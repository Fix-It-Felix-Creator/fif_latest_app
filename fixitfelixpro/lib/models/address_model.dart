import 'package:equatable/equatable.dart';

class AddressModel extends Equatable {
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? county;
  final String postcode;

  const AddressModel({
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    this.county = '',
    required this.postcode,
  });

  AddressModel copyWith({
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? county,
    String? postcode,
  }) {
    return AddressModel(
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      county: county ?? this.county,
      postcode: postcode ?? this.postcode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'county': county,
      'postcode': postcode,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      addressLine1: json['addressLine1'] ?? '',
      addressLine2: json['addressLine2'] ?? '',
      city: json['city'] ?? '',
      county: json['county'] ?? '',
      postcode: json['postcode'] ?? '',
    );
  }

  /// Create an empty address
  factory AddressModel.empty() {
    return const AddressModel(
      addressLine1: '',
      addressLine2: '',
      city: '',
      county: '',
      postcode: '',
    );
  }

  /// Check if address is empty
  bool get isEmpty =>
      addressLine1.isEmpty &&
      city.isEmpty &&
      (county ?? '').isEmpty &&
      postcode.isEmpty;

  /// Check if address is valid (has required fields)
  /// Note: county is optional - many UK addresses don't have one
  bool get isValid =>
      addressLine1.isNotEmpty &&
      city.isNotEmpty &&
      postcode.isNotEmpty;

  /// Get formatted address string
  String get formatted {
    final parts = <String>[];
    if (addressLine1.isNotEmpty) parts.add(addressLine1);
    if (addressLine2 != null && addressLine2!.isNotEmpty) parts.add(addressLine2!);
    if (city.isNotEmpty) parts.add(city);
    if (county != null && county!.isNotEmpty) parts.add(county!);
    if (postcode.isNotEmpty) parts.add(postcode);
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
    addressLine1,
    addressLine2,
    city,
    county,
    postcode,
  ];
}
