import 'package:equatable/equatable.dart';

class LocationModel extends Equatable {
  final String address;
  final double? latitude;
  final double? longitude;

  const LocationModel({required this.address, this.latitude, this.longitude});

  LocationModel copyWith({
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return LocationModel(
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {'address': address, 'latitude': latitude, 'longitude': longitude};
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      address: json['address'] ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory LocationModel.empty() {
    return const LocationModel(address: '', latitude: null, longitude: null);
  }

  bool get isEmpty => address.isEmpty && latitude == null && longitude == null;

  bool get isValid =>
      address.isNotEmpty && latitude != null && longitude != null;

  String get coordinates {
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return '';
  }

  @override
  List<Object?> get props => [address, latitude, longitude];
}
