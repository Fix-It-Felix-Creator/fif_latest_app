import 'package:equatable/equatable.dart';

import '../core/enum.dart';

class UserSubscriptionModel extends Equatable {
  /// Unique subscription ID from backend
  final int subscriptionId;

  /// Subscription name (e.g., "Plus+ Monthly", "VIP Business Yearly")
  final String name;

  /// Base plan price
  final double price;

  /// Add-on tools price (if applicable)
  final double? toolsPrice;

  /// Total price (price + toolsPrice)
  double get totalPrice => price + (toolsPrice ?? 0);

  /// Final price to pay (prorated amount for upgrades, otherwise totalPrice)
  final double? finalPriceToPay;

  /// Get the actual amount to charge (uses prorated price if available)
  double get amountToCharge => finalPriceToPay ?? totalPrice;

  /// Billing cycle
  final BillingCycle billingCycle;

  /// Plan type
  final PlanType planType;

  /// Account type this subscription belongs to
  final AccountCategoryType accountType;

  /// Whether premium/advanced tools are included
  final bool hasTools;

  /// Transaction fee percentage (for tradesman/business)
  final double? transactionFee;

  /// Savings percentage (yearly vs monthly, e.g., "Save up to 20%")
  final double? savingsPercentage;

  /// Subscription start date
  final DateTime startDate;

  /// Subscription end date
  final DateTime? endDate;

  /// Current subscription status
  final SubscriptionStatus status;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  const UserSubscriptionModel({
    required this.subscriptionId,
    required this.name,
    required this.price,
    this.toolsPrice,
    this.finalPriceToPay,
    required this.billingCycle,
    required this.planType,
    required this.accountType,
    this.hasTools = false,
    this.transactionFee,
    this.savingsPercentage,
    required this.startDate,
    this.endDate,
    this.status = SubscriptionStatus.active,
    this.metadata,
  });

  /// Create from subscription screen selection
  factory UserSubscriptionModel.fromSelection({
    required int subscriptionId,
    required String name,
    required double price,
    double? toolsPrice,
    double? finalPriceToPay,
    required bool isYearly,
    required PlanType planType,
    required AccountCategoryType accountType,
    bool hasTools = false,
    double? transactionFee,
    double? savingsPercentage,
  }) {
    final now = DateTime.now();
    return UserSubscriptionModel(
      subscriptionId: subscriptionId,
      name: name,
      price: price,
      toolsPrice: toolsPrice,
      finalPriceToPay: finalPriceToPay,
      billingCycle: isYearly ? BillingCycle.yearly : BillingCycle.monthly,
      planType: planType,
      accountType: accountType,
      hasTools: hasTools,
      transactionFee: transactionFee,
      savingsPercentage: savingsPercentage,
      startDate: now,
      endDate: isYearly
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30)),
      status: SubscriptionStatus.active,
    );
  }

  UserSubscriptionModel copyWith({
    int? subscriptionId,
    String? name,
    double? price,
    double? toolsPrice,
    double? finalPriceToPay,
    BillingCycle? billingCycle,
    PlanType? planType,
    AccountCategoryType? accountType,
    bool? hasTools,
    double? transactionFee,
    double? savingsPercentage,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return UserSubscriptionModel(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      name: name ?? this.name,
      price: price ?? this.price,
      toolsPrice: toolsPrice ?? this.toolsPrice,
      finalPriceToPay: finalPriceToPay ?? this.finalPriceToPay,
      billingCycle: billingCycle ?? this.billingCycle,
      planType: planType ?? this.planType,
      accountType: accountType ?? this.accountType,
      hasTools: hasTools ?? this.hasTools,
      transactionFee: transactionFee ?? this.transactionFee,
      savingsPercentage: savingsPercentage ?? this.savingsPercentage,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionId': subscriptionId,
      'name': name,
      'price': price,
      'toolsPrice': toolsPrice,
      'finalPriceToPay': finalPriceToPay,
      'totalPrice': totalPrice,
      'billingCycle': billingCycle.name,
      'planType': planType.name,
      'accountType': accountType.name,
      'hasTools': hasTools,
      'transactionFee': transactionFee,
      'savingsPercentage': savingsPercentage,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status.name,
      'metadata': metadata,
    };
  }

  factory UserSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionModel(
      subscriptionId: json['subscriptionId'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      toolsPrice: json['toolsPrice']?.toDouble(),
      finalPriceToPay: json['finalPriceToPay']?.toDouble(),
      billingCycle: BillingCycle.values.firstWhere(
        (e) => e.name == json['billingCycle'],
        orElse: () => BillingCycle.monthly,
      ),
      planType: PlanType.values.firstWhere(
        (e) => e.name == json['planType'],
        orElse: () => PlanType.standard,
      ),
      accountType: AccountCategoryType.values.firstWhere(
        (e) => e.name == json['accountType'],
        orElse: () => AccountCategoryType.tradesman,
      ),
      hasTools: json['hasTools'] ?? false,
      transactionFee: json['transactionFee']?.toDouble(),
      savingsPercentage: json['savingsPercentage']?.toDouble(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  /// Check if this is a free plan (standard plan with zero price)
  bool get isFreePlan => planType == PlanType.standard && price == 0;

  /// Check if subscription is currently active
  /// Note: Free/Standard plans are always active and never expire
  bool get isActive {
    // Free/Standard plans are always active
    if (isFreePlan) return true;

    if (status != SubscriptionStatus.active &&
        status != SubscriptionStatus.trial) {
      return false;
    }
    if (endDate != null && DateTime.now().isAfter(endDate!)) {
      return false;
    }
    return true;
  }

  /// Check if subscription is expired
  /// Note: Free/Standard plans never expire
  bool get isExpired {
    // Free/Standard plans never expire
    if (isFreePlan) return false;

    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Days remaining in subscription
  /// Returns -1 for unlimited (free plans or no end date)
  int get daysRemaining {
    // Free plans have unlimited duration
    if (isFreePlan) return -1;

    if (endDate == null) return -1; // Unlimited
    final remaining = endDate!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Formatted price string (full subscription price)
  String get formattedPrice {
    if (totalPrice == 0) return 'Free';
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${totalPrice.toStringAsFixed(totalPrice == totalPrice.roundToDouble() ? 0 : 2)}$suffix';
  }

  /// Formatted final price to pay (prorated if applicable, without suffix)
  String get formattedFinalPrice {
    if (amountToCharge == 0) return 'Free';
    return '£${amountToCharge.toStringAsFixed(amountToCharge == amountToCharge.roundToDouble() ? 0 : 2)}';
  }

  /// Check if this subscription has a prorated price
  bool get hasProration =>
      finalPriceToPay != null && finalPriceToPay! < totalPrice;

  /// Formatted billing cycle
  String get formattedBillingCycle {
    return billingCycle == BillingCycle.yearly ? 'Yearly' : 'Monthly';
  }

  /// Plan display name
  String get planDisplayName {
    switch (planType) {
      case PlanType.standard:
        return 'Standard';
      case PlanType.pro:
      case PlanType.plus:
        return 'Plus+';
      case PlanType.advance:
        return 'Advance';
      case PlanType.vip:
        return 'VIP Business';
    }
  }

  @override
  List<Object?> get props => [
    subscriptionId,
    name,
    price,
    toolsPrice,
    finalPriceToPay,
    billingCycle,
    planType,
    accountType,
    hasTools,
    transactionFee,
    savingsPercentage,
    startDate,
    endDate,
    status,
    metadata,
  ];
}
