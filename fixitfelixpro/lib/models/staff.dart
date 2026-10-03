import 'package:equatable/equatable.dart';

enum StaffPayType { day, hour }

extension StaffPayTypeX on StaffPayType {
  String get wire => this == StaffPayType.day ? 'day' : 'hour';
  String get label => this == StaffPayType.day ? 'Day' : 'Hour';

  static StaffPayType fromWire(String? raw) {
    return (raw ?? '').toLowerCase() == 'hour'
        ? StaffPayType.hour
        : StaffPayType.day;
  }
}

/// The labour rate a staff member is charged at on a quote / invoice line.
/// Trades people bill different rates for standard, weekend, emergency and
/// sociable-hours work — each is shown transparently on the customer quote.
enum LabourRateType { standard, weekend, emergency, sociable }

extension LabourRateTypeX on LabourRateType {
  String get wire => name;

  String get label {
    switch (this) {
      case LabourRateType.standard:
        return 'Standard';
      case LabourRateType.weekend:
        return 'Weekend';
      case LabourRateType.emergency:
        return 'Emergency';
      case LabourRateType.sociable:
        return 'Sociable';
    }
  }

  static LabourRateType fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'weekend':
        return LabourRateType.weekend;
      case 'emergency':
        return LabourRateType.emergency;
      case 'sociable':
        return LabourRateType.sociable;
      default:
        return LabourRateType.standard;
    }
  }

  /// Every rate method, standard first, for building selectors.
  static const List<LabourRateType> all = [
    LabourRateType.standard,
    LabourRateType.weekend,
    LabourRateType.emergency,
    LabourRateType.sociable,
  ];
}

class Staff extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final StaffPayType defaultPayType;

  /// The standard labour rate (per day or hour). Weekend / emergency /
  /// sociable rates are premium alternatives; each falls back to [rate]
  /// when left unset (0), so a staff member always has a usable rate.
  final double rate;
  final double weekendRate;
  final double emergencyRate;
  final double sociableRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Staff({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.defaultPayType = StaffPayType.day,
    this.rate = 0,
    this.weekendRate = 0,
    this.emergencyRate = 0,
    this.sociableRate = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// The configured rate for [type], falling back to the standard [rate]
  /// when the premium rate has not been set.
  double rateFor(LabourRateType type) {
    switch (type) {
      case LabourRateType.standard:
        return rate;
      case LabourRateType.weekend:
        return weekendRate > 0 ? weekendRate : rate;
      case LabourRateType.emergency:
        return emergencyRate > 0 ? emergencyRate : rate;
      case LabourRateType.sociable:
        return sociableRate > 0 ? sociableRate : rate;
    }
  }

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    StaffPayType? defaultPayType,
    double? rate,
    double? weekendRate,
    double? emergencyRate,
    double? sociableRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      defaultPayType: defaultPayType ?? this.defaultPayType,
      rate: rate ?? this.rate,
      weekendRate: weekendRate ?? this.weekendRate,
      emergencyRate: emergencyRate ?? this.emergencyRate,
      sociableRate: sociableRate ?? this.sociableRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    defaultPayType,
    rate,
    weekendRate,
    emergencyRate,
    sociableRate,
    createdAt,
    updatedAt,
  ];
}
