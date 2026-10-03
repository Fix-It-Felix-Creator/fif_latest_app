import 'package:equatable/equatable.dart';

import 'bank_details_model.dart';

class CompanyDetailsModel extends Equatable {
  final String companyName;
  final String companiesHouseNumber;
  final String? companyLogoUrl;
  final String companyEmail;
  final String? companyLandline;
  final String? website;
  final bool vatRegistered;
  final String? vatNumber;
  final BankDetailsModel? bankDetails;

  const CompanyDetailsModel({
    required this.companyName,
    required this.companiesHouseNumber,
    this.companyLogoUrl,
    required this.companyEmail,
    this.companyLandline,
    this.website,
    this.vatRegistered = false,
    this.vatNumber,
    this.bankDetails,
  });

  bool get isEmpty =>
      companyName.isEmpty &&
      companiesHouseNumber.isEmpty &&
      companyEmail.isEmpty;

  bool get isNotEmpty => !isEmpty;

  CompanyDetailsModel copyWith({
    String? companyName,
    String? companiesHouseNumber,
    String? companyLogoUrl,
    String? companyEmail,
    String? companyLandline,
    String? website,
    bool? vatRegistered,
    String? vatNumber,
    BankDetailsModel? bankDetails,
  }) {
    return CompanyDetailsModel(
      companyName: companyName ?? this.companyName,
      companiesHouseNumber:
          companiesHouseNumber ?? this.companiesHouseNumber,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      companyEmail: companyEmail ?? this.companyEmail,
      companyLandline: companyLandline ?? this.companyLandline,
      website: website ?? this.website,
      vatRegistered: vatRegistered ?? this.vatRegistered,
      vatNumber: vatNumber ?? this.vatNumber,
      bankDetails: bankDetails ?? this.bankDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'companiesHouseNumber': companiesHouseNumber,
      'companyLogoUrl': companyLogoUrl,
      'companyEmail': companyEmail,
      'companyLandline': companyLandline,
      'website': website,
      'vatRegistered': vatRegistered,
      'vatNumber': vatNumber,
      'bankDetails': bankDetails?.toJson(),
    };
  }

  factory CompanyDetailsModel.fromJson(Map<String, dynamic> json) {
    final bank = json['bankDetails'];
    return CompanyDetailsModel(
      companyName: json['companyName'] as String? ?? '',
      companiesHouseNumber: json['companiesHouseNumber'] as String? ?? '',
      companyLogoUrl: json['companyLogoUrl'] as String?,
      companyEmail: json['companyEmail'] as String? ?? '',
      companyLandline: json['companyLandline'] as String?,
      website: json['website'] as String?,
      vatRegistered: json['vatRegistered'] as bool? ?? false,
      vatNumber: json['vatNumber'] as String?,
      bankDetails: bank is Map
          ? BankDetailsModel.fromJson(Map<String, dynamic>.from(bank))
          : null,
    );
  }

  @override
  List<Object?> get props => [
    companyName,
    companiesHouseNumber,
    companyLogoUrl,
    companyEmail,
    companyLandline,
    website,
    vatRegistered,
    vatNumber,
    bankDetails,
  ];
}
