import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/enum.dart';
import '../../core/services/app_config_store.dart';
import '../../models/subscription_plan_model.dart';
import 'base_subscription_repository.dart';

/// Repository for fetching subscription plan configuration.
///
/// Was RTDB `config/subscriptions/{accountType}`; now the `subscriptions` key
/// in `app_config`, whose value is keyed by account type. A missing key yields
/// an empty plan list, exactly as a missing RTDB node did.
class SubscriptionRepository implements BaseSubscriptionRepository {
  static const String _configKey = 'subscriptions';

  final AppConfigStore _config = AppConfigStore();

  /// Plans for one account type, or null when the key is absent.
  Map<String, dynamic>? _plansFor(String accountTypeStr) {
    final all = _config.map(_configKey);
    final forType = all?[accountTypeStr];
    return forType is Map ? Map<String, dynamic>.from(forType) : null;
  }

  /// In-memory cache for subscription plans
  final Map<AccountCategoryType, List<SubscriptionPlanModel>> _cache = {};

  /// Subscription listeners for cleanup
  final Map<AccountCategoryType, StreamSubscription> _subscriptions = {};

  SubscriptionRepository();

  /// Get the account type string for Firebase path
  String _getAccountTypeString(AccountCategoryType accountType) {
    switch (accountType) {
      case AccountCategoryType.tradesman:
        return 'tradesman';
      case AccountCategoryType.business:
        return 'business';
      case AccountCategoryType.customer:
        return 'customer';
    }
  }

  @override
  Future<List<SubscriptionPlanModel>> getPlans(
    AccountCategoryType accountType,
  ) async {
    try {
      // Check cache first
      if (_cache.containsKey(accountType) && _cache[accountType]!.isNotEmpty) {
        return _cache[accountType]!;
      }

      final accountTypeStr = _getAccountTypeString(accountType);
      await _config.load();
      final data = _plansFor(accountTypeStr);

      if (data == null || data.isEmpty) {
        debugPrint('No subscription plans found for $accountTypeStr');
        return [];
      }

      final plans = data.entries.map((entry) {
        final planData = entry.value as Map<String, dynamic>;
        return SubscriptionPlanModel.fromJson(planData);
      }).toList();

      // Sort by plan type order: standard, plus, advance, vip
      plans.sort(
        (a, b) => _getPlanTypeOrder(
          a.planType,
        ).compareTo(_getPlanTypeOrder(b.planType)),
      );

      // Update cache
      _cache[accountType] = plans;

      debugPrint('Fetched ${plans.length} plans for $accountTypeStr');
      return plans;
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      return _cache[accountType] ?? [];
    }
  }

  @override
  Stream<List<SubscriptionPlanModel>> watchPlans(
    AccountCategoryType accountType,
  ) async* {
    final accountTypeStr = _getAccountTypeString(accountType);

    // Emit cached data first if available
    if (_cache.containsKey(accountType) && _cache[accountType]!.isNotEmpty) {
      yield _cache[accountType]!;
    }

    // Then follow app_config updates
    await for (final value in _config.watchKey(_configKey)) {
      final forType = value is Map ? value[accountTypeStr] : null;
      if (forType is! Map) {
        yield <SubscriptionPlanModel>[];
        continue;
      }

      try {
        final dataMap = Map<String, dynamic>.from(forType);
        var plans = dataMap.entries.map((entry) {
          final planData = entry.value as Map<String, dynamic>;
          return SubscriptionPlanModel.fromJson(planData);
        }).toList();

        // Sort by plan type order
        plans.sort(
          (a, b) => _getPlanTypeOrder(
            a.planType,
          ).compareTo(_getPlanTypeOrder(b.planType)),
        );

        // Update cache
        _cache[accountType] = plans;

        yield plans;
      } catch (e) {
        debugPrint('Error processing subscription plans: $e');
        yield _cache[accountType] ?? [];
      }
    }
  }

  @override
  Future<List<SubscriptionPlanModel>> getActivePlans(
    AccountCategoryType accountType,
  ) async {
    final plans = await getPlans(accountType);
    return plans.where((plan) => plan.isActive).toList();
  }

  @override
  Future<SubscriptionPlanModel?> getPlanById(
    AccountCategoryType accountType,
    int planId,
  ) async {
    final plans = await getPlans(accountType);
    try {
      return plans.firstWhere((plan) => plan.id == planId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SubscriptionPlanModel>> getPlansByType(
    AccountCategoryType accountType,
    PlanType planType,
  ) async {
    final plans = await getPlans(accountType);
    return plans.where((plan) => plan.planType == planType).toList();
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Get sort order for plan types
  int _getPlanTypeOrder(PlanType planType) {
    switch (planType) {
      case PlanType.standard:
        return 0;
      case PlanType.pro:
      case PlanType.plus:
        return 1;
      case PlanType.advance:
        return 2;
      case PlanType.vip:
        return 3;
    }
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
}
