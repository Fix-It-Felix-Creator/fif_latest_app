import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'config/base_limits_model.dart';
import 'config/business_limits_model.dart';
import 'config/tradesman_limits_model.dart';
import 'feature_limits_model.dart';

/// Model representing a subscription plan configuration from Firebase
/// This is used to display available plans to users (not their current subscription)
class SubscriptionPlanModel extends Equatable {
  /// Unique plan ID
  final int id;

  /// Plan display name
  final String name;

  /// Plan type (standard, plus, advance, vip, freeTrial)
  final PlanType planType;

  /// Account type this plan is for
  final AccountCategoryType accountType;

  /// Monthly price
  final double monthlyPrice;

  /// Yearly price
  final double yearlyPrice;

  /// Free trial days
  final int trialDays;

  /// List of features included in the plan
  final List<String> features;

  /// Whether this plan includes tools addon
  final bool hasTools;

  /// Monthly price for tools addon
  final double? toolsMonthlyPrice;

  /// Yearly price for tools addon
  final double? toolsYearlyPrice;

  /// Transaction fee percentage (for tradesman/business)
  final double? transactionFee;

  /// Whether this plan is currently active
  final bool isActive;

  /// Plan description
  final String description;

  /// Feature limits for this plan (parsed from limits + tradesmanLimits)
  final FeatureLimitsModel limits;

  /// Created timestamp
  final DateTime? createdAt;

  /// Updated timestamp
  final DateTime? updatedAt;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.planType,
    required this.accountType,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.trialDays = 30,
    this.features = const [],
    this.hasTools = false,
    this.toolsMonthlyPrice,
    this.toolsYearlyPrice,
    this.transactionFee,
    this.isActive = true,
    this.description = '',
    this.limits = const FeatureLimitsModel(),
    this.createdAt,
    this.updatedAt,
  });

  /// Get price based on billing cycle
  double getPrice(BillingCycle billingCycle) {
    return billingCycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;
  }

  /// Get tools price based on billing cycle
  double? getToolsPrice(BillingCycle billingCycle) {
    if (!hasTools) return null;
    return billingCycle == BillingCycle.yearly
        ? toolsYearlyPrice
        : toolsMonthlyPrice;
  }

  /// Check if this is a free plan
  bool get isFree => monthlyPrice == 0 && yearlyPrice == 0;

  /// Get formatted price string
  String getFormattedPrice(BillingCycle billingCycle) {
    final price = getPrice(billingCycle);
    if (price == 0) return 'Free';
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix';
  }

  /// Get formatted tools price string
  String? getFormattedToolsPrice(BillingCycle billingCycle) {
    final price = getToolsPrice(billingCycle);
    if (price == null) return null;
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix';
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    // Parse base limits
    final baseLimitsJson = json['limits'] as Map<String, dynamic>?;
    final baseLimits = BaseLimitsModel.fromJson(baseLimitsJson);

    // Parse tradesman-specific limits (for tradesman accounts)
    final tradesmanLimitsJson =
        json['tradesmanLimits'] as Map<String, dynamic>?;
    final tradesmanLimits = tradesmanLimitsJson != null
        ? TradesmanLimitsModel.fromJson(tradesmanLimitsJson)
        : null;

    // Parse business-specific limits (for business accounts)
    final businessLimitsJson = json['businessLimits'] as Map<String, dynamic>?;
    final businessLimits = businessLimitsJson != null
        ? BusinessLimitsModel.fromJson(businessLimitsJson)
        : null;

    // Create merged limits model
    final mergedLimits = FeatureLimitsModel(
      baseLimits: baseLimits,
      tradesmanLimits: tradesmanLimits,
      businessLimits: businessLimits,
    );

    return SubscriptionPlanModel(
      id: _parseInt(json['id']) ?? 0,
      name: json['name'] ?? '',
      planType: _parsePlanType(json['planType']),
      accountType: _parseAccountType(json['accountType']),
      monthlyPrice: _parseDouble(json['monthlyPrice']) ?? 0,
      yearlyPrice: _parseDouble(json['yearlyPrice']) ?? 0,
      trialDays: _parseInt(json['trialDays']) ?? 30,
      features: json['features'] != null
          ? List<String>.from(json['features'])
          : const [],
      hasTools: json['hasTools'] ?? false,
      toolsMonthlyPrice: _parseDouble(json['toolsMonthlyPrice']),
      toolsYearlyPrice: _parseDouble(json['toolsYearlyPrice']),
      transactionFee: _parseDouble(json['transactionFee']),
      isActive: json['isActive'] ?? true,
      description: json['description'] ?? '',
      limits: mergedLimits,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'planType': planType.name,
      'accountType': accountType.name,
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'trialDays': trialDays,
      'features': features,
      'hasTools': hasTools,
      'toolsMonthlyPrice': toolsMonthlyPrice,
      'toolsYearlyPrice': toolsYearlyPrice,
      'transactionFee': transactionFee,
      'isActive': isActive,
      'description': description,
      'limits': limits.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static PlanType _parsePlanType(dynamic value) {
    if (value == null) return PlanType.standard;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'standard':
        return PlanType.standard;
      case 'plus':
        return PlanType.plus;
      case 'advance':
        return PlanType.advance;
      case 'vip':
        return PlanType.vip;
      default:
        return PlanType.standard;
    }
  }

  static AccountCategoryType _parseAccountType(dynamic value) {
    if (value == null) return AccountCategoryType.tradesman;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'tradesman':
        return AccountCategoryType.tradesman;
      case 'business':
        return AccountCategoryType.business;
      default:
        return AccountCategoryType.tradesman;
    }
  }

  SubscriptionPlanModel copyWith({
    int? id,
    String? name,
    PlanType? planType,
    AccountCategoryType? accountType,
    double? monthlyPrice,
    double? yearlyPrice,
    int? trialDays,
    List<String>? features,
    bool? hasTools,
    double? toolsMonthlyPrice,
    double? toolsYearlyPrice,
    double? transactionFee,
    bool? isActive,
    String? description,
    FeatureLimitsModel? limits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      planType: planType ?? this.planType,
      accountType: accountType ?? this.accountType,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      trialDays: trialDays ?? this.trialDays,
      features: features ?? this.features,
      hasTools: hasTools ?? this.hasTools,
      toolsMonthlyPrice: toolsMonthlyPrice ?? this.toolsMonthlyPrice,
      toolsYearlyPrice: toolsYearlyPrice ?? this.toolsYearlyPrice,
      transactionFee: transactionFee ?? this.transactionFee,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      limits: limits ?? this.limits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    planType,
    accountType,
    monthlyPrice,
    yearlyPrice,
    trialDays,
    features,
    hasTools,
    toolsMonthlyPrice,
    toolsYearlyPrice,
    transactionFee,
    isActive,
    description,
    limits,
    createdAt,
    updatedAt,
  ];
}
