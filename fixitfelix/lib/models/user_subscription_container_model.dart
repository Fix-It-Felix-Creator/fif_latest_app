import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'member_subscription_model.dart';
import 'tool_subscription_model.dart';
import 'user_subscription_model.dart';

/// Container model for user's subscription data
/// Holds both member (tier) and tool (add-on) subscriptions separately
class UserSubscriptionContainerModel extends Equatable {
  /// Member subscription (main tier: Standard/Plus/Advance/VIP)
  final MemberSubscriptionModel? member;

  /// Tool subscription (premium tools add-on)
  final ToolSubscriptionModel? tool;

  const UserSubscriptionContainerModel({this.member, this.tool});

  /// Empty container
  static const UserSubscriptionContainerModel empty =
      UserSubscriptionContainerModel();

  /// Check if user has any member subscription
  bool get hasMemberSubscription => member != null;

  /// Check if user has an active tool subscription
  bool get hasToolSubscription => tool != null && tool!.isActive;

  /// Check if user has any active subscription
  bool get hasActiveSubscription =>
      (member?.isActive ?? false) || (tool?.isActive ?? false);

  /// Check if user has active member subscription
  bool get hasActiveMemberSubscription => member?.isActive ?? false;

  /// Total price of both subscriptions
  double get totalPrice => (member?.price ?? 0) + (tool?.price ?? 0);

  /// Current plan type from member subscription
  PlanType? get currentPlanType => member?.planType;

  /// Plan type getter (convenience accessor for member's planType)
  PlanType get planType => member?.planType ?? PlanType.standard;

  /// Plan display name (convenience accessor for member's planDisplayName)
  String get planDisplayName => member?.planDisplayName ?? 'Free Plan';

  /// Check if user is on free plan
  bool get isFreePlan => member?.isFreePlan ?? true;

  /// Get member subscription status
  SubscriptionStatus? get memberStatus => member?.status;

  /// Get tool subscription status
  SubscriptionStatus? get toolStatus => tool?.status;

  /// Days remaining on member subscription
  int get memberDaysRemaining => member?.remainingDays ?? -1;

  /// Days remaining on tool subscription
  int get toolDaysRemaining => tool?.remainingDays ?? -1;

  /// Formatted total price
  String get formattedTotalPrice {
    if (totalPrice == 0) return 'Free';
    final cycle = member?.billingCycle ?? tool?.billingCycle;
    final suffix = cycle == BillingCycle.yearly ? '/year' : '/month';
    return '£${totalPrice.toStringAsFixed(totalPrice == totalPrice.roundToDouble() ? 0 : 2)}$suffix';
  }

  UserSubscriptionContainerModel copyWith({
    MemberSubscriptionModel? member,
    ToolSubscriptionModel? tool,
  }) {
    return UserSubscriptionContainerModel(
      member: member ?? this.member,
      tool: tool ?? this.tool,
    );
  }

  /// Create container with only member subscription cleared
  UserSubscriptionContainerModel clearMember() {
    return UserSubscriptionContainerModel(member: null, tool: tool);
  }

  /// Create container with only tool subscription cleared
  UserSubscriptionContainerModel clearTool() {
    return UserSubscriptionContainerModel(member: member, tool: null);
  }

  Map<String, dynamic> toJson() {
    return {'member': member?.toJson(), 'tool': tool?.toJson()};
  }

  factory UserSubscriptionContainerModel.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionContainerModel(
      member: json['member'] != null
          ? MemberSubscriptionModel.fromJson(
              Map<String, dynamic>.from(json['member']),
            )
          : null,
      tool: json['tool'] != null
          ? ToolSubscriptionModel.fromJson(
              Map<String, dynamic>.from(json['tool']),
            )
          : null,
    );
  }

  /// Migrate from legacy UserSubscriptionModel to new container format
  factory UserSubscriptionContainerModel.fromLegacy(
    UserSubscriptionModel legacy,
  ) {
    // Create member subscription from legacy
    final member = MemberSubscriptionModel(
      subscriptionId: legacy.subscriptionId,
      name: legacy.name,
      price: legacy.price,
      billingCycle: legacy.billingCycle,
      planType: legacy.planType,
      accountType: legacy.accountType,
      startDate: legacy.startDate,
      endDate: legacy.endDate,
      status: legacy.status,
      metadata: legacy.metadata,
    );

    // Create tool subscription if legacy had tools
    ToolSubscriptionModel? tool;
    if (legacy.hasTools &&
        legacy.toolsPrice != null &&
        legacy.toolsPrice! > 0) {
      tool = ToolSubscriptionModel(
        subscriptionId: legacy.subscriptionId + 100, // Generate tool ID
        name:
            'Advanced Tools ${legacy.billingCycle == BillingCycle.yearly ? "Yearly" : "Monthly"}',
        price: legacy.toolsPrice!,
        billingCycle: legacy.billingCycle,
        startDate: legacy.startDate,
        endDate: legacy.endDate,
        status: legacy.status,
        includedTools: ToolSubscriptionModel.defaultTools,
      );
    }

    return UserSubscriptionContainerModel(member: member, tool: tool);
  }

  /// Check if JSON represents legacy structure (has subscriptionId at root)
  static bool isLegacyStructure(Map<String, dynamic> json) {
    return json.containsKey('subscriptionId') && !json.containsKey('member');
  }

  /// Parse JSON handling both legacy and new structure
  factory UserSubscriptionContainerModel.fromJsonAuto(
    Map<String, dynamic> json,
  ) {
    if (isLegacyStructure(json)) {
      final legacy = UserSubscriptionModel.fromJson(json);
      return UserSubscriptionContainerModel.fromLegacy(legacy);
    }
    return UserSubscriptionContainerModel.fromJson(json);
  }

  @override
  List<Object?> get props => [member, tool];
}
