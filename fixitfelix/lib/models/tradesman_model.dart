import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'address_model.dart';
import 'extra_document_model.dart';
import 'user_subscription_container_model.dart';

class TradesmanModel extends Equatable {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final AccountCategoryType accountType;
  final AddressModel address;

  final DateTime? dateOfBirth;
  final String? nationalInsuranceNumber;

  final List<String>? documentUrls;
  final String? documentType;

  final String? trade;
  final String? selfieUrl;

  final VerificationStatus verificationStatus;
  final String? rejectionReason;

  final DateTime createdAt;
  final DateTime updatedAt;

  final UserSubscriptionContainerModel? subscription;

  final String? profileImage;
  final WorkStatus? workStatus;

  /// Extra documents/certificates uploaded by tradesman
  final List<ExtraDocumentModel>? extraDocuments;

  /// Selected subscription plan ID
  final String? subscriptionPlanSelected;

  /// Social media / portfolio links
  final List<String>? links;

  const TradesmanModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.accountType,
    required this.address,
    this.dateOfBirth,
    this.nationalInsuranceNumber,
    this.documentUrls,
    this.documentType,
    this.trade,
    this.selfieUrl,
    required this.verificationStatus,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.subscription,
    this.profileImage,
    this.workStatus,
    this.extraDocuments,
    this.subscriptionPlanSelected,
    this.links,
  });

  TradesmanModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    AccountCategoryType? accountType,
    AddressModel? address,
    DateTime? dateOfBirth,
    String? nationalInsuranceNumber,
    List<String>? documentUrls,
    String? documentType,
    String? trade,
    String? selfieUrl,
    VerificationStatus? verificationStatus,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserSubscriptionContainerModel? subscription,
    final String? profileImage,
    final WorkStatus? workStatus,
    List<ExtraDocumentModel>? extraDocuments,
    String? subscriptionPlanSelected,
    List<String>? links,
  }) {
    return TradesmanModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      address: address ?? this.address,
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
      subscription: subscription ?? this.subscription,
      profileImage: profileImage ?? this.profileImage,
      workStatus: workStatus ?? this.workStatus,
      extraDocuments: extraDocuments ?? this.extraDocuments,
      subscriptionPlanSelected:
          subscriptionPlanSelected ?? this.subscriptionPlanSelected,
      links: links ?? this.links,
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
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'nationalInsuranceNumber': nationalInsuranceNumber,
      'documentUrls': documentUrls,
      'documentType': documentType,
      'trade': trade,
      'selfieUrl': selfieUrl,
      'verificationStatus': verificationStatus.name,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subscription': subscription?.toJson(),
      'profileImage': profileImage,
      'workStatus': workStatus,
      'extraDocuments': extraDocuments?.map((e) => e.toJson()).toList(),
      'subscriptionPlanSelected': subscriptionPlanSelected,
      'links': links,
    };
  }

  factory TradesmanModel.fromJson(Map<String, dynamic> json) {
    return TradesmanModel(
      uid: json['uid'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      phoneNumber: json['phoneNumber'],
      accountType: AccountCategoryType.values.firstWhere(
        (e) => e.name == json['accountType'],
      ),
      address: json['address'] != null
          ? AddressModel.fromJson(json['address'])
          : AddressModel.empty(),
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      nationalInsuranceNumber: json['nationalInsuranceNumber'],
      documentUrls: json['documentUrls'] != null
          ? List<String>.from(json['documentUrls'])
          : null,
      documentType: json['documentType'],
      trade: json['trade'],
      selfieUrl: json['selfieUrl'],
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verificationStatus'],
      ),
      rejectionReason: json['rejectionReason'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      subscription: json['subscription'] != null
          ? UserSubscriptionContainerModel.fromJsonAuto(
              Map<String, dynamic>.from(json['subscription']),
            )
          : null,
      profileImage: json['profileImage'],
      workStatus: json['workStatus'],
      extraDocuments: json['extraDocuments'] != null
          ? (json['extraDocuments'] as List)
                .map(
                  (e) => ExtraDocumentModel.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : null,
      subscriptionPlanSelected: json['subscriptionPlanSelected'],
      links: json['links'] != null ? List<String>.from(json['links']) : null,
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
    subscription,
    profileImage,
    workStatus,
    extraDocuments,
    subscriptionPlanSelected,
    links,
  ];
}
