import 'package:equatable/equatable.dart';

import '../core/enum.dart';

/// Tool subscription model for premium tools add-on
class ToolSubscriptionModel extends Equatable {
  /// Unique subscription ID from backend
  final int subscriptionId;

  /// Subscription name (e.g., "Advanced Tools Monthly")
  final String name;

  /// Tool subscription price
  final double price;

  /// Billing cycle
  final BillingCycle billingCycle;

  /// Subscription start date
  final DateTime startDate;

  /// Subscription end date
  final DateTime? endDate;

  /// Current subscription status
  final SubscriptionStatus status;

  /// List of included tool identifiers
  final List<String> includedTools;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Stripe subscription ID for auto-renewal
  final String? stripeSubscriptionId;

  /// Stripe customer ID
  final String? stripeCustomerId;

  /// Stripe price ID
  final String? stripePriceId;

  /// Whether subscription auto-renews
  final bool autoRenew;

  const ToolSubscriptionModel({
    required this.subscriptionId,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.startDate,
    this.endDate,
    this.status = SubscriptionStatus.active,
    this.includedTools = const [],
    this.metadata,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    this.stripePriceId,
    this.autoRenew = true,
  });

  /// Default tools list for premium tools subscription
  static const List<String> defaultTools = [
    'ar_tools',
    'calculator',
    'sketch_pad',
    'photo_docs',
    'invoicing',
    'templates',
    'advanced_reports',
  ];

  /// Create from subscription screen selection
  factory ToolSubscriptionModel.fromSelection({
    required int subscriptionId,
    required String name,
    required double price,
    required bool isYearly,
    List<String>? includedTools,
  }) {
    final now = DateTime.now();
    return ToolSubscriptionModel(
      subscriptionId: subscriptionId,
      name: name,
      price: price,
      billingCycle: isYearly ? BillingCycle.yearly : BillingCycle.monthly,
      startDate: now,
      endDate: isYearly
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 30)),
      status: SubscriptionStatus.active,
      includedTools: includedTools ?? defaultTools,
    );
  }

  /// Number of days user has been on this plan
  int get daysOnPlan => DateTime.now().difference(startDate).inDays;

  /// Total days in billing cycle (30 for monthly, 365 for yearly)
  int get totalDays => billingCycle == BillingCycle.yearly ? 365 : 30;

  /// Days remaining in subscription
  int get remainingDays {
    if (endDate == null) return -1;
    final remaining = endDate!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check if subscription is currently active
  bool get isActive {
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
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Check if a specific tool is included
  bool hasTool(String toolId) => includedTools.contains(toolId);

  /// Formatted price string
  String get formattedPrice {
    if (price == 0) return 'Free';
    final suffix = billingCycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix';
  }

  ToolSubscriptionModel copyWith({
    int? subscriptionId,
    String? name,
    double? price,
    BillingCycle? billingCycle,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    List<String>? includedTools,
    Map<String, dynamic>? metadata,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    String? stripePriceId,
    bool? autoRenew,
  }) {
    return ToolSubscriptionModel(
      subscriptionId: subscriptionId ?? this.subscriptionId,
      name: name ?? this.name,
      price: price ?? this.price,
      billingCycle: billingCycle ?? this.billingCycle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      includedTools: includedTools ?? this.includedTools,
      metadata: metadata ?? this.metadata,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscriptionId': subscriptionId,
      'name': name,
      'price': price,
      'billingCycle': billingCycle.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status.name,
      'includedTools': includedTools,
      'metadata': metadata,
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripeCustomerId': stripeCustomerId,
      'stripePriceId': stripePriceId,
      'autoRenew': autoRenew,
    };
  }

  factory ToolSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return ToolSubscriptionModel(
      // Tolerate both numeric (legacy) and string-slug (cloud-function)
      // subscription IDs. See MemberSubscriptionModel for the same fix
      // and rationale.
      subscriptionId: _parseInt(json['subscriptionId']),
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      billingCycle: BillingCycle.values.firstWhere(
        (e) => e.name == json['billingCycle'],
        orElse: () => BillingCycle.monthly,
      ),
      startDate: _parseTs(json['startDate']) ?? DateTime.now(),
      endDate: _parseTs(json['endDate'] ?? json['currentPeriodEnd']),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      includedTools: json['includedTools'] != null
          ? List<String>.from(json['includedTools'])
          : defaultTools,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      stripeSubscriptionId: json['stripeSubscriptionId'],
      stripeCustomerId: json['stripeCustomerId'],
      stripePriceId: json['stripePriceId'],
      autoRenew: json['autoRenew'] ?? true,
    );
  }

  /// See [MemberSubscriptionModel] for the rationale — tolerant
  /// parsing for ints (slug or numeric) and timestamps (ISO string
  /// or epoch millis) writes from either client or cloud function.
  static int _parseInt(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  List<Object?> get props => [
    subscriptionId,
    name,
    price,
    billingCycle,
    startDate,
    endDate,
    status,
    includedTools,
    metadata,
    stripeSubscriptionId,
    stripeCustomerId,
    stripePriceId,
    autoRenew,
  ];
}
