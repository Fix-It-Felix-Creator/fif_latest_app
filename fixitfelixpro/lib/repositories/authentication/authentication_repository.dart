import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthChangeEvent,
        AuthResponse,
        AuthException,
        OAuthProvider,
        OtpType,
        PostgrestException,
        SupabaseClient,
        User,
        UserAttributes;

import '../../core/config/config_service.dart';
import '../../core/config/environment_variables.dart';
import '../../core/enum.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/image_compressor.dart';
import '../../generated/database_paths.dart';
import '../../globals.dart';
import '../../models/app_user.dart';
import '../../models/user_details_model.dart';
import '../../models/user_subscription_model.dart';
import '../../services/iap_service.dart';
import '../configurations/configurations_repositories.dart';
import '../device/device_info_repository.dart';
import '../subscription/subscription_mapper.dart';
import 'base_authentication_repository.dart';
import 'profile_mapper.dart';

/// Repository for handling all authentication operations.
///
/// Migrated from Firebase Auth + Realtime Database + Firebase Storage to
/// Supabase Auth + Postgres (`profiles`) + Supabase Storage. Behaviour,
/// navigation and cache semantics are preserved exactly; only the backend
/// changed. Firebase's `User`/`UserCredential` no longer appear — see
/// [AppUser].
class AuthRepository extends BaseAuthenticationRepository {
  final ConfigurationRepository remoteConfigRepository;

  AuthRepository({required this.remoteConfigRepository});

  /// Callback to be called before sign out to stop all active streams/listeners
  /// Set this from your app to clean up BLoC subscriptions before auth sign out
  static Future<void> Function()? onBeforeSignOut;

  /// Bucket holding profile images and KYC documents.
  static const String _userDocumentsBucket = 'user-documents';

  /// Table backing the old `users/{uid}` RTDB node.
  static const String _profilesTable = 'profiles';

  SupabaseClient get _client => SupabaseService().client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Caching services
  final CacheService _cacheService = CacheService();
  final ConnectivityService _connectivityService = ConnectivityService();

  late EnvironmentVariables _envData;

  @override
  void setENVConfig(EnvironmentVariables envData) {
    _envData = envData;
    debugPrint(
      'AuthRepository: Environment variables set: APP_TYPE=${_envData.appType}, APP_VERSION=${_envData.appVersion}',
    );
  }

  // ===========================================================================
  // Authentication state
  // ===========================================================================

  @override
  AppUser? get currentUser {
    final u = _client.auth.currentUser;
    return u == null ? null : AppUser.fromSupabase(u);
  }

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange
      .where(
        // Supabase emits a token-refresh event roughly hourly. The old
        // Firebase stream did not, and re-emitting here would make every
        // listening bloc rebuild for no state change.
        (data) => data.event != AuthChangeEvent.tokenRefreshed,
      )
      .map(
        (data) => data.session?.user == null
            ? null
            : AppUser.fromSupabase(data.session!.user),
      );

  @override
  bool get isLoggedIn => _client.auth.currentUser != null;

  @override
  Future<String?> getAccessToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  @override
  bool isEmailVerified() => currentUser?.emailVerified ?? false;

  String? get _uid => _client.auth.currentUser?.id;

  // ===========================================================================
  // Sign in / sign up
  // ===========================================================================

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final trimmed = email.trim();
      AuthResponse res;

      try {
        res = await _client.auth.signInWithPassword(
          email: trimmed,
          password: password,
        );
      } on AuthException catch (e) {
        // A user migrated from Firebase has no Supabase password yet, so a
        // perfectly correct password fails here the first time. Offer it to
        // the bridge, which verifies it against Firebase once and copies it
        // across, then retry.
        //
        // Only on an invalid-credentials failure: a rate limit or a network
        // error must not be mistaken for "needs migrating".
        if (_normalizeAuthCode(e) != 'invalid-credential') rethrow;

        final bridged = await _tryPasswordBridge(trimmed, password);
        if (!bridged) rethrow;

        res = await _client.auth.signInWithPassword(
          email: trimmed,
          password: password,
        );
      }

      final user = res.user;
      if (user == null) {
        throw CustomException(message: _getAuthErrorMessage('invalid-credential'));
      }

      // Block restricted account types (e.g. customer)
      await _validateAccountType();

      return AppUser.fromSupabase(user);
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Sign in failed: $e');
    }
  }

  /// One-time password migration for a user carried over from Firebase.
  ///
  /// Returns true when the backend accepted the credentials and set the
  /// Supabase password, so the caller can retry the sign-in. Returns false for
  /// every other outcome — wrong password, an account that was never migrated,
  /// rate limiting, backend unreachable — and the caller then surfaces the
  /// original error. The user sees a normal "invalid password" message rather
  /// than anything about migration, which is the point: this should be
  /// invisible.
  Future<bool> _tryPasswordBridge(String email, String password) async {
    try {
      final base = ConfigService().stripeBackendUrl;
      if (base.isEmpty) return false;

      final res = await http
          .post(
            Uri.parse('$base/auth/bridge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          // Bounded: sign-in must not hang on a slow backend. Failing here
          // just means the user sees the ordinary invalid-credentials error.
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = body['success'] == true;
      if (ok) debugPrint('Password migrated from Firebase for $email');
      return ok;
    } catch (e) {
      debugPrint('Password bridge unavailable: $e');
      return false;
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Supabase sends the confirmation email automatically when email
      // confirmation is enabled, so there is no explicit
      // sendEmailVerification() call here as there was with Firebase.
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _emailRedirectTo,
      );

      final user = res.user;
      if (user == null) {
        throw CustomException(message: 'Sign up failed. Please try again.');
      }

      // The profiles row is created by the `handle_new_user` trigger on
      // auth.users, so there is nothing to insert here — and no window where
      // an auth user exists without a profile.
      return AppUser.fromSupabase(user);
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Sign up failed: $e');
    }
  }

  /// Deep link the auth emails redirect back into. Registered as a redirect
  /// URL on both projects, and declared by iOS (`CFBundleURLSchemes`) and
  /// Android (the `fixitfelix` intent-filter).
  static const String _emailRedirectTo = 'fixitfelix://login-callback';

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      // Supabase requires the ID token specifically — an access token alone
      // is not enough to establish a session.
      if (idToken == null) {
        throw CustomException(
          message:
              'Failed to get Google authentication tokens. Please try again.',
        );
      }

      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      final user = res.user;
      if (user == null) {
        throw CustomException(message: 'Google sign in failed. Please try again.');
      }

      // Persist the Google profile name so a fresh Google user isn't asked to
      // re-type a name we already have.
      final googleName =
          (googleUser.displayName ?? AppUser.fromSupabase(user).displayName ?? '')
              .trim();
      final parts =
          googleName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      await _persistOAuthNameIfMissing(
        user,
        firstName: parts.isNotEmpty ? parts.first : '',
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      );

      await _validateAccountType();

      return AppUser.fromSupabase(user);
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Google sign in failed: $e');
    }
  }

  /// Sign in with Apple (required by App Store Guideline 4.8 on iOS).
  @override
  Future<AppUser?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        throw CustomException(
          message: 'Failed to get Apple identity token. Please try again.',
        );
      }

      // Apple hashes the nonce into the token; Supabase re-hashes the raw
      // value to verify, so the RAW nonce is what gets passed here.
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );

      final user = res.user;
      if (user == null) {
        throw CustomException(message: 'Apple sign in failed. Please try again.');
      }

      // Apple only returns the name on the *first* authorization. Capture it
      // here and persist it so the user is never forced to re-type a name
      // Apple already provided — App Store Guideline 4 forbids that.
      await _persistOAuthNameIfMissing(
        user,
        firstName: (appleCredential.givenName ?? '').trim(),
        lastName: (appleCredential.familyName ?? '').trim(),
      );

      await _validateAccountType();

      return AppUser.fromSupabase(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw CustomException(message: 'Apple sign in failed: ${e.message}');
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Apple sign in failed: $e');
    }
  }

  /// Persists an OAuth-provider-supplied name (Apple / Google) onto both the
  /// auth user metadata and the `profiles` row so the onboarding name step is
  /// satisfied automatically. Only writes fields that are currently missing —
  /// it never clobbers a name the user has already set, and is a no-op when
  /// the provider returned nothing (e.g. Apple's non-first sign-ins).
  Future<void> _persistOAuthNameIfMissing(
    User? user, {
    required String firstName,
    required String lastName,
  }) async {
    final uid = user?.id;
    final first = firstName.trim();
    final last = lastName.trim();
    if (uid == null || (first.isEmpty && last.isEmpty)) return;

    try {
      final fullName = [first, last].where((p) => p.isNotEmpty).join(' ');
      final existingName = AppUser.fromSupabase(user!).displayName;
      if (fullName.isNotEmpty && (existingName == null || existingName.isEmpty)) {
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': fullName}),
        );
      }

      final existing = await _client
          .from(_profilesTable)
          .select('first_name, last_name')
          .eq('id', uid)
          .maybeSingle();

      final hasFirst =
          ((existing?['first_name'] as String?) ?? '').trim().isNotEmpty;
      final hasLast =
          ((existing?['last_name'] as String?) ?? '').trim().isNotEmpty;

      final updates = <String, dynamic>{
        if (!hasFirst && first.isNotEmpty) 'first_name': first,
        if (!hasLast && last.isNotEmpty) 'last_name': last,
      };
      if (updates.isEmpty) return;

      if (user.email != null) updates['email'] = user.email;
      await _client.from(_profilesTable).update(updates).eq('id', uid);
    } catch (e) {
      // Non-fatal: the onboarding screen still pre-fills from the display name.
      debugPrint('OAuth name persist failed (non-fatal): $e');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  // ===========================================================================
  // Sign out
  // ===========================================================================

  @override
  Future<void> signOut() async {
    try {
      // Stop all listeners BEFORE signing out. Under RLS an in-flight
      // realtime subscription starts failing the moment the JWT is revoked,
      // exactly as it did with RTDB permission-denied errors.
      debugPrint('AuthRepository: Stopping all listeners before sign out...');

      if (onBeforeSignOut != null) {
        await onBeforeSignOut!();
      }

      DeviceInfoRepository().stopForceLogoutListener();

      debugPrint(
        'AuthRepository: All listeners stopped, proceeding with sign out...',
      );

      try {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        // Ignore Google sign out errors - proceed with Supabase sign out
        debugPrint('Google sign out failed (non-critical): $e');
      }

      await _client.auth.signOut();
      handleAuthentication();
    } catch (e) {
      throw CustomException(message: 'Sign out failed: $e');
    }
  }

  // ===========================================================================
  // Password / verification email
  // ===========================================================================

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _emailRedirectTo,
      );
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      throw CustomException(message: 'Password reset failed: $e');
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw CustomException(
        message: _getAuthErrorMessage(_normalizeAuthCode(e)),
        code: _normalizeAuthCode(e),
        originalError: e,
      );
    } catch (e) {
      throw CustomException(message: 'Failed to update password: $e');
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': displayName}),
      );
    } catch (e) {
      throw CustomException(message: 'Failed to update display name: $e');
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    try {
      final email = _client.auth.currentUser?.email;
      if (email == null) {
        throw CustomException(message: 'No email address on this account.');
      }
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _emailRedirectTo,
      );
    } on AuthException catch (e) {
      final code = _normalizeAuthCode(e);
      if (code == 'too-many-requests') {
        throw CustomException(
          message:
              'Too many requests. Please wait a few minutes before trying again.',
          code: code,
          originalError: e,
        );
      }
      throw CustomException(
        message: _getAuthErrorMessage(code),
        code: code,
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('too many') || errorStr.contains('rate limit')) {
        throw CustomException(
          message:
              'Too many requests. Please wait a few minutes before trying again.',
        );
      }
      throw CustomException(message: 'Failed to send verification email: $e');
    }
  }

  @override
  Future<void> refreshUserVerificationStatus() async {
    try {
      // Firebase had User.reload(); Supabase refreshes the whole session,
      // which re-reads email_confirmed_at from the server.
      await _client.auth.refreshSession();
    } catch (e) {
      throw CustomException(message: 'Failed to refresh user status: $e');
    }
  }

  // ===========================================================================
  // User details CRUD
  // ===========================================================================

  @override
  Future<void> saveUserDetails({required UserDetailsModel userDetails}) async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'User not authenticated');
      }

      final row = ProfileMapper.modelJsonToRow(userDetails.toJson());
      row['id'] = uid; // never trust a uid carried on the model

      await _client.from(_profilesTable).update(row).eq('id', uid);
      debugPrint('User details saved to profiles');

      // Update cache so subsequent getUserDetails() calls return fresh data.
      await _cacheService.saveUserDetails(uid, userDetails.toJson());
    } on PostgrestException catch (e) {
      throw CustomException(
        message: 'Failed to save user details: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to save user details: $e');
    }
  }

  @override
  Future<void> updateUserDetails(Map<String, dynamic> updates) async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'User not authenticated');
      }

      // partial: true so only the supplied keys are written — the RTDB
      // .update() this replaces was inherently partial, and a full write
      // here would null out every untouched column.
      final row = ProfileMapper.modelJsonToRow(updates, partial: true);
      if (row.isEmpty) {
        debugPrint('updateUserDetails: nothing writable in $updates — skipping');
        return;
      }

      debugPrint('Updating user details in profiles: $row');
      await _client.from(_profilesTable).update(row).eq('id', uid);
    } on PostgrestException catch (e) {
      throw CustomException(
        message: 'Failed to update user details: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to update user details: $e');
    }
  }

  @override
  Future<UserDetailsModel?> getUserDetails({bool forceRefresh = false}) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return null;
      }

      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedData = _cacheService.getUserDetails(uid);
        if (cachedData != null) {
          final isOffline = !_connectivityService.isConnected;
          final isCacheFresh = !_cacheService.isCacheStale(uid);

          if (isOffline || isCacheFresh) {
            debugPrint(
              'Using cached user details (offline: $isOffline, fresh: $isCacheFresh)',
            );
            return UserDetailsModel.fromJson(cachedData);
          }
        }
      }

      // If offline and no cache, return null
      if (!_connectivityService.isConnected) {
        debugPrint('Offline and no cache available');
        return null;
      }

      final row = await _client
          .from(_profilesTable)
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      final data = ProfileMapper.rowToModelJson(row);

      // RTDB nested the subscription inside the user document, so it arrived
      // with the profile. Postgres keeps it in its own table, and there is no
      // FK from `subscriptions` to `profiles` (it points at auth.users), so
      // PostgREST can't embed it — it takes a second read.
      //
      // This is not optional detail: `_needsSubscription()` gates the whole
      // app on `subscription?.member`, and the Settings plan card reads the
      // same field. Without this the gate sends every user to ChoosePlan for
      // ever, even holding a valid trial, and Settings shows "No active plan".
      data['subscription'] = SubscriptionMapper.rowToContainerJson(
        await _client
            .from(SubscriptionMapper.table)
            .select()
            .eq(SubscriptionMapper.primaryKey, uid)
            .maybeSingle(),
      );

      await _cacheService.saveUserDetails(uid, data);
      debugPrint('User details cached successfully');

      return UserDetailsModel.fromJson(data);
    } catch (e) {
      // On error, try to return cached data
      final uid = _uid;
      if (uid != null) {
        final cachedData = _cacheService.getUserDetails(uid);
        if (cachedData != null) {
          debugPrint('Returning cached data due to error: $e');
          return UserDetailsModel.fromJson(cachedData);
        }
      }
      throw CustomException(message: 'Failed to get user details: $e');
    }
  }

  @override
  UserDetailsModel? getCachedUserDetails() {
    final uid = _uid;
    if (uid == null) return null;

    final cachedData = _cacheService.getUserDetails(uid);
    if (cachedData != null) {
      return UserDetailsModel.fromJson(cachedData);
    }
    return null;
  }

  @override
  Stream<UserDetailsModel?> streamUserDetails() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(null);
    }

    return _client
        .from(_profilesTable)
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        // asyncMap, not map: the subscription lives in another table and has
        // to be fetched. Emitting the profile alone would publish a user with
        // `subscription: null` AND cache it, silently undoing whatever
        // getUserDetails() had just loaded — bouncing a paying or trialling
        // user back to ChoosePlan on the next gate check.
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;

          final data = ProfileMapper.rowToModelJson(rows.first);

          data['subscription'] = SubscriptionMapper.rowToContainerJson(
            await _client
                .from(SubscriptionMapper.table)
                .select()
                .eq(SubscriptionMapper.primaryKey, uid)
                .maybeSingle(),
          );

          _cacheService.saveUserDetails(uid, data);
          debugPrint('User details updated and cached from stream');

          return UserDetailsModel.fromJson(data);
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('Error in streamUserDetails: $error');
        });
  }

  @override
  Future<void> clearUserCache() async {
    final uid = _uid;
    if (uid != null) {
      await _cacheService.delete(CacheBoxes.userDetails, uid);
      await _cacheService.delete(CacheBoxes.userDetails, '${uid}_lastSync');
    }
  }

  // ===========================================================================
  // Profile
  // ===========================================================================

  @override
  Future<bool> hasCompletedProfile() async {
    try {
      final user = await getUserDetails();
      if (user == null) return false;

      if (user.accountType == AccountCategoryType.business &&
          user.role == BusinessRole.owner) {
        // Business owner profile completion rule
        return (user.businessName?.isNotEmpty ?? false);
      }

      // Tradesman rule
      return (user.firstName?.isNotEmpty ?? false) &&
          (user.lastName?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final uid = _uid;
      if (uid == null) return null;

      final row = await _client
          .from(_profilesTable)
          .select('role')
          .eq('id', uid)
          .maybeSingle();

      return row?['role']?.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String> uploadProfileImage(String localPath) async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'User not authenticated');
      }

      var file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'Image file does not exist');
      }

      // Smart compress: only compresses if file exceeds profile image size limit
      final compressionResult =
          await ImageCompressor.compressIfNeeded(file, 'profile');
      if (compressionResult != null) {
        file = compressionResult.file;
      }

      // Delete existing profile image from storage if it exists
      await _deleteExistingProfileImage(uid);

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath = DatabasePaths.profileImage(uid, timestamp);

      await _client.storage
          .from(_userDocumentsBucket)
          .upload(storagePath, file);

      // The bucket is private, so this replaces Firebase's getDownloadURL()
      // with a long-lived signed URL. Ten years keeps the stored value stable
      // for the lifetime of the record, matching the old behaviour where the
      // download URL never expired.
      final downloadUrl = await _client.storage
          .from(_userDocumentsBucket)
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365 * 10);

      await _client.from(_profilesTable).update({
        'profile_image_url': downloadUrl,
      }).eq('id', uid);

      return downloadUrl;
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to upload profile image: $e');
    }
  }

  /// Remove the user's previous profile image object.
  ///
  /// The stored value is a signed URL, so the object key is recovered from the
  /// path rather than the URL itself.
  Future<void> _deleteExistingProfileImage(String uid) async {
    try {
      final dir = '${DatabasePaths.storageUserDocuments(uid)}/profile';
      final existing = await _client.storage
          .from(_userDocumentsBucket)
          .list(path: dir);

      if (existing.isEmpty) return;

      await _client.storage
          .from(_userDocumentsBucket)
          .remove(existing.map((f) => '$dir/${f.name}').toList());
    } catch (e) {
      // If deletion fails (e.g. nothing there), continue with upload
      debugPrint('Failed to delete existing profile image: $e');
    }
  }

  // ===========================================================================
  // Subscription
  // ===========================================================================

  @override
  Future<void> updateSubscription(
    UserSubscriptionModel subscription, {
    bool resetUsage = false,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'User not authenticated');
      }

      await _client.from('subscriptions').upsert({
        'owner_id': uid,
        ...subscription.toJson(),
      }, onConflict: 'owner_id');

      // Reset usage counts if a new plan is activated.
      //
      // Deliberately resets only these six, matching the original exactly.
      // usage_repository.resetUsage() clears all seventeen — these are two
      // different behaviours and must not be collapsed into reset_usage().
      if (resetUsage) {
        await _client.from('usage_counters').upsert({
          'owner_id': uid,
          'address_count': 0,
          'invoice_count': 0,
          'quotation_count': 0,
          'template_count': 0,
          'service_count': 0,
          'customer_count': 0,
        }, onConflict: 'owner_id');
      }
    } on PostgrestException catch (e) {
      throw CustomException(
        message: 'Failed to update subscription plan: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to update subscription plan: $e');
    }
  }

  // ===========================================================================
  // Account management
  // ===========================================================================

  @override
  Future<void> deleteAccountCompletely() async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'No user logged in');
      }

      await deleteUserDocuments();

      // Deleting the auth user cascades to profiles (FK ON DELETE CASCADE)
      // and from there to every owner_id-scoped table.
      //
      // Supabase has no client-side "delete my own account" call — it needs
      // the service role — so this goes through the account-deletion endpoint,
      // which is also where the recovery window is recorded.
      await _client.functions.invoke('account-delete');
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to delete account: $e');
    }
  }

  @override
  Future<void> deleteUserDetails() async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'No user logged in');
      }

      await deleteUserDocuments();
      await _client.from(_profilesTable).delete().eq('id', uid);
      await clearUserCache();
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to delete user details: $e');
    }
  }

  @override
  Future<void> deleteUserDocuments() async {
    try {
      final uid = _uid;
      if (uid == null) {
        throw CustomException(message: 'No user logged in');
      }

      await _removeStorageTree(DatabasePaths.storageUserDocuments(uid));
    } catch (e) {
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to delete user documents: $e');
    }
  }

  /// Recursively removes every object under [prefix].
  ///
  /// Supabase Storage has no "delete folder" call — `list` returns one level
  /// at a time, so this walks the tree the way the old
  /// `_deleteRecursive(Reference)` did.
  Future<void> _removeStorageTree(String prefix) async {
    final entries =
        await _client.storage.from(_userDocumentsBucket).list(path: prefix);
    if (entries.isEmpty) return;

    final files = <String>[];
    for (final entry in entries) {
      // A storage "folder" is synthesised from key prefixes and has no id.
      if (entry.id == null) {
        await _removeStorageTree('$prefix/${entry.name}');
      } else {
        files.add('$prefix/${entry.name}');
      }
    }
    if (files.isNotEmpty) {
      await _client.storage.from(_userDocumentsBucket).remove(files);
    }
  }

  /// Check if the current user's account is disabled in the database
  Future<bool> isAccountDisabled() async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final row = await _client
          .from(_profilesTable)
          .select('account_status')
          .eq('id', uid)
          .maybeSingle();
      return row?['account_status'] == 'disabled';
    } catch (e) {
      debugPrint('Error checking account status: $e');
      return false;
    }
  }

  /// Validate that the authenticated user's account type is allowed in this app.
  /// This app is for tradesmen and businesses only — customer accounts are blocked.
  Future<void> _validateAccountType() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final row = await _client
          .from(_profilesTable)
          .select('account_type')
          .eq('id', uid)
          .maybeSingle();

      final accountType = row?['account_type']?.toString().toLowerCase();
      if (accountType == 'customer') {
        await _client.auth.signOut();
        throw CustomException(
          message:
              'Access denied. Customer accounts are not allowed to sign in to this app. Please use the FixItFelix customer app.',
          code: 'account-type-restricted',
        );
      }
    } on CustomException {
      rethrow;
    } catch (e) {
      // If we can't validate, allow sign-in to proceed (fail open)
      debugPrint('Account type validation failed: $e');
    }
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  @override
  Future<void> handleAuthentication() async {
    // Ensure navigator is ready. Bounded wait (≈5s) instead of unbounded
    // recursion so a never-mounted navigator (app torn down / backgrounded
    // at sign-in) can't loop forever and build up an unbounded async chain.
    NavigatorState? navigator = globalNavigatorKey.currentState;
    var navWaits = 0;
    while (navigator == null && navWaits < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      navigator = globalNavigatorKey.currentState;
      navWaits++;
    }
    if (navigator == null) {
      debugPrint(
        'handleAuthentication: navigator never became ready — aborting',
      );
      return;
    }

    // =========================================================================
    // CHECK FORCE UPDATE & MAINTENANCE STATUS FIRST (based on APP_TYPE)
    // =========================================================================
    final configService = ConfigService();

    if (configService.requiresForceUpdate) {
      debugPrint('Force update required - navigating to /force_update');
      navigator.pushNamedAndRemoveUntil('/force_update', (route) => false);
      return;
    }

    if (configService.isUnderMaintenance) {
      debugPrint('App under maintenance - navigating to /maintenance');
      navigator.pushNamedAndRemoveUntil('/maintenance', (route) => false);
      return;
    }

    // =========================================================================
    // NORMAL AUTHENTICATION FLOW
    // =========================================================================
    try {
      // Firebase used User.reload(); refreshing the session is the Supabase
      // equivalent and re-reads email_confirmed_at from the server.
      if (_client.auth.currentSession != null) {
        await _client.auth.refreshSession();
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
      if (e is AuthException) {
        // Only sign out for errors that indicate an invalid session, not
        // network issues — otherwise a flaky connection logs the user out.
        final code = _normalizeAuthCode(e);
        const invalidSessionCodes = [
          'user-token-expired',
          'user-disabled',
          'user-not-found',
          'invalid-user-token',
        ];
        if (invalidSessionCodes.contains(code)) {
          await _client.auth.signOut();
          navigator.pushNamedAndRemoveUntil('/signIn', (route) => false);
          return;
        }
        // For network errors, continue with cached user state
      }
    }

    final user = currentUser;

    if (user == null) {
      navigator.pushNamedAndRemoveUntil('/signIn', (route) => false);
    } else if (!user.emailVerified) {
      navigator.pushNamedAndRemoveUntil('/emailVerify', (route) => false);
    } else {
      final userDetails = await getUserDetails(forceRefresh: true);

      // Block / divert on account_status before anything else, even if the
      // user has no profile data yet — a deletion-pending or disabled account
      // should never be routed to onboarding.
      Map<String, dynamic>? accountRow;
      try {
        accountRow = await _client
            .from(_profilesTable)
            .select(
              'account_status, recovery_window_ends_at, personal_data_retained_until',
            )
            .eq('id', user.uid)
            .maybeSingle();
      } catch (e) {
        debugPrint('Failed to read account status: $e');
      }

      final accountStatus = accountRow?['account_status']?.toString();
      if (accountStatus == 'deletion_pending') {
        debugPrint('Deletion-pending account — routing to recovery screen');
        navigator.pushNamedAndRemoveUntil(
          '/accountDisabled',
          (route) => false,
          arguments: {
            // The screen expects epoch millis (routes.dart:310-312); the
            // columns are timestamptz, so convert rather than hand it a string.
            'recoveryWindowEndsAt':
                _toEpochMillis(accountRow?['recovery_window_ends_at']),
            'personalDataRetainedUntil':
                _toEpochMillis(accountRow?['personal_data_retained_until']),
          },
        );
        return;
      }
      if (accountStatus == 'disabled') {
        debugPrint('Disabled account detected - signing out');
        await _client.auth.signOut();
        navigator.pushNamedAndRemoveUntil('/signIn', (route) => false);
        return;
      }

      // Block customer accounts — this app is for tradesmen only.
      if (userDetails?.accountType == AccountCategoryType.customer) {
        debugPrint('Customer account detected - signing out and redirecting');
        await _client.auth.signOut();
        navigator.pushNamedAndRemoveUntil('/signIn', (route) => false);
        return;
      }

      final needsOnboarding = _needsOnboarding(userDetails);
      if (needsOnboarding) {
        navigator.pushNamedAndRemoveUntil(
          '/onboarding/personal',
          (route) => false,
        );
        return;
      }

      var details = userDetails!;
      if (_needsSubscription(details)) {
        final restored = await _tryRestoreEntitlement();
        if (restored != null) details = restored;
      }

      if (_needsSubscription(details)) {
        navigator.pushNamedAndRemoveUntil('/choosePlan', (route) => false);
        return;
      }

      navigator.pushNamedAndRemoveUntil('/tradesmanHome', (route) => false);
    }
  }

  /// The recovery screen takes epoch millis; Postgres hands back ISO-8601.
  static int? _toEpochMillis(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return DateTime.tryParse(value.toString())?.millisecondsSinceEpoch;
  }

  /// True when the user hasn't completed the onboarding minimum:
  /// firstName, phoneNumber, and an address (postcode is the canonical
  /// "address present" probe). Last name is optional.
  bool _needsOnboarding(UserDetailsModel? d) {
    if (d == null) return true;
    if ((d.firstName ?? '').trim().isEmpty) return true;
    // Last name is OPTIONAL — must match the onboarding form's Continue
    // gate (personal_details_step). Apple/Google may return no surname,
    // and requiring it here would bounce those users back to onboarding
    // forever even after they complete step 1.
    if (d.phoneNumber.trim().isEmpty) return true;
    if (d.address.postcode.trim().isEmpty) return true;
    return false;
  }

  /// True when the user can't access the home screen yet.
  bool _needsSubscription(UserDetailsModel d) {
    final member = d.subscription?.member;
    if (member == null) {
      debugPrint('[sub-gate] no member subscription → ChoosePlan');
      return true;
    }

    final grantsAccess = member.status == SubscriptionStatus.active ||
        member.status == SubscriptionStatus.trial;

    final end = member.endDate;
    final expired = end != null && end.isBefore(DateTime.now());

    final needs = !grantsAccess || expired;
    debugPrint(
      '[sub-gate] status=${member.status.name} isPaid=${member.isPaid} '
      'end=$end expired=$expired → ${needs ? "ChoosePlan" : "Home"}',
    );
    return needs;
  }

  /// Silently re-deliver and re-validate any active store purchase, then poll
  /// until the refreshed entitlement grants access.
  Future<UserDetailsModel?> _tryRestoreEntitlement() async {
    try {
      final iap = IapService();
      if (!iap.isAvailable) {
        debugPrint('[sub-gate] silent restore skipped: IAP unavailable');
        return null;
      }
      debugPrint('[sub-gate] no live subscription — attempting silent restore');
      await iap.restore();
      const attempts = 8;
      for (var i = 0; i < attempts; i++) {
        await Future.delayed(const Duration(milliseconds: 750));
        final d = await getUserDetails(forceRefresh: true);
        if (d != null && !_needsSubscription(d)) {
          debugPrint('[sub-gate] silent restore confirmed a subscription');
          return d;
        }
      }
      debugPrint('[sub-gate] silent restore found no active subscription');
    } catch (e) {
      debugPrint('[sub-gate] silent restore failed: $e');
    }
    return null;
  }

  // ===========================================================================
  // Error mapping
  // ===========================================================================

  /// Maps Supabase auth failures onto the Firebase error codes the UI copy
  /// was written against, so [_getAuthErrorMessage] and every screen that
  /// switches on a code keep working unchanged.
  String _normalizeAuthCode(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return 'invalid-credential';
    }
    if (code == 'user_not_found' || msg.contains('user not found')) {
      return 'user-not-found';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'email-already-in-use';
    }
    if (code == 'weak_password' || msg.contains('password should be at least')) {
      return 'weak-password';
    }
    if (code == 'validation_failed' && msg.contains('email')) {
      return 'invalid-email';
    }
    if (code == 'email_address_invalid' || msg.contains('invalid email')) {
      return 'invalid-email';
    }
    if (code == 'user_banned' || msg.contains('banned')) {
      return 'user-disabled';
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        e.statusCode == '429' ||
        msg.contains('rate limit') ||
        msg.contains('too many')) {
      return 'too-many-requests';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'email-not-verified';
    }
    if (code == 'session_expired' || msg.contains('jwt expired')) {
      return 'user-token-expired';
    }
    if (msg.contains('failed host lookup') ||
        msg.contains('socketexception') ||
        msg.contains('network')) {
      return 'network-request-failed';
    }
    return code.isEmpty ? 'unknown' : code;
  }

  /// Helper method to convert auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'email-not-verified':
        return 'Please verify your email address before signing in.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
