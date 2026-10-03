import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../models/member_subscription_model.dart';
import '../models/tool_subscription_model.dart';
import '../models/user_subscription_container_model.dart';
import '../repositories/subscription/subscription_mapper.dart';

/// Service for listening to subscription changes in realtime
/// Handles auto-renewal updates from Stripe webhooks
class SubscriptionListenerService {
  static final SubscriptionListenerService _instance =
      SubscriptionListenerService._internal();

  factory SubscriptionListenerService() => _instance;

  SubscriptionListenerService._internal();

  StreamSubscription<List<Map<String, dynamic>>>? _memberSubscription;

  final _subscriptionController =
      StreamController<UserSubscriptionContainerModel>.broadcast();

  /// Stream of subscription updates
  Stream<UserSubscriptionContainerModel> get subscriptionStream =>
      _subscriptionController.stream;

  UserSubscriptionContainerModel? _currentSubscription;

  /// Get current subscription (cached)
  UserSubscriptionContainerModel? get currentSubscription =>
      _currentSubscription;

  /// Start listening to subscription changes
  void startListening() {
    final user = SupabaseService().auth.currentUser;
    if (user == null) {
      debugPrint('SubscriptionListenerService: No user logged in');
      return;
    }

    final userId = user.id;
    debugPrint(
      'SubscriptionListenerService: Starting listener for user $userId',
    );

    // RTDB split this into `subscription/member` and `subscription/tool`.
    // `subscriptions` is one row per owner, so there is a single stream and
    // `tool` stays null — nothing in the app reads a tool subscription, and
    // the schema has no place to store one. If tool subscriptions are ever
    // used, they need their own table rather than a second listener here.
    _memberSubscription = SupabaseService()
        .client
        .from('subscriptions')
        .stream(primaryKey: const ['owner_id'])
        .eq('owner_id', userId)
        .listen(
      (rows) {
        _handleMemberUpdate(rows.isEmpty ? null : rows.first);
      },
      onError: (error) {
        debugPrint('Tool subscription listener error: $error');
      },
    );
  }

  /// `subscriptions` row -> the JSON MemberSubscriptionModel expects.
  ///
  /// Shared with `getUserDetails()`, which reads the same table to populate
  /// `UserDetailsModel.subscription`. Keeping one mapper means the live
  /// stream and the user document can't disagree about what a row means.
  Map<String, dynamic> _rowToMemberJson(Map<String, dynamic> row) =>
      SubscriptionMapper.rowToMemberJson(row);

  /// Handle member subscription update
  void _handleMemberUpdate(Map<String, dynamic>? row) {
    MemberSubscriptionModel? member;

    if (row != null) {
      try {
        final data = _rowToMemberJson(row);
        member = MemberSubscriptionModel.fromJson(data);
        debugPrint(
          'Member subscription updated: ${member.planDisplayName}, status: ${member.status}',
        );
      } catch (e) {
        debugPrint('Error parsing member subscription: $e');
      }
    }

    _currentSubscription = UserSubscriptionContainerModel(
      member: member,
      tool: _currentSubscription?.tool,
    );

    _subscriptionController.add(_currentSubscription!);
  }

  /// Stop listening to subscription changes
  void stopListening() {
    debugPrint('SubscriptionListenerService: Stopping listeners');
    _memberSubscription?.cancel();
    _memberSubscription = null;
  }

  /// Dispose the service
  void dispose() {
    stopListening();
    _subscriptionController.close();
  }

  /// Check if member subscription is expired
  bool get isMemberExpired {
    final member = _currentSubscription?.member;
    if (member == null) return true;
    return member.status.name == 'expired' ||
        (member.endDate != null && DateTime.now().isAfter(member.endDate!));
  }

  /// Check if tool subscription is expired
  bool get isToolExpired {
    final tool = _currentSubscription?.tool;
    if (tool == null) return true;
    return tool.status.name == 'expired' ||
        (tool.endDate != null && DateTime.now().isAfter(tool.endDate!));
  }

  /// Check if member subscription will renew
  bool get willMemberRenew => _currentSubscription?.member?.autoRenew ?? false;

  /// Check if tool subscription will renew
  bool get willToolRenew => _currentSubscription?.tool?.autoRenew ?? false;

  /// Get days until member subscription expires
  int get daysUntilMemberExpiry {
    final endDate = _currentSubscription?.member?.endDate;
    if (endDate == null) return -1;
    return endDate.difference(DateTime.now()).inDays;
  }

  /// Get days until tool subscription expires
  int get daysUntilToolExpiry {
    final endDate = _currentSubscription?.tool?.endDate;
    if (endDate == null) return -1;
    return endDate.difference(DateTime.now()).inDays;
  }
}
