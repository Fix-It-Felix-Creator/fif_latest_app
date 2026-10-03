import 'package:equatable/equatable.dart';

import '../../models/app_user.dart';

import '../../models/user_details_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState._({
    this.status = AuthStatus.unknown,
    this.user,
    this.userDetails,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  // Factory constructors for main auth states
  const AuthState.unknown() : this._();

  const AuthState.authenticated(AppUser user, {UserDetailsModel? userDetails})
    : this._(
        status: AuthStatus.authenticated,
        user: user,
        userDetails: userDetails,
      );

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final AppUser? user;
  final UserDetailsModel? userDetails;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  /// Check if user's email is verified
  bool get isEmailVerified => user?.emailVerified ?? false;

  /// Check if user has completed profile.
  ///
  /// First name only. Last name is optional everywhere in this app — Google
  /// and Apple may return no surname — so requiring it would disagree with
  /// _needsOnboarding and with the onboarding form's own Continue gate. The
  /// pro app's business-owner branch is gone with the account types it read.
  bool get hasCompletedProfile =>
      userDetails?.firstName?.isNotEmpty == true;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    UserDetailsModel? userDetails,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      userDetails: userDetails ?? this.userDetails,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    userDetails,
    isLoading,
    errorMessage,
    successMessage,
  ];
}

// ============================================
// Auth Operation States (for UI feedback)
// ============================================

class AuthLoadingState extends AuthState {
  final String? loadingMessage;

  const AuthLoadingState({this.loadingMessage})
    : super._(isLoading: true, status: AuthStatus.unknown);

  @override
  List<Object?> get props => [loadingMessage];
}

class AuthErrorState extends AuthState {
  @override
  final String errorMessage;

  const AuthErrorState({required this.errorMessage})
    : super._(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class AuthSuccessState extends AuthState {
  @override
  final String successMessage;

  const AuthSuccessState({required this.successMessage})
    : super._(successMessage: successMessage);

  @override
  List<Object?> get props => [successMessage];
}

// ============================================
// Password Reset States
// ============================================

class PasswordResetLoadingState extends AuthState {
  const PasswordResetLoadingState() : super._(isLoading: true);
}

class PasswordResetSuccessState extends AuthState {
  const PasswordResetSuccessState()
    : super._(
        successMessage: 'Password reset email sent. Please check your inbox.',
      );
}

class PasswordResetErrorState extends AuthState {
  @override
  final String errorMessage;

  const PasswordResetErrorState({required this.errorMessage})
    : super._(errorMessage: errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

// ============================================
// Email Verification States
// ============================================

class VerificationEmailLoadingState extends AuthState {
  const VerificationEmailLoadingState() : super._(isLoading: true);
}

class VerificationEmailSentState extends AuthState {
  const VerificationEmailSentState()
    : super._(
        successMessage: 'Verification email sent. Please check your inbox.',
      );
}

class VerificationEmailErrorState extends AuthState {
  @override
  final String errorMessage;

  const VerificationEmailErrorState({required this.errorMessage})
    : super._(errorMessage: errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

// ============================================
// Tradesman Registration States
// ============================================

class TradesmanRegistrationInitialState extends AuthState {
  const TradesmanRegistrationInitialState() : super._();
}

class TradesmanRegistrationLoadingState extends AuthState {
  const TradesmanRegistrationLoadingState() : super._(isLoading: true);
}

class TradesmanRegistrationCompleteState extends AuthState {
  const TradesmanRegistrationCompleteState()
    : super._(successMessage: 'Registration completed successfully.');
}

class TradesmanRegistrationErrorState extends AuthState {
  final String message;

  const TradesmanRegistrationErrorState({required this.message})
    : super._(errorMessage: message);

  @override
  List<Object?> get props => [message];
}

// ============================================
// Business Registration States
// ============================================

class BusinessRegistrationInitialState extends AuthState {
  const BusinessRegistrationInitialState() : super._();
}

class BusinessRegistrationLoadingState extends AuthState {
  const BusinessRegistrationLoadingState() : super._(isLoading: true);
}

class BusinessRegistrationCompleteState extends AuthState {
  const BusinessRegistrationCompleteState()
    : super._(successMessage: 'Business registration completed successfully.');
}

class BusinessRegistrationErrorState extends AuthState {
  final String message;

  const BusinessRegistrationErrorState({required this.message})
    : super._(errorMessage: message);

  @override
  List<Object?> get props => [message];
}

// ============================================
// Delete Account States
// ============================================

class DeleteAccountLoadingState extends AuthState {
  const DeleteAccountLoadingState() : super._(isLoading: true);
}

class DeleteAccountSuccessState extends AuthState {
  const DeleteAccountSuccessState()
    : super._(successMessage: 'Account deleted successfully.');
}

class DeleteAccountErrorState extends AuthState {
  @override
  final String errorMessage;

  const DeleteAccountErrorState({required this.errorMessage})
    : super._(errorMessage: errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

// ============================================
// Force Logout State
// ============================================

/// State emitted when user is forcibly logged out from another device
class ForceLogoutState extends AuthState {
  final String reason;

  const ForceLogoutState({required this.reason})
    : super._(status: AuthStatus.unauthenticated);

  @override
  List<Object?> get props => [reason];
}
