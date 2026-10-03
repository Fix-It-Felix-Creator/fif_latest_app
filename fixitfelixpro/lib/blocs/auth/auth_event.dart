import 'package:equatable/equatable.dart';
import 'package:fixitfelix/models/address_model.dart';

import '../../core/enum.dart';
import '../../models/user_details_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// ============================================
// App Lifecycle Events
// ============================================

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthUserDetailsChanged extends AuthEvent {
  final UserDetailsModel? userDetails;

  const AuthUserDetailsChanged(this.userDetails);

  @override
  List<Object?> get props => [userDetails];
}

class AuthUserRefreshed extends AuthEvent {
  const AuthUserRefreshed();
}

// ============================================
// Sign In Events
// ============================================

class SignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignInWithGoogleRequested extends AuthEvent {
  const SignInWithGoogleRequested();
}

class SignInWithAppleRequested extends AuthEvent {
  const SignInWithAppleRequested();
}

// ============================================
// Sign Up Events
// ============================================

class SignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const SignUpWithEmailRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

// ============================================
// Sign Out Event
// ============================================

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Event triggered when user is force logged out from another device
class AuthForceLogoutRequested extends AuthEvent {
  final String reason;

  const AuthForceLogoutRequested({required this.reason});

  @override
  List<Object?> get props => [reason];
}

// ============================================
// Password Reset Events
// ============================================

class PasswordResetRequested extends AuthEvent {
  final String email;

  const PasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

// ============================================
// Email Verification Events
// ============================================

class SendVerificationEmailRequested extends AuthEvent {
  const SendVerificationEmailRequested();
}

// ============================================
// Tradesman Registration Events
// ============================================

class TradesmanRegistrationEvent extends AuthEvent {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final AddressModel address;
  final DateTime? dateOfBirth;
  final String? nationalInsuranceNumber;
  final String? trade;
  final DocumentType documentType;

  // Image paths for upload
  final String? passportImagePath;
  final String? idCardFrontImagePath;
  final String? idCardBackImagePath;
  final String? driverLicenseFrontImagePath;
  final String? driverLicenseBackImagePath;
  final String? selfieImagePath;
  final AccountCategoryType accountCategoryType;

  // Trade qualification file paths (requirementId -> localPath)
  final Map<String, String>? qualificationFiles;

  // Company details (optional)
  final bool hasCompany;
  final String? companyName;
  final String? companiesHouseNumber;
  final String? companyEmail;
  final String? companyLandline;
  final String? companyLogoImagePath;

  const TradesmanRegistrationEvent({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.address,
    this.dateOfBirth,
    this.nationalInsuranceNumber,
    required this.accountCategoryType,
    this.trade,
    required this.documentType,
    this.passportImagePath,
    this.idCardFrontImagePath,
    this.idCardBackImagePath,
    this.driverLicenseFrontImagePath,
    this.driverLicenseBackImagePath,
    this.selfieImagePath,
    this.qualificationFiles,
    this.hasCompany = false,
    this.companyName,
    this.companiesHouseNumber,
    this.companyEmail,
    this.companyLandline,
    this.companyLogoImagePath,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    phoneNumber,
    address,
    dateOfBirth,
    nationalInsuranceNumber,
    trade,
    documentType,
    passportImagePath,
    idCardFrontImagePath,
    idCardBackImagePath,
    driverLicenseFrontImagePath,
    driverLicenseBackImagePath,
    selfieImagePath,
    accountCategoryType,
    qualificationFiles,
    hasCompany,
    companyName,
    companiesHouseNumber,
    companyEmail,
    companyLandline,
    companyLogoImagePath,
  ];
}

class ResetTradesmanRegistrationEvent extends AuthEvent {
  const ResetTradesmanRegistrationEvent();
}

// ============================================
// Business Registration Events
// ============================================

class BusinessRegistrationEvent extends AuthEvent {
  final String? businessEmail;
  final String? businessRegistrationId;
  final String? firstName;
  final String? lastName;
  final String phoneNumber;
  final AccountCategoryType accountType;
  final BusinessRole role;
  final AddressModel address;
  final String? businessName;
  final List<String>? trade;

  const BusinessRegistrationEvent({
    this.businessEmail,
    this.businessRegistrationId,
    this.firstName,
    this.lastName,
    required this.phoneNumber,
    required this.accountType,
    required this.role,
    required this.address,
    this.businessName,
    this.trade,
  });

  @override
  List<Object?> get props => [
    businessEmail,
    businessRegistrationId,
    firstName,
    lastName,
    phoneNumber,
    accountType,
    role,
    address,
    businessName,
    trade,
  ];
}

class ResetBusinessRegistrationEvent extends AuthEvent {
  const ResetBusinessRegistrationEvent();
}

// ============================================
// Delete Account Event
// ============================================

class DeleteAccountRequested extends AuthEvent {
  const DeleteAccountRequested();
}

// ============================================
// Clear Error Event
// ============================================

class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}

class HandleAuthentication extends AuthEvent {
  const HandleAuthentication();
}

// ============================================
// Update Work Status Event
// ============================================

class UpdateWorkStatusRequested extends AuthEvent {
  final WorkStatus workStatus;

  const UpdateWorkStatusRequested({required this.workStatus});

  @override
  List<Object?> get props => [workStatus];
}

// ============================================
// Update User Details Event
// ============================================

class UpdateUserDetailsRequested extends AuthEvent {
  final Map<String, dynamic> updates;

  const UpdateUserDetailsRequested({required this.updates});

  @override
  List<Object?> get props => [updates];
}

// ============================================
// Upload Profile Image Event
// ============================================

class UploadProfileImageRequested extends AuthEvent {
  final String imagePath;

  const UploadProfileImageRequested({required this.imagePath});

  @override
  List<Object?> get props => [imagePath];
}

// ============================================
// Company Details Events
// ============================================

class UpdateCompanyDetailsRequested extends AuthEvent {
  final String companyName;
  final String companiesHouseNumber;
  final String companyEmail;
  final String? companyLandline;
  final String? companyLogoImagePath;

  const UpdateCompanyDetailsRequested({
    required this.companyName,
    required this.companiesHouseNumber,
    required this.companyEmail,
    this.companyLandline,
    this.companyLogoImagePath,
  });

  @override
  List<Object?> get props => [
    companyName,
    companiesHouseNumber,
    companyEmail,
    companyLandline,
    companyLogoImagePath,
  ];
}

class RemoveCompanyDetailsRequested extends AuthEvent {
  const RemoveCompanyDetailsRequested();
}

class SaveBankDetailsRequested extends AuthEvent {
  final String bankName;
  final String accountNumber;
  final String sortCode;

  const SaveBankDetailsRequested({
    required this.bankName,
    required this.accountNumber,
    required this.sortCode,
  });

  @override
  List<Object?> get props => [bankName, accountNumber, sortCode];
}

class SaveBusinessProfileRequested extends AuthEvent {
  final String companyName;
  final String phoneNumber;
  final String? website;
  final bool vatRegistered;
  final String? vatNumber;
  final String? logoImagePath;

  const SaveBusinessProfileRequested({
    required this.companyName,
    required this.phoneNumber,
    this.website,
    required this.vatRegistered,
    this.vatNumber,
    this.logoImagePath,
  });

  @override
  List<Object?> get props => [
    companyName,
    phoneNumber,
    website,
    vatRegistered,
    vatNumber,
    logoImagePath,
  ];
}
