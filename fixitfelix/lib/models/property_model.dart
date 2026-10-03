import 'package:equatable/equatable.dart';

import 'address_model.dart';

enum PropertyType { apartment, house, commercial, condo, land, other }

enum PropertyStatus { occupied, vacant, maintenance }

class PropertyModel extends Equatable {
  final String id;
  final String name;
  final AddressModel address;
  final PropertyType type;
  final PropertyStatus status;
  final String? imageUrl;
  final String? notes;
  final int activeJobs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PropertyModel({
    required this.id,
    required this.name,
    required this.address,
    this.type = PropertyType.house,
    this.status = PropertyStatus.vacant,
    this.imageUrl,
    this.notes,
    this.activeJobs = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  PropertyModel copyWith({
    String? id,
    String? name,
    AddressModel? address,
    PropertyType? type,
    PropertyStatus? status,
    String? imageUrl,
    String? notes,
    int? activeJobs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      activeJobs: activeJobs ?? this.activeJobs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address.toJson(),
      'type': type.name,
      'status': status.name,
      'imageUrl': imageUrl,
      'notes': notes,
      'activeJobs': activeJobs,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PropertyModel.fromJson(Map<String, dynamic> json, String id) {
    return PropertyModel(
      id: id,
      name: json['name'] ?? '',
      address: json['address'] != null
          ? AddressModel.fromJson(Map<String, dynamic>.from(json['address']))
          : AddressModel.empty(),
      type: PropertyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PropertyType.house,
      ),
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.vacant,
      ),
      imageUrl: json['imageUrl'],
      notes: json['notes'],
      activeJobs: json['activeJobs'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory PropertyModel.empty() {
    final now = DateTime.now();
    return PropertyModel(
      id: '',
      name: '',
      address: AddressModel.empty(),
      createdAt: now,
      updatedAt: now,
    );
  }

  String get formattedAddress => address.formatted;

  String get typeDisplayName {
    switch (type) {
      case PropertyType.apartment:
        return 'Apartment';
      case PropertyType.house:
        return 'House';
      case PropertyType.commercial:
        return 'Commercial';
      case PropertyType.condo:
        return 'Condo';
      case PropertyType.land:
        return 'Land';
      case PropertyType.other:
        return 'Other';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case PropertyStatus.occupied:
        return 'Occupied';
      case PropertyStatus.vacant:
        return 'Vacant';
      case PropertyStatus.maintenance:
        return 'Maintenance';
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    type,
    status,
    imageUrl,
    notes,
    activeJobs,
    createdAt,
    updatedAt,
  ];
}
