import 'package:equatable/equatable.dart';

import '../../core/enum.dart';
import 'base_limits_model.dart';
import 'business_limits_model.dart';
import 'customer_limits_model.dart';
import 'tradesman_limits_model.dart';

/// Subscription plan configuration model
/// Represents a complete subscription plan from Firebase config
class SubscriptionPlanConfigModel extends Equatable {
  /// Plan ID (e.g., "tradesman_plus", "customer_standard")
  final String id;

  /// Plan display name (e.g., "Plus+", "Standard")
  final String name;

  /// Plan description
  final String description;

  /// Account type this plan belongs to
  final AccountCategoryType accountType;

  /// Plan type (standard, plus, advance, vip)
  final PlanType planType;

  /// Monthly price
  final double monthlyPrice;

  /// Yearly price
  final double yearlyPrice;

  /// Whether the plan is active
  final bool isActive;

  /// Whether tools are included in the plan
  final bool hasTools;

  /// Tools add-on monthly price (if tools not included)
  final double? toolsMonthlyPrice;

  /// Tools add-on yearly price (if tools not included)
  final double? toolsYearlyPrice;

  /// Transaction fee percentage (for tradesman/business)
  final double? transactionFee;

  /// Trial period in days
  final int trialDays;

  /// Stripe Price ID for monthly billing
  final String? stripePriceIdMonthly;

  /// Stripe Price ID for yearly billing
  final String? stripePriceIdYearly;

  /// Stripe Price ID for tools add-on (monthly)
  final String? stripeToolsPriceIdMonthly;

  /// Stripe Price ID for tools add-on (yearly)
  final String? stripeToolsPriceIdYearly;

  /// List of feature descriptions for display
  final List<String> features;

  /// Short line under the price on the card. Null hides it.
  final String? tagline;

  /// Ribbon on the card — "MOST POPULAR", "COMING SOON". Null hides it.
  final String? badge;

  /// live | coming_soon | hidden. A coming_soon tier is shown but not sellable.
  final String availability;

  /// Whether this tier is the highlighted one.
  final bool isFeatured;

  /// Left-to-right order on the paywall.
  final int sortOrder;

  /// ISO currency of [monthlyPrice] / [yearlyPrice].
  final String currency;

  /// Store product id that actually charges. Null means this tier cannot be
  /// bought, whatever its card says.
  final String? productIdMonthly;
  final String? productIdYearly;

  /// Customer-specific limits (only for customer accounts).
  final CustomerLimitsModel? customerLimits;

  /// Base limits (common across all account types)
  final BaseLimitsModel limits;

  /// Tradesman-specific limits (only for tradesman accounts)
  final TradesmanLimitsModel? tradesmanLimits;

  /// Business-specific limits (only for business accounts)
  final BusinessLimitsModel? businessLimits;

  /// Created timestamp
  final DateTime? createdAt;

  /// Updated timestamp
  final DateTime? updatedAt;

  const SubscriptionPlanConfigModel({
    required this.id,
    required this.name,
    required this.description,
    required this.accountType,
    required this.planType,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.isActive = true,
    this.hasTools = false,
    this.toolsMonthlyPrice,
    this.toolsYearlyPrice,
    this.transactionFee,
    this.trialDays = 0,
    this.stripePriceIdMonthly,
    this.stripePriceIdYearly,
    this.stripeToolsPriceIdMonthly,
    this.stripeToolsPriceIdYearly,
    this.features = const [],
    this.tagline,
    this.badge,
    this.availability = 'live',
    this.isFeatured = false,
    this.sortOrder = 0,
    this.currency = 'GBP',
    this.productIdMonthly,
    this.productIdYearly,
    this.customerLimits,
    this.limits = const BaseLimitsModel(),
    this.tradesmanLimits,
    this.businessLimits,
    this.createdAt,
    this.updatedAt,
  });


  /// Whether this tier can actually be bought right now.
  ///
  /// A card can say "£30/mo" and still be unbuyable: the store owns the
  /// transaction, so without a product id there is nothing to purchase. Kept
  /// separate from [isActive] — hiding a tier and not selling it yet are
  /// different states, and the campaign ships two tiers in the second one.
  bool isPurchasable({required bool yearly}) =>
      isActive &&
      availability == 'live' &&
      (yearly ? productIdYearly : productIdMonthly) != null;

  bool get isComingSoon => availability == 'coming_soon';

  /// The price as it reads on a card: "FREE", "£30/mo", "£12.99/mo".
  String priceLabel({required bool yearly}) {
    final price = yearly ? yearlyPrice : monthlyPrice;
    if (monthlyPrice == 0 && yearlyPrice == 0) return 'FREE';
    final symbol = currency == 'GBP' ? '£' : '';
    final amount = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return '$symbol$amount${yearly ? '/yr' : '/mo'}';
  }

  /// Check if this is a free plan
  bool get isFreePlan => monthlyPrice == 0 && yearlyPrice == 0;

  /// Check if tools add-on is available for purchase
  bool get hasToolsAddOn =>
      !hasTools && toolsMonthlyPrice != null && toolsYearlyPrice != null;

  /// Get price by billing cycle
  double getPrice(BillingCycle billingCycle) {
    return billingCycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;
  }

  /// Get tools price by billing cycle
  double? getToolsPrice(BillingCycle billingCycle) {
    if (!hasToolsAddOn) return null;
    return billingCycle == BillingCycle.yearly
        ? toolsYearlyPrice
        : toolsMonthlyPrice;
  }

  /// Get Stripe Price ID by billing cycle
  String? getStripePriceId(BillingCycle billingCycle) {
    return billingCycle == BillingCycle.yearly
        ? stripePriceIdYearly
        : stripePriceIdMonthly;
  }

  /// Get Stripe Tools Price ID by billing cycle
  String? getStripeToolsPriceId(BillingCycle billingCycle) {
    return billingCycle == BillingCycle.yearly
        ? stripeToolsPriceIdYearly
        : stripeToolsPriceIdMonthly;
  }

  /// Formatted price string
  String getFormattedPrice(BillingCycle billingCycle) {
    final price = getPrice(billingCycle);
    if (price == 0) return 'Free';
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix';
  }

  /// Get max staff members based on account type
  int get maxStaffMembers {
    if (accountType == AccountCategoryType.business) {
      return businessLimits?.maxStaffMembers ?? 0;
    }
    if (accountType == AccountCategoryType.tradesman) {
      return tradesmanLimits?.maxStaffMembers ?? 0;
    }
    return 0;
  }

  /// Check if staff management is available
  bool get hasStaffManagement => maxStaffMembers != 0;

  /// Check if staff members limit is unlimited
  bool get isStaffMembersUnlimited => maxStaffMembers == -1;

  /// Check if user can add more staff members
  bool canAddStaff(int currentStaffCount) {
    if (!hasStaffManagement) return false;
    if (isStaffMembersUnlimited) return true;
    return currentStaffCount < maxStaffMembers;
  }

  SubscriptionPlanConfigModel copyWith({
    String? id,
    String? name,
    String? description,
    AccountCategoryType? accountType,
    PlanType? planType,
    double? monthlyPrice,
    double? yearlyPrice,
    bool? isActive,
    bool? hasTools,
    double? toolsMonthlyPrice,
    double? toolsYearlyPrice,
    double? transactionFee,
    int? trialDays,
    String? stripePriceIdMonthly,
    String? stripePriceIdYearly,
    String? stripeToolsPriceIdMonthly,
    String? stripeToolsPriceIdYearly,
    List<String>? features,
    String? tagline,
    String? badge,
    String? availability,
    bool? isFeatured,
    int? sortOrder,
    String? currency,
    String? productIdMonthly,
    String? productIdYearly,
    CustomerLimitsModel? customerLimits,
    BaseLimitsModel? limits,
    TradesmanLimitsModel? tradesmanLimits,
    BusinessLimitsModel? businessLimits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlanConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      accountType: accountType ?? this.accountType,
      planType: planType ?? this.planType,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      isActive: isActive ?? this.isActive,
      hasTools: hasTools ?? this.hasTools,
      toolsMonthlyPrice: toolsMonthlyPrice ?? this.toolsMonthlyPrice,
      toolsYearlyPrice: toolsYearlyPrice ?? this.toolsYearlyPrice,
      transactionFee: transactionFee ?? this.transactionFee,
      trialDays: trialDays ?? this.trialDays,
      stripePriceIdMonthly: stripePriceIdMonthly ?? this.stripePriceIdMonthly,
      stripePriceIdYearly: stripePriceIdYearly ?? this.stripePriceIdYearly,
      stripeToolsPriceIdMonthly:
          stripeToolsPriceIdMonthly ?? this.stripeToolsPriceIdMonthly,
      stripeToolsPriceIdYearly:
          stripeToolsPriceIdYearly ?? this.stripeToolsPriceIdYearly,
      features: features ?? this.features,
      tagline: tagline ?? this.tagline,
      badge: badge ?? this.badge,
      availability: availability ?? this.availability,
      isFeatured: isFeatured ?? this.isFeatured,
      sortOrder: sortOrder ?? this.sortOrder,
      currency: currency ?? this.currency,
      productIdMonthly: productIdMonthly ?? this.productIdMonthly,
      productIdYearly: productIdYearly ?? this.productIdYearly,
      customerLimits: customerLimits ?? this.customerLimits,
      limits: limits ?? this.limits,
      tradesmanLimits: tradesmanLimits ?? this.tradesmanLimits,
      businessLimits: businessLimits ?? this.businessLimits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'accountType': accountType.name,
      'planType': planType.name,
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'isActive': isActive,
      'hasTools': hasTools,
      if (toolsMonthlyPrice != null) 'toolsMonthlyPrice': toolsMonthlyPrice,
      if (toolsYearlyPrice != null) 'toolsYearlyPrice': toolsYearlyPrice,
      if (transactionFee != null) 'transactionFee': transactionFee,
      'trialDays': trialDays,
      if (stripePriceIdMonthly != null)
        'stripePriceIdMonthly': stripePriceIdMonthly,
      if (stripePriceIdYearly != null)
        'stripePriceIdYearly': stripePriceIdYearly,
      if (stripeToolsPriceIdMonthly != null)
        'stripeToolsPriceIdMonthly': stripeToolsPriceIdMonthly,
      if (stripeToolsPriceIdYearly != null)
        'stripeToolsPriceIdYearly': stripeToolsPriceIdYearly,
      'features': features,
      if (tagline != null) 'tagline': tagline,
      if (badge != null) 'badge': badge,
      'availability': availability,
      'isFeatured': isFeatured,
      'sortOrder': sortOrder,
      'currency': currency,
      if (productIdMonthly != null) 'productIdMonthly': productIdMonthly,
      if (productIdYearly != null) 'productIdYearly': productIdYearly,
      if (customerLimits != null) 'customerLimits': customerLimits!.toJson(),
      'limits': limits.toJson(),
      if (tradesmanLimits != null) 'tradesmanLimits': tradesmanLimits!.toJson(),
      if (businessLimits != null) 'businessLimits': businessLimits!.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory SubscriptionPlanConfigModel.fromJson(Map<String, dynamic> json) {
    final accountTypeStr = json['accountType'] as String? ?? 'tradesman';
    final accountType = AccountCategoryType.values.firstWhere(
      (e) => e.name == accountTypeStr,
      orElse: () => AccountCategoryType.tradesman,
    );

    final planTypeStr = json['planType'] as String? ?? 'standard';
    final planType = PlanType.values.firstWhere(
      (e) => e.name == planTypeStr,
      orElse: () => PlanType.standard,
    );

    return SubscriptionPlanConfigModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      accountType: accountType,
      planType: planType,
      monthlyPrice: (json['monthlyPrice'] ?? 0).toDouble(),
      yearlyPrice: (json['yearlyPrice'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
      hasTools: json['hasTools'] ?? false,
      toolsMonthlyPrice: json['toolsMonthlyPrice']?.toDouble(),
      toolsYearlyPrice: json['toolsYearlyPrice']?.toDouble(),
      transactionFee: json['transactionFee']?.toDouble(),
      trialDays: json['trialDays'] ?? 0,
      stripePriceIdMonthly: json['stripePriceIdMonthly'] as String?,
      stripePriceIdYearly: json['stripePriceIdYearly'] as String?,
      stripeToolsPriceIdMonthly: json['stripeToolsPriceIdMonthly'] as String?,
      stripeToolsPriceIdYearly: json['stripeToolsPriceIdYearly'] as String?,
      features: json['features'] != null
          ? List<String>.from(json['features'])
          : const [],
      tagline: json['tagline'] as String?,
      badge: json['badge'] as String?,
      availability: json['availability'] as String? ?? 'live',
      isFeatured: json['isFeatured'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      productIdMonthly: json['productIdMonthly'] as String?,
      productIdYearly: json['productIdYearly'] as String?,
      customerLimits: json['customerLimits'] != null
          ? CustomerLimitsModel.fromJson(json['customerLimits'])
          : null,
      limits: BaseLimitsModel.fromJson(json['limits']),
      tradesmanLimits: json['tradesmanLimits'] != null
          ? TradesmanLimitsModel.fromJson(json['tradesmanLimits'])
          : null,
      businessLimits: json['businessLimits'] != null
          ? BusinessLimitsModel.fromJson(json['businessLimits'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    accountType,
    planType,
    monthlyPrice,
    yearlyPrice,
    isActive,
    hasTools,
    toolsMonthlyPrice,
    toolsYearlyPrice,
    transactionFee,
    trialDays,
    stripePriceIdMonthly,
    stripePriceIdYearly,
    stripeToolsPriceIdMonthly,
    stripeToolsPriceIdYearly,
    features,
    tagline,
    badge,
    availability,
    isFeatured,
    sortOrder,
    currency,
    productIdMonthly,
    productIdYearly,
    customerLimits,
    limits,
    tradesmanLimits,
    businessLimits,
    createdAt,
    updatedAt,
  ];
}
