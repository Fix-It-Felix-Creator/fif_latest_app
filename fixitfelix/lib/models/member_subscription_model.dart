import 'package:equatable/equatable.dart';

import '../core/enum.dart';

/// Member subscription model for the main subscription tier (Standard/Plus/Advance/VIP)
class MemberSubscriptionModel extends Equatable {
  /// Unique subscription ID from backend
  final int subscriptionId;

  /// Subscription name (e.g., "Plus+ Monthly", "Advance Yearly")
  final String name;

  /// Plan price
  final double price;

  /// Billing cycle
  final BillingCycle billingCycle;

  /// Plan type (standard, plus, advance, vip)
  final PlanType planType;

  /// Account type this subscription belongs to
  final AccountCategoryType accountType;

  /// Subscription start date
  final DateTime startDate;

  /// Subscription end date
  final DateTime? endDate;

  /// Current subscription status
  final SubscriptionStatus status;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Stripe subscription ID for auto-renewal
  final String? stripeSubscriptionId;

  /// Stripe customer ID
  final String? stripeCustomerId;

  /// Stripe price ID
  final String? stripePriceId;

  /// Payment provider that owns this subscription: "apple", "google",
  /// "trial", or legacy "stripe". Null is treated as legacy.
  final String? provider;

  /// Store product identifier (App Store / Play product id).
  final String? productId;

  /// Apple's `originalTransactionId` — the stable identifier for an
  /// auto-renewable subscription across renewals. The IAP equivalent of
  /// [stripeSubscriptionId]; either being non-empty means "paid".
  final String? originalTransactionId;

  /// Whether subscription auto-renews
  final bool autoRenew;

  const MemberSubscriptionModel({
    required this.subscriptionId,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.planType,
    required this.accountType,
    required this.startDate,
    this.endDate,
    this.status = SubscriptionStatus.active,
    this.metadata,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    this.stripePriceId,
    this.provider,
    this.productId,
    this.originalTransactionId,
    this.autoRenew = true,
  });

  /// True when this is a real *paid* subscription (Apple/Google/Stripe)
  /// as opposed to the free server-side trial. The trial writes no
  /// provider transaction id, so an empty id on both fields = trial.
  ///
  /// This says nothing about whether the subscription is still live —
  /// an expired record keeps its transaction id. Gate access on
  /// [grantsAccess], never on this.
  bool get isPaid =>
      (originalTransactionId?.isNotEmpty ?? false) ||
      (stripeSubscriptionId?.isNotEmpty ?? false);

  /// True when this subscription currently grants access: status is
  /// active/trial AND the period hasn't lapsed. Must stay in lockstep
  /// with the auth gate's `_needsSubscription` check.
  bool get grantsAccess {
    final live = status == SubscriptionStatus.active ||
        status == SubscriptionStatus.trial;
    final end = endDate;
    final expired = end != null && end.isBefore(DateTime.now());
    return live && !expired;
  }

  /// Create from subscription screen selection
  factory MemberSubscriptionModel.fromSelection({
    required int subscriptionId,
    required String name,
    required double price,
    required bool isYearly,
    required PlanType planType,
    required AccountCategoryType accountType,
  }) {
    final now = DateTime.now();
    return MemberSubscriptionModel(
      subscriptionId: subscriptionId,
      name: name,
      price: price,
      billingCycle: isYearly ? BillingCycle.yearly : BillingCycle.monthly,
      planType: planType,
      accountType: accountType,
      startDate: now,
      endDate: isYearly
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30)),
      status: SubscriptionStatus.active,
    );
  }

  /// Number of days user has been on this plan
  int get daysOnPlan => DateTime.now().difference(startDate).inDays;

  /// Total days in billing cycle (30 for monthly, 365 for yearly)
  int get totalDays => billingCycle == BillingCycle.yearly ? 365 : 30;

  /// Days remaining in subscription
  /// Returns -1 for unlimited (free plans or no end date)
  int get remainingDays {
    if (isFreePlan) return -1;
    if (endDate == null) return -1;
    final remaining = endDate!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check if this is a free plan (standard plan with zero price)
  bool get isFreePlan => planType == PlanType.standard && price == 0;

  /// Check if subscription is currently active
  bool get isActive {
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
  bool get isExpired {
    if (isFreePlan) return false;
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Formatted price string
  String get formattedPrice {
    if (price == 0) return 'Free';
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix';
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

  MemberSubscriptionModel copyWith({
    int? subscriptionId,
    String? name,
    double? price,
    BillingCycle? billingCycle,
    PlanType? planType,
    AccountCategoryType? accountType,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    Map<String, dynamic>? metadata,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    String? stripePriceId,
    String? provider,
    String? productId,
    String? originalTransactionId,
    bool? autoRenew,
  }) {
    return MemberSubscriptionModel(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      name: name ?? this.name,
      price: price ?? this.price,
      billingCycle: billingCycle ?? this.billingCycle,
      planType: planType ?? this.planType,
      accountType: accountType ?? this.accountType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      provider: provider ?? this.provider,
      productId: productId ?? this.productId,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionId': subscriptionId,
      'name': name,
      'price': price,
      'billingCycle': billingCycle.name,
      'planType': planType.name,
      'accountType': accountType.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status.name,
      'metadata': metadata,
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripeCustomerId': stripeCustomerId,
      'stripePriceId': stripePriceId,
      'provider': provider,
      'productId': productId,
      'originalTransactionId': originalTransactionId,
      'autoRenew': autoRenew,
    };
  }

  factory MemberSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return MemberSubscriptionModel(
      // The cloud function writes subscriptionId as a string slug
      // (e.g. "tradesman_standard"), while the legacy app wrote a
      // numeric id. Tolerate either — fall back to 0 if neither.
      subscriptionId: _parseInt(json['subscriptionId']),
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
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
      // Accept both ISO strings (legacy client writes) and numeric
      // milliseconds (cloud-function writes — e.g. activate-trial,
      // create-with-payment-sheet). Without this dual handling the
      // model silently dropped trial timestamps and the auth gate
      // re-routed the user back to ChoosePlanScreen on every signin.
      startDate: _parseTs(json['startDate']) ?? DateTime.now(),
      endDate: _parseTs(json['endDate'] ?? json['currentPeriodEnd']),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      stripeSubscriptionId: json['stripeSubscriptionId'],
      stripeCustomerId: json['stripeCustomerId'],
      stripePriceId: json['stripePriceId'],
      provider: json['provider'],
      productId: json['productId'],
      originalTransactionId: json['originalTransactionId'],
      autoRenew: json['autoRenew'] ?? true,
    );
  }

  /// Tolerant parser for timestamps that may arrive as ISO strings
  /// (legacy app writes) or numeric milliseconds (cloud-function writes).
  /// Returns null when the input is null, malformed, or an unexpected
  /// type — callers default to a sensible fallback.
  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  /// Tolerant int parser. The cloud function writes `subscriptionId`
  /// as a string slug (e.g. "tradesman_standard"); legacy clients
  /// wrote a real int. Falls through to 0 when the value isn't
  /// numeric — the slug content lives on `metadata` / `name` anyway,
  /// so 0 is a safe sentinel.
  static int _parseInt(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  @override
  List<Object?> get props => [
    subscriptionId,
    name,
    price,
    billingCycle,
    planType,
    accountType,
    startDate,
    endDate,
    status,
    metadata,
    stripeSubscriptionId,
    stripeCustomerId,
    stripePriceId,
    provider,
    productId,
    originalTransactionId,
    autoRenew,
  ];
}
