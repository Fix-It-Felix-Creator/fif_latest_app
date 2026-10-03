import '../../core/config/environment_variables.dart';
import '../../models/app_user.dart';
import '../../models/user_details_model.dart';
import '../../models/user_subscription_model.dart';

/// Contract for authentication.
///
/// Migration note: this interface used to expose Firebase's `User` and
/// `UserCredential` directly, which leaked the auth provider into the bloc
/// layer and three screens. It now speaks [AppUser], an app-owned type, so
/// swapping providers never again reaches the UI.
///
/// Actions that used to hang off Firebase's `User` object — `reload()`,
/// `sendEmailVerification()`, `updateDisplayName()`, `delete()`,
/// `getIdToken()` — are methods here instead, which is where Supabase
/// exposes them.
abstract class BaseAuthenticationRepository {
  // ============================================
  // Configuration
  // ============================================
  void setENVConfig(EnvironmentVariables envData);

  // ============================================
  // Authentication State
  // ============================================
  AppUser? get currentUser;
  Stream<AppUser?> get authStateChanges;
  bool get isLoggedIn;

  /// Access token for the current session, used when calling backend
  /// functions. Replaces `User.getIdToken()`.
  Future<String?> getAccessToken();

  // ============================================
  // Email Verification
  // ============================================
  bool isEmailVerified();
  Future<void> sendVerificationEmail();
  Future<void> refreshUserVerificationStatus();

  // ============================================
  // Sign In / Sign Up
  // ============================================
  /// Returns the signed-in user. Throws [CustomException] on failure.
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Returns null when the user cancels the provider flow.
  Future<AppUser?> signInWithGoogle();

  Future<AppUser?> signInWithApple();

  Future<void> signOut();

  // ============================================
  // Password Management
  // ============================================
  Future<void> sendPasswordResetEmail({required String email});

  /// Sets a new password for the signed-in user.
  Future<void> updatePassword({required String newPassword});

  // ============================================
  // Profile
  // ============================================
  /// Replaces `User.updateDisplayName()`.
  Future<void> updateDisplayName(String displayName);

  // ============================================
  // User Details CRUD
  // ============================================
  Future<UserDetailsModel?> getUserDetails({bool forceRefresh = false});
  UserDetailsModel? getCachedUserDetails();
  Future<void> saveUserDetails({required UserDetailsModel userDetails});
  Future<void> updateUserDetails(Map<String, dynamic> updates);
  Stream<UserDetailsModel?> streamUserDetails();

  // ============================================
  // User Profile
  // ============================================
  Future<bool> hasCompletedProfile();
  Future<String?> getUserRole();
  Future<String> uploadProfileImage(String localPath);

  // ============================================
  // Subscription
  // ============================================
  Future<void> updateSubscription(
    UserSubscriptionModel subscription, {
    bool resetUsage = false,
  });

  // ============================================
  // Account Management
  // ============================================
  Future<void> deleteAccountCompletely();
  Future<void> deleteUserDetails();
  Future<void> deleteUserDocuments();
  Future<void> clearUserCache();

  // ============================================
  // Navigation
  // ============================================
  Future<void> handleAuthentication();
}
