import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'address_model.dart';
import 'company_details_model.dart';
import 'location_model.dart';
import 'notification_preferences_model.dart';
import 'user_subscription_container_model.dart';

class UserDetailsModel extends Equatable {
  // Common fields
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String phoneNumber;
  final AccountCategoryType accountType;
  final String? profileImage;

  // Address
  final AddressModel address;

  // Location (GPS coordinates)
  final LocationModel? location;

  // Business
  final BusinessRole? role;
  final String? businessName;
  final String? businessEmail;
  final String? businessRegistrationId;

  // Tradesman
  final DateTime? dateOfBirth;
  final String? nationalInsuranceNumber;
  final List<String>? documentUrls;
  final String? documentType;
  final List<String>? trade;
  final String? selfieUrl;
  final VerificationStatus? verificationStatus;
  final String? rejectionReason;
  final String? workStatus;

  // General
  final DateTime createdAt;
  final DateTime updatedAt;

  // Address update tracking
  final DateTime? lastAddressUpdatedAt;

  // Subscription (contains member and tool subscriptions)
  final UserSubscriptionContainerModel? subscription;

  /// Selected subscription plan ID
  final String? subscriptionPlanSelected;

  /// Social media / portfolio links
  final List<String>? links;

  /// Notification preferences (push, email, SMS)
  final NotificationPreferencesModel notificationPreferences;

  /// User bio/description (short, max 150 words - displayed on profile)
  final String? bio;

  /// Introduction bio (detailed, max 500 words)
  final String? introductionBio;

  /// Company details (tradesman only, optional)
  final CompanyDetailsModel? companyDetails;

  /// Preferred currency code (e.g. 'GBP')
  final String currency;

  const UserDetailsModel({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    required this.phoneNumber,
    required this.accountType,
    required this.address,
    this.location,
    this.businessName,
    this.dateOfBirth,
    this.nationalInsuranceNumber,
    this.documentUrls,
    this.documentType,
    this.trade,
    this.businessEmail,
    this.businessRegistrationId,
    this.selfieUrl,
    this.verificationStatus,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.lastAddressUpdatedAt,
    this.subscription,
    this.role,
    this.workStatus,
    this.profileImage,
    this.subscriptionPlanSelected,
    this.links,
    this.notificationPreferences = const NotificationPreferencesModel(),
    this.bio,
    this.introductionBio,
    this.companyDetails,
    this.currency = 'GBP',
  });

  UserDetailsModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    AccountCategoryType? accountType,
    AddressModel? address,
    LocationModel? location,
    String? businessName,
    DateTime? dateOfBirth,
    String? nationalInsuranceNumber,
    List<String>? documentUrls,
    String? documentType,
    List<String>? trade,
    String? selfieUrl,
    VerificationStatus? verificationStatus,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAddressUpdatedAt,
    UserSubscriptionContainerModel? subscription,
    BusinessRole? role,
    String? businessEmail,
    String? businessRegistrationId,
    String? workStatus,
    String? profileImage,
    String? subscriptionPlanSelected,
    List<String>? links,
    NotificationPreferencesModel? notificationPreferences,
    String? bio,
    String? introductionBio,
    CompanyDetailsModel? companyDetails,
    String? currency,
  }) {
    return UserDetailsModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      address: address ?? this.address,
      location: location ?? this.location,
      businessName: businessName ?? this.businessName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      nationalInsuranceNumber:
          nationalInsuranceNumber ?? this.nationalInsuranceNumber,
      documentUrls: documentUrls ?? this.documentUrls,
      documentType: documentType ?? this.documentType,
      trade: trade ?? this.trade,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAddressUpdatedAt: lastAddressUpdatedAt ?? this.lastAddressUpdatedAt,
      subscription: subscription ?? this.subscription,
      role: role ?? this.role,
      businessEmail: businessEmail ?? this.businessEmail,
      businessRegistrationId:
          businessRegistrationId ?? this.businessRegistrationId,
      workStatus: workStatus ?? this.workStatus,
      profileImage: profileImage ?? this.profileImage,
      subscriptionPlanSelected:
          subscriptionPlanSelected ?? this.subscriptionPlanSelected,
      links: links ?? this.links,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      bio: bio ?? this.bio,
      introductionBio: introductionBio ?? this.introductionBio,
      companyDetails: companyDetails ?? this.companyDetails,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'accountType': accountType.name,
      'address': address.toJson(),
      'location': location?.toJson(),
      'businessName': businessName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'nationalInsuranceNumber': nationalInsuranceNumber,
      'documentUrls': documentUrls,
      'documentType': documentType,
      'trade': trade,
      'selfieUrl': selfieUrl,
      'verificationStatus': verificationStatus?.name,
      'rejectionReason': rejectionReason,
      'role': role?.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastAddressUpdatedAt': lastAddressUpdatedAt?.toIso8601String(),
      'subscription': subscription?.toJson(),
      'businessEmail': businessEmail,
      'businessRegistrationId': businessRegistrationId,
      'workStatus': workStatus,
      'profileImage': profileImage,
      'subscriptionPlanSelected': subscriptionPlanSelected,
      'links': links,
      'notificationPreferences': notificationPreferences.toJson(),
      'bio': bio,
      'introductionBio': introductionBio,
      'companyDetails': companyDetails?.toJson(),
      'currency': currency,
    };
  }

  factory UserDetailsModel.fromJson(Map<String, dynamic> json) {
    return UserDetailsModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      accountType: AccountCategoryType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            json['accountType']?.toString().toLowerCase(),
        orElse: () => AccountCategoryType.tradesman,
      ),
      address: json['address'] != null
          ? AddressModel.fromJson(Map<String, dynamic>.from(json['address']))
          : AddressModel.empty(),
      location: json['location'] != null
          ? LocationModel.fromJson(Map<String, dynamic>.from(json['location']))
          : null,
      businessName: json['businessName'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      nationalInsuranceNumber: json['nationalInsuranceNumber'] as String?,
      documentUrls: json['documentUrls'] != null
          ? List<String>.from(json['documentUrls'])
          : null,
      documentType: json['documentType'] as String?,
      role: json['role'] != null
          ? BusinessRole.values.firstWhere(
              (e) => e.name == json['role'],
              orElse: () => BusinessRole.owner,
            )
          : null,
      trade: json['trade'] != null
          ? (json['trade'] is String
                ? [json['trade'] as String]
                : List<String>.from(json['trade']))
          : null,
      selfieUrl: json['selfieUrl'] as String?,
      verificationStatus: json['verificationStatus'] != null
          ? VerificationStatus.values.firstWhere(
              (e) => e.name == json['verificationStatus'],
              orElse: () => VerificationStatus.unverified,
            )
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastAddressUpdatedAt: json['lastAddressUpdatedAt'] != null
          ? DateTime.tryParse(json['lastAddressUpdatedAt'].toString())
          : null,
      subscription: json['subscription'] != null
          ? UserSubscriptionContainerModel.fromJsonAuto(
              Map<String, dynamic>.from(json['subscription']),
            )
          : null,
      businessEmail: json['businessEmail'] as String?,
      businessRegistrationId: json['businessRegistrationId'] as String?,
      workStatus: json['workStatus'] as String?,
      profileImage: json['profileImage'] as String?,
      subscriptionPlanSelected: json['subscriptionPlanSelected'] as String?,
      links: json['links'] != null ? List<String>.from(json['links']) : null,
      notificationPreferences: json['notificationPreferences'] != null
          ? NotificationPreferencesModel.fromJson(
              Map<String, dynamic>.from(json['notificationPreferences']),
            )
          : NotificationPreferencesModel.defaultEnabled(),
      bio: json['bio'] as String?,
      introductionBio: json['introductionBio'] as String?,
      companyDetails: json['companyDetails'] != null
          ? CompanyDetailsModel.fromJson(
              Map<String, dynamic>.from(json['companyDetails']),
            )
          : null,
      currency: json['currency'] as String? ?? 'GBP',
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    firstName,
    lastName,
    phoneNumber,
    accountType,
    address,
    location,
    businessName,
    dateOfBirth,
    nationalInsuranceNumber,
    documentUrls,
    documentType,
    trade,
    selfieUrl,
    verificationStatus,
    rejectionReason,
    createdAt,
    updatedAt,
    lastAddressUpdatedAt,
    subscription,
    role,
    businessEmail,
    businessRegistrationId,
    workStatus,
    profileImage,
    subscriptionPlanSelected,
    links,
    notificationPreferences,
    bio,
    introductionBio,
    companyDetails,
    currency,
  ];
}
