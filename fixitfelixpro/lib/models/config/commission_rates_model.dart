import 'package:equatable/equatable.dart';

/// Model representing platform commission rates from Firebase
/// Path: config/commissionRates
class CommissionRatesModel extends Equatable {
  /// Commission rate for tradesman accounts (percentage)
  final double tradesmanCommission;

  /// Commission rate for business accounts (percentage)
  final double businessCommission;

  /// Premium rate for emergency jobs (percentage)
  final double emergencyJobPremium;

  /// Last updated timestamp
  final DateTime? updatedAt;

  /// UID of admin who last updated
  final String? updatedBy;

  const CommissionRatesModel({
    this.tradesmanCommission = 10.0,
    this.businessCommission = 8.0,
    this.emergencyJobPremium = 15.0,
    this.updatedAt,
    this.updatedBy,
  });

  /// Default commission rates
  static const CommissionRatesModel defaultRates = CommissionRatesModel();

  /// Get commission rate by account type
  double getCommissionByAccountType(String accountType) {
    switch (accountType.toLowerCase()) {
      case 'tradesman':
        return tradesmanCommission;
      case 'business':
        return businessCommission;
      default:
        return 0.0;
    }
  }

  /// Format commission as percentage string
  String formatCommission(double rate) {
    if (rate == rate.roundToDouble()) {
      return '${rate.toInt()}%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }

  /// Get formatted tradesman commission
  String get formattedTradesmanCommission =>
      formatCommission(tradesmanCommission);

  /// Get formatted business commission
  String get formattedBusinessCommission =>
      formatCommission(businessCommission);

  /// Get formatted emergency premium
  String get formattedEmergencyPremium => formatCommission(emergencyJobPremium);

  factory CommissionRatesModel.fromJson(Map<String, dynamic> json) {
    return CommissionRatesModel(
      tradesmanCommission: (json['tradesmanCommission'] ?? 10.0).toDouble(),
      businessCommission: (json['businessCommission'] ?? 8.0).toDouble(),
      emergencyJobPremium: (json['emergencyJobPremium'] ?? 15.0).toDouble(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      updatedBy: json['updatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tradesmanCommission': tradesmanCommission,
      'businessCommission': businessCommission,
      'emergencyJobPremium': emergencyJobPremium,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  CommissionRatesModel copyWith({
    double? tradesmanCommission,
    double? businessCommission,
    double? emergencyJobPremium,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CommissionRatesModel(
      tradesmanCommission: tradesmanCommission ?? this.tradesmanCommission,
      businessCommission: businessCommission ?? this.businessCommission,
      emergencyJobPremium: emergencyJobPremium ?? this.emergencyJobPremium,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
    tradesmanCommission,
    businessCommission,
    emergencyJobPremium,
    updatedAt,
    updatedBy,
  ];
}
