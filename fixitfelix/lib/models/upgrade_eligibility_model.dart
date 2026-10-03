import 'package:equatable/equatable.dart';

/// Model representing upgrade eligibility status and pricing
class UpgradeEligibilityModel extends Equatable {
  /// Whether user can upgrade (always true, but pricing may vary)
  final bool isEligible;

  /// Whether user qualifies for prorated pricing
  /// True if: daysOnCurrentPlan < 14 AND averageUsagePercentage < 70%
  final bool qualifiesForProration;

  /// Number of days user has been on current plan
  final int daysOnCurrentPlan;

  /// Average usage percentage across all usage types (0-100)
  final double averageUsagePercentage;

  /// Current plan price
  final double currentPlanPrice;

  /// New plan price (full price)
  final double newPlanPrice;

  /// Prorated price (reduced based on remaining days credit)
  final double proratedPrice;

  /// Full price (no proration)
  final double fullPrice;

  /// Reason why user doesn't qualify for proration (if applicable)
  final String? ineligibilityReason;

  const UpgradeEligibilityModel({
    required this.isEligible,
    required this.qualifiesForProration,
    required this.daysOnCurrentPlan,
    required this.averageUsagePercentage,
    required this.currentPlanPrice,
    required this.newPlanPrice,
    required this.proratedPrice,
    required this.fullPrice,
    this.ineligibilityReason,
  });

  /// Final price to charge based on eligibility
  double get finalPrice => qualifiesForProration ? proratedPrice : fullPrice;

  /// Amount saved with proration
  double get savings => fullPrice - finalPrice;

  /// Whether there are any savings
  bool get hasSavings => savings > 0;

  /// Formatted final price
  String get formattedFinalPrice {
    return '£${finalPrice.toStringAsFixed(2)}';
  }

  /// Formatted savings amount
  String get formattedSavings {
    return '£${savings.toStringAsFixed(2)}';
  }

  /// Formatted current plan price
  String get formattedCurrentPrice {
    return '£${currentPlanPrice.toStringAsFixed(2)}';
  }

  /// Formatted new plan price
  String get formattedNewPrice {
    return '£${newPlanPrice.toStringAsFixed(2)}';
  }

  /// Get eligibility summary message
  String get eligibilitySummary {
    if (qualifiesForProration) {
      return 'You qualify for prorated pricing! Pay only $formattedFinalPrice (save $formattedSavings)';
    }
    return ineligibilityReason ?? 'Full price upgrade: $formattedFullPrice';
  }

  /// Formatted full price
  String get formattedFullPrice {
    return '£${fullPrice.toStringAsFixed(2)}';
  }

  /// Formatted prorated price
  String get formattedProratedPrice {
    return '£${proratedPrice.toStringAsFixed(2)}';
  }

  /// Create eligibility for free plan users (no current subscription)
  factory UpgradeEligibilityModel.forFreePlanUser({
    required double newPlanPrice,
  }) {
    return UpgradeEligibilityModel(
      isEligible: true,
      qualifiesForProration: false,
      daysOnCurrentPlan: 0,
      averageUsagePercentage: 0,
      currentPlanPrice: 0,
      newPlanPrice: newPlanPrice,
      proratedPrice: newPlanPrice,
      fullPrice: newPlanPrice,
      ineligibilityReason: null,
    );
  }

  UpgradeEligibilityModel copyWith({
    bool? isEligible,
    bool? qualifiesForProration,
    int? daysOnCurrentPlan,
    double? averageUsagePercentage,
    double? currentPlanPrice,
    double? newPlanPrice,
    double? proratedPrice,
    double? fullPrice,
    String? ineligibilityReason,
  }) {
    return UpgradeEligibilityModel(
      isEligible: isEligible ?? this.isEligible,
      qualifiesForProration:
          qualifiesForProration ?? this.qualifiesForProration,
      daysOnCurrentPlan: daysOnCurrentPlan ?? this.daysOnCurrentPlan,
      averageUsagePercentage:
          averageUsagePercentage ?? this.averageUsagePercentage,
      currentPlanPrice: currentPlanPrice ?? this.currentPlanPrice,
      newPlanPrice: newPlanPrice ?? this.newPlanPrice,
      proratedPrice: proratedPrice ?? this.proratedPrice,
      fullPrice: fullPrice ?? this.fullPrice,
      ineligibilityReason: ineligibilityReason ?? this.ineligibilityReason,
    );
  }

  @override
  List<Object?> get props => [
    isEligible,
    qualifiesForProration,
    daysOnCurrentPlan,
    averageUsagePercentage,
    currentPlanPrice,
    newPlanPrice,
    proratedPrice,
    fullPrice,
    ineligibilityReason,
  ];
}
