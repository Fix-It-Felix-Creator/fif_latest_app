import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'address_model.dart';
import 'user_subscription_container_model.dart';

class BusinessModel extends Equatable {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String phoneNumber;
  final AccountCategoryType accountType;
  final BusinessRole role;
  final AddressModel address;
  final String? businessName;
  final String? businessEmail;
  final String? businessRegistrationId;
  final List<String>? trade;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSubscriptionContainerModel? subscription;
  final String? profileImage;
  final String? subscriptionPlanSelected;

  const BusinessModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.accountType,
    required this.role,
    required this.address,
    this.businessName,
    required this.createdAt,
    required this.updatedAt,
    this.subscription,
    this.trade,
    this.businessEmail,
    this.businessRegistrationId,
    this.profileImage,
    this.subscriptionPlanSelected,
  });

  BusinessModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    AccountCategoryType? accountType,
    BusinessRole? role,
    AddressModel? address,
    String? businessName,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserSubscriptionContainerModel? subscription,
    List<String>? trade,
    String? businessEmail,
    String? businessRegistrationId,
    final String? profileImage,
    String? subscriptionPlanSelected,
  }) {
    return BusinessModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountType: accountType ?? this.accountType,
      role: role ?? this.role,
      address: address ?? this.address,
      businessName: businessName ?? this.businessName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscription: subscription ?? this.subscription,
      trade: trade ?? this.trade,
      businessEmail: businessEmail ?? this.businessEmail,
      businessRegistrationId:
          businessRegistrationId ?? this.businessRegistrationId,
      profileImage: profileImage ?? this.profileImage,
      subscriptionPlanSelected:
          subscriptionPlanSelected ?? this.subscriptionPlanSelected,
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
      'businessName': businessName,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subscription': subscription?.toJson(),
      'trade': trade,
      'businessEmail': businessEmail,
      'businessRegistrationId': businessRegistrationId,
      'profileImage': profileImage,
      'subscriptionPlanSelected': subscriptionPlanSelected,
    };
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
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
      businessName: json['businessName'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      subscription: json['subscription'] != null
          ? UserSubscriptionContainerModel.fromJsonAuto(
              Map<String, dynamic>.from(json['subscription']),
            )
          : null,
      role: BusinessRole.values.firstWhere((e) => e.name == json['role']),
      trade: json['trade'],
      businessEmail: json['businessEmail'],
      businessRegistrationId: json['businessRegistrationId'],
      profileImage: json['profileImage'],
      subscriptionPlanSelected: json['subscriptionPlanSelected'],
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
    businessName,
    createdAt,
    updatedAt,
    subscription,
    role,
    trade,
    businessEmail,
    businessRegistrationId,
    profileImage,
    subscriptionPlanSelected,
  ];
}
