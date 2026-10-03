import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../core/enum.dart';
import '../../globals.dart';
import '../../models/user_details_model.dart';
import '../../repositories/authentication/authentication_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
  }) : _authRepository = authRepository,
       super(const AuthState.unknown()) {
    // App lifecycle
    on<AuthStarted>(_onAuthStarted);
    on<AuthUserDetailsChanged>(_onAuthUserDetailsChanged);
    on<AuthUserRefreshed>(_onAuthUserRefreshed);

    // Sign in
    on<SignInWithEmailRequested>(_onSignInWithEmail);
    on<SignInWithGoogleRequested>(_onSignInWithGoogle);
    on<SignInWithAppleRequested>(_onSignInWithApple);

    // Sign up
    on<SignUpWithEmailRequested>(_onSignUpWithEmail);

    // Sign out
    on<AuthLogoutRequested>(_onAuthLogoutRequested);

    // Force logout (from another device)
    on<AuthForceLogoutRequested>(_onAuthForceLogoutRequested);

    // Password reset
    on<PasswordResetRequested>(_onPasswordResetRequested);

    // Email verification
    on<SendVerificationEmailRequested>(_onSendVerificationEmail);

    // Tradesman registration

    // Business registration

    // Delete account
    on<DeleteAccountRequested>(_onDeleteAccount);

    // Error handling
    on<AuthErrorCleared>(_onAuthErrorCleared);

    on<HandleAuthentication>(_onHandleAuthentication);

    // Update work status

    // Update user details
    on<UpdateUserDetailsRequested>(_onUpdateUserDetails);

    // Upload profile image

    // Company details

    // Listen to auth state changes
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      add(const AuthStarted());
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<dynamic> _authSubscription;
  StreamSubscription<dynamic>? _userDetailsSubscription;

  // ============================================
  // App Lifecycle Handlers
  // ============================================

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    _userDetailsSubscription?.cancel();

    if (user != null) {
      // Check if account is disabled BEFORE emitting authenticated state
      // This prevents services from starting for disabled accounts
      if (await _authRepository.isAccountDisabled()) {
        await _authRepository.signOut();
        emit(const AuthErrorState(
          errorMessage:
              'This account has been disabled. Please contact support.',
        ));
        return;
      }

      // First, try to load cached data for instant UI (offline-first)
      final cachedDetails = _authRepository.getCachedUserDetails();

      // Block tradesman and business accounts (cached check)
      if (await _refuseIfNotCustomer(cachedDetails, emit)) return;

      if (cachedDetails != null) {
        emit(AuthState.authenticated(user, userDetails: cachedDetails));
      }

      // Then fetch fresh details (will use cache if offline or cache is fresh)
      final userDetails = await _authRepository.getUserDetails();

      // Block tradesman and business accounts (fresh data check)
      if (await _refuseIfNotCustomer(userDetails, emit)) return;

      // Subscribe to user details updates (also caches changes automatically)
      _userDetailsSubscription = _authRepository.streamUserDetails().listen(
        (userDetails) {
          add(AuthUserDetailsChanged(userDetails));
        },
        onError: (error) {
          debugPrint('Error in user details stream: $error');
        },
      );

      // Emit with fresh data if different from cached
      if (userDetails != null && userDetails != cachedDetails) {
        emit(AuthState.authenticated(user, userDetails: userDetails));
      } else if (cachedDetails == null) {
        emit(AuthState.authenticated(user, userDetails: userDetails));
      }
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  /// Signs out and reports a refusal when [details] belongs to anything other
  /// than a customer. Returns true when the caller should stop.
  ///
  /// This app is for customers; the pro app runs the mirror image of this
  /// check. Both are also enforced in AuthRepository — at sign-in by
  /// _validateAccountType and at routing by handleAuthentication — so the
  /// rule lives in three places. One shared helper here at least keeps the
  /// bloc's cached and fresh paths from disagreeing with each other, which is
  /// how this check ended up inverted after the port.
  ///
  /// A null [details] passes: the profile row may not have been read yet, and
  /// refusing on absent data would lock out a brand-new customer.
  Future<bool> _refuseIfNotCustomer(
    UserDetailsModel? details,
    Emitter<AuthState> emit,
  ) async {
    if (details == null ||
        details.accountType == AccountCategoryType.customer) {
      return false;
    }
    await _authRepository.signOut();
    emit(const AuthErrorState(
      errorMessage:
          'This email is already used for a FixItFelix Pro tradesperson '
          'account. Sign in to the FixItFelix Pro app instead, or use a '
          'different email to sign up as a customer.',
    ));
    return true;
  }

  Future<void> _onAuthUserDetailsChanged(
    AuthUserDetailsChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      final newDetails = event.userDetails;

      emit(AuthState.authenticated(user, userDetails: newDetails));

      // The pro app re-routes here when a tradesperson's verificationStatus
      // changes, driving its KYC waiting / rejected screens. Customers are
      // not verified and this app has neither screen, so there is nothing to
      // react to.
    }
  }

  Future<void> _onAuthUserRefreshed(
    AuthUserRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    // Refresh first, then get updated user
    await _authRepository.refreshUserVerificationStatus();
    final user = _authRepository.currentUser;
    if (user == null) return;

    // Re-read the user document rather than re-emitting `state.userDetails`.
    //
    // Callers dispatch this precisely because something outside the profile
    // row changed — ChoosePlan fires it after activating a free trial so the
    // gate can see the new subscription. The subscription lives in its own
    // table, so no profile-stream event fires for it; keeping the old
    // userDetails here meant the trial was invisible until a full restart,
    // leaving the user stuck on the paywall they had just cleared.
    //
    // forceRefresh bypasses the cache, which is still holding the pre-trial
    // copy. On failure keep what we had — a stale plan beats signing the
    // user out.
    UserDetailsModel? details;
    try {
      details = await _authRepository.getUserDetails(forceRefresh: true);
    } catch (e) {
      debugPrint('AuthUserRefreshed: could not reload user details: $e');
    }

    emit(
      AuthState.authenticated(
        user,
        userDetails: details ?? state.userDetails,
      ),
    );
  }

  // ============================================
  // Sign In Handlers
  // ============================================

  Future<void> _onSignInWithEmail(
    SignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoadingState(loadingMessage: 'Signing in...'));

      await _authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      // Auth state listener (_onAuthStarted) will handle:
      // - disabled account check
      // - customer account check
      // - emitting authenticated state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoadingState(loadingMessage: 'Signing in with Google...'));

      final result = await _authRepository.signInWithGoogle();

      if (result == null) {
        // User cancelled Google sign-in
        emit(const AuthState.unauthenticated());
        return;
      }

      // Auth state listener (_onAuthStarted) will handle:
      // - disabled account check
      // - customer account check
      // - emitting authenticated state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  Future<void> _onSignInWithApple(
    SignInWithAppleRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoadingState(loadingMessage: 'Signing in with Apple...'));

      final result = await _authRepository.signInWithApple();

      if (result == null) {
        emit(const AuthState.unauthenticated());
        return;
      }
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Sign Up Handler
  // ============================================

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoadingState(loadingMessage: 'Creating account...'));

      await _authRepository.signUpWithEmail(
        email: event.email,
        password: event.password,
      );

      // Auth state listener will handle the authenticated state
      // Verification email is sent automatically in repository
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Sign Out Handler
  // ============================================

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoadingState(loadingMessage: 'Signing out...'));

      _userDetailsSubscription?.cancel();
      await _authRepository.signOut();

      // Auth state listener will handle the unauthenticated state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  /// Handle force logout from another device
  /// This is called when the user logs in from another device and this device
  /// needs to be logged out automatically
  Future<void> _onAuthForceLogoutRequested(
    AuthForceLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      debugPrint('AuthBloc: Force logout requested - ${event.reason}');

      _userDetailsSubscription?.cancel();

      // Sign out from Firebase (signOut already handles Google sign out)
      await _authRepository.signOut();

      // Emit the force logout state with the reason
      // This allows the UI to show a specific message about why they were logged out
      emit(ForceLogoutState(reason: event.reason));
    } catch (e) {
      debugPrint('AuthBloc: Error during force logout: $e');
      // Even if there's an error, we should still emit unauthenticated
      emit(ForceLogoutState(reason: event.reason));
    }
  }

  // ============================================
  // Password Reset Handler
  // ============================================

  Future<void> _onPasswordResetRequested(
    PasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const PasswordResetLoadingState());

      await _authRepository.sendPasswordResetEmail(email: event.email);

      emit(const PasswordResetSuccessState());
    } catch (e) {
      emit(PasswordResetErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Email Verification Handler
  // ============================================

  Future<void> _onSendVerificationEmail(
    SendVerificationEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const VerificationEmailLoadingState());

      await _authRepository.sendVerificationEmail();

      emit(const VerificationEmailSentState());
    } catch (e) {
      emit(VerificationEmailErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Tradesman Registration Handlers
  // ============================================

  // ============================================
  // Business Registration Handlers
  // ============================================

  // ============================================
  // Delete Account Handler
  // ============================================

  Future<void> _onDeleteAccount(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const DeleteAccountLoadingState());

      _userDetailsSubscription?.cancel();
      await _authRepository.deleteAccountCompletely();

      emit(const DeleteAccountSuccessState());

      // Wait for state to update then navigate to sign in
      await Future.delayed(const Duration(milliseconds: 100));
      await _authRepository.handleAuthentication();
    } catch (e) {
      emit(
        DeleteAccountErrorState(
          errorMessage: 'Failed to delete account: ${_getErrorMessage(e)}',
        ),
      );
    }
  }

  // ============================================
  // Error Handling
  // ============================================

  Future<void> _onAuthErrorCleared(
    AuthErrorCleared event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      emit(AuthState.authenticated(user, userDetails: state.userDetails));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  /// Extract user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (error is CustomException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    _userDetailsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onHandleAuthentication(
    HandleAuthentication event,
    Emitter<AuthState> emit,
  ) async {
    _authRepository.handleAuthentication();
  }

  // ============================================
  // Update Work Status Handler
  // ============================================

  // ============================================
  // Update User Details Handler
  // ============================================

  Future<void> _onUpdateUserDetails(
    UpdateUserDetailsRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final updates = Map<String, dynamic>.from(event.updates);
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _authRepository.updateUserDetails(updates);
      // The stream listener will automatically update the state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Upload Profile Image Handler
  // ============================================

  // ============================================
  // Company Details Handlers
  // ============================================

}
