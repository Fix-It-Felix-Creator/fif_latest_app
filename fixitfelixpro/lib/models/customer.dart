import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? county;
  final String postcode;
  final double? latitude;
  final double? longitude;
  final String? company;
  final String? notes;
  /// Raw formatted address string as returned by the address search provider
  /// (e.g. Nominatim's display_name). Stored verbatim so we can show the user
  /// exactly what they picked, even if our structured fields differ.
  final String? formattedAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.addressLine1 = '',
    this.addressLine2,
    this.city = '',
    this.county,
    this.postcode = '',
    this.latitude,
    this.longitude,
    this.company,
    this.notes,
    this.formattedAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Combined address string for display (backwards compatible)
  String get address {
    final parts = <String>[];
    if (addressLine1.isNotEmpty) parts.add(addressLine1);
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    if (city.isNotEmpty) parts.add(city);
    if (county != null && county!.isNotEmpty) parts.add(county!);
    if (postcode.isNotEmpty) parts.add(postcode);
    return parts.join(', ');
  }

  bool get hasLocation => latitude != null && longitude != null;

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? county,
    String? postcode,
    double? latitude,
    double? longitude,
    String? company,
    String? notes,
    String? formattedAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      county: county ?? this.county,
      postcode: postcode ?? this.postcode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'county': county,
      'postcode': postcode,
      'address': address, // combined string for backwards compatibility
      'latitude': latitude,
      'longitude': longitude,
      'company': company,
      'notes': notes,
      'formattedAddress': formattedAddress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json, String id) {
    // Support both new structured fields and old single 'address' field
    final hasStructuredAddress = json['addressLine1'] != null;

    return Customer(
      id: id,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      addressLine1: hasStructuredAddress
          ? json['addressLine1'] as String? ?? ''
          : json['address'] as String? ?? '',
      addressLine2: json['addressLine2'] as String?,
      city: json['city'] as String? ?? '',
      county: json['county'] as String?,
      postcode: json['postcode'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      company: json['company'] as String?,
      notes: json['notes'] as String?,
      formattedAddress: json['formattedAddress'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    addressLine1,
    addressLine2,
    city,
    county,
    postcode,
    latitude,
    longitude,
    company,
    notes,
    formattedAddress,
    createdAt,
    updatedAt,
  ];
}
