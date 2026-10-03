import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../core/enum.dart';
import '../../globals.dart';
import '../../models/address_model.dart';
import '../../models/member_subscription_model.dart';
import '../../models/user_details_model.dart';
import '../../models/user_subscription_container_model.dart';
import '../../repositories/authentication/authentication_repository.dart';
import '../../repositories/tradesman/tradesman_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required TradesmanRepository tradesmanRepository,
  }) : _authRepository = authRepository,
       _tradesmanRepository = tradesmanRepository,
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
    on<TradesmanRegistrationEvent>(_onTradesmanRegistration);
    on<ResetTradesmanRegistrationEvent>(_onResetTradesman);

    // Business registration
    on<BusinessRegistrationEvent>(_onBusinessRegistration);
    on<ResetBusinessRegistrationEvent>(_onResetBusiness);

    // Delete account
    on<DeleteAccountRequested>(_onDeleteAccount);

    // Error handling
    on<AuthErrorCleared>(_onAuthErrorCleared);

    on<HandleAuthentication>(_onHandleAuthentication);

    // Update work status
    on<UpdateWorkStatusRequested>(_onUpdateWorkStatus);

    // Update user details
    on<UpdateUserDetailsRequested>(_onUpdateUserDetails);

    // Upload profile image
    on<UploadProfileImageRequested>(_onUploadProfileImage);

    // Company details
    on<UpdateCompanyDetailsRequested>(_onUpdateCompanyDetails);
    on<SaveBusinessProfileRequested>(_onSaveBusinessProfile);
    on<SaveBankDetailsRequested>(_onSaveBankDetails);
    on<RemoveCompanyDetailsRequested>(_onRemoveCompanyDetails);

    // Listen to auth state changes
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      add(const AuthStarted());
    });
  }

  final AuthRepository _authRepository;
  final TradesmanRepository _tradesmanRepository;
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

      // Block customer accounts (cached check)
      if (cachedDetails != null &&
          cachedDetails.accountType == AccountCategoryType.customer) {
        await _authRepository.signOut();
        emit(const AuthErrorState(
          errorMessage:
              'Access denied. Customer accounts are not allowed to sign in to this app.',
        ));
        return;
      }

      if (cachedDetails != null) {
        emit(AuthState.authenticated(user, userDetails: cachedDetails));
      }

      // Then fetch fresh details (will use cache if offline or cache is fresh)
      final userDetails = await _authRepository.getUserDetails();

      // Block customer accounts (fresh data check)
      if (userDetails != null &&
          userDetails.accountType == AccountCategoryType.customer) {
        await _authRepository.signOut();
        emit(const AuthErrorState(
          errorMessage:
              'Access denied. Customer accounts are not allowed to sign in to this app.',
        ));
        return;
      }

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

  Future<void> _onAuthUserDetailsChanged(
    AuthUserDetailsChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      final previousDetails = state.userDetails;
      final newDetails = event.userDetails;

      emit(AuthState.authenticated(user, userDetails: newDetails));

      // Check if verificationStatus changed for tradesman
      if (newDetails != null &&
          newDetails.accountType == AccountCategoryType.tradesman) {
        final previousStatus = previousDetails?.verificationStatus;
        final newStatus = newDetails.verificationStatus;

        // If status changed, navigate to appropriate screen
        if (previousStatus != null && previousStatus != newStatus) {
          _authRepository.handleAuthentication();
        }
      }
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

  Future<void> _onTradesmanRegistration(
    TradesmanRegistrationEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const TradesmanRegistrationLoadingState());

      final user = _authRepository.currentUser;
      if (user == null) {
        emit(
          const TradesmanRegistrationErrorState(
            message: 'User not authenticated',
          ),
        );
        return;
      }

      await _tradesmanRepository.submitTradesmanRegistration(
        uid: user.uid,
        email: user.email ?? '',
        firstName: event.firstName,
        lastName: event.lastName,
        dateOfBirth: event.dateOfBirth,
        phoneNumber: event.phoneNumber,
        address: event.address,
        nationalInsuranceNumber: event.nationalInsuranceNumber ?? '',
        documentType: event.documentType,
        verificationStatus: VerificationStatus.waiting,
        accountCategoryType: AccountCategoryType.tradesman,
        rejectionReason: "",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        passportImagePath: event.passportImagePath,
        idCardFrontImagePath: event.idCardFrontImagePath,
        idCardBackImagePath: event.idCardBackImagePath,
        driverLicenseFrontImagePath: event.driverLicenseFrontImagePath,
        driverLicenseBackImagePath: event.driverLicenseBackImagePath,
        selfieImagePath: event.selfieImagePath,
        trade: event.trade,
        workStatus: WorkStatus.offline,
        qualificationFiles: event.qualificationFiles,
        hasCompany: event.hasCompany,
        companyName: event.companyName,
        companiesHouseNumber: event.companiesHouseNumber,
        companyEmail: event.companyEmail,
        companyLandline: event.companyLandline,
        companyLogoImagePath: event.companyLogoImagePath,
      );

      emit(const TradesmanRegistrationCompleteState());
    } catch (e) {
      emit(
        TradesmanRegistrationErrorState(
          message: 'Failed to complete registration: ${_getErrorMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onResetTradesman(
    ResetTradesmanRegistrationEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const TradesmanRegistrationInitialState());
  }

  // ============================================
  // Business Registration Handlers
  // ============================================

  Future<void> _onBusinessRegistration(
    BusinessRegistrationEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const BusinessRegistrationLoadingState());

      final user = _authRepository.currentUser;
      if (user == null) {
        emit(
          const BusinessRegistrationErrorState(
            message: 'User not authenticated',
          ),
        );
        return;
      }

      final businessDetails = UserDetailsModel(
        uid: user.uid,
        email: user.email ?? '',
        businessEmail: event.businessEmail,
        businessRegistrationId: event.businessRegistrationId,
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        accountType: AccountCategoryType.business,
        role: event.role,
        address: AddressModel(
          addressLine1: event.address.addressLine1,
          addressLine2: event.address.addressLine2 ?? '',
          city: event.address.city,
          county: event.address.county,
          postcode: event.address.postcode,
        ),
        businessName: event.businessName,
        trade: event.trade,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        subscription: event.role == BusinessRole.owner
            ? UserSubscriptionContainerModel(
                member: MemberSubscriptionModel(
                  subscriptionId: 0,
                  name: 'Standard Free',
                  price: 0,
                  billingCycle: BillingCycle.monthly,
                  planType: PlanType.standard,
                  accountType: AccountCategoryType.business,
                  startDate: DateTime.now(),
                  status: SubscriptionStatus.active,
                ),
              )
            : null,
      );

      await _authRepository.saveUserDetails(userDetails: businessDetails);

      emit(const BusinessRegistrationCompleteState());
    } catch (e) {
      emit(
        BusinessRegistrationErrorState(
          message: 'Failed to complete registration: ${_getErrorMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onResetBusiness(
    ResetBusinessRegistrationEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const BusinessRegistrationInitialState());
  }

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

  Future<void> _onUpdateWorkStatus(
    UpdateWorkStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.updateUserDetails({
        'workStatus': event.workStatus.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      // The stream listener will automatically update the state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

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

  Future<void> _onUploadProfileImage(
    UploadProfileImageRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.uploadProfileImage(event.imagePath);
      // The stream listener will automatically update the state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  // ============================================
  // Company Details Handlers
  // ============================================

  Future<void> _onUpdateCompanyDetails(
    UpdateCompanyDetailsRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _tradesmanRepository.updateCompanyDetails(
        companyName: event.companyName,
        companiesHouseNumber: event.companiesHouseNumber,
        companyEmail: event.companyEmail,
        companyLandline: event.companyLandline,
        companyLogoImagePath: event.companyLogoImagePath,
      );
      // The stream listener will automatically update the state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  Future<void> _onSaveBusinessProfile(
    SaveBusinessProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _tradesmanRepository.saveBusinessProfile(
        companyName: event.companyName,
        phoneNumber: event.phoneNumber,
        website: event.website,
        vatRegistered: event.vatRegistered,
        vatNumber: event.vatNumber,
        logoImagePath: event.logoImagePath,
      );
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  Future<void> _onSaveBankDetails(
    SaveBankDetailsRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _tradesmanRepository.saveBankDetails(
        bankName: event.bankName,
        accountNumber: event.accountNumber,
        sortCode: event.sortCode,
      );
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }

  Future<void> _onRemoveCompanyDetails(
    RemoveCompanyDetailsRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _tradesmanRepository.removeCompanyDetails();
      // The stream listener will automatically update the state
    } catch (e) {
      emit(AuthErrorState(errorMessage: _getErrorMessage(e)));
    }
  }
}
