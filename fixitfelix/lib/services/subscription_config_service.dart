import 'package:flutter/foundation.dart';

import '../core/enum.dart';
import '../core/services/app_config_store.dart';
import '../models/config/config_models.dart';

/// Reads the subscription plans both apps share.
///
/// A trimmed port of the Pro app's service. The customer app needs the plan
/// documents to draw its paywall, and nothing else: it does not enforce
/// limits, has no in-app purchase wiring, and has no notion of a tradesman
/// tier — so the limits lookups and the hardcoded default ladders that make up
/// most of the Pro app's copy are deliberately left out rather than ported and
/// left unused.
///
/// The source is `app_config.subscriptions`, generated from the
/// `subscription_plans` table. Edit a plan in the admin panel and this is what
/// changes.
class SubscriptionConfigService {
  static final SubscriptionConfigService _instance =
      SubscriptionConfigService._internal();

  factory SubscriptionConfigService() => _instance;

  SubscriptionConfigService._internal();

  final Map<String, SubscriptionPlanConfigModel> _cache = {};
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 30);

  /// jsonb comes back with dynamic maps; the models want `Map<String, dynamic>`.
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) return MapEntry(key.toString(), _asMap(value));
        if (value is List) return MapEntry(key.toString(), _asList(value));
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  List<dynamic> _asList(List<dynamic> list) => list
      .map((item) => item is Map
          ? _asMap(item)
          : item is List
              ? _asList(item)
              : item)
      .toList();

  /// Every customer tier, in the order the paywall should show them.
  ///
  /// Hidden and inactive tiers are dropped here rather than at the widget: a
  /// screen that has to remember to filter is a screen that will one day
  /// forget and show a withdrawn plan.
  Future<List<SubscriptionPlanConfigModel>> customerPlans({
    bool forceRefresh = false,
  }) async {
    final fresh = _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration;
    if (!forceRefresh && _cache.isNotEmpty && fresh) {
      return _sorted(_cache.values);
    }

    try {
      await AppConfigStore().load();
      final raw = AppConfigStore().map('subscriptions');
      if (raw == null || raw.isEmpty) {
        debugPrint('SubscriptionConfigService: no subscription config');
        return _sorted(_cache.values);
      }

      final data = _asMap(raw);
      final customer = data['customer'];
      if (customer == null) {
        debugPrint('SubscriptionConfigService: no customer plans in config');
        return _sorted(_cache.values);
      }

      _cache.clear();
      for (final entry in _asMap(customer).entries) {
        _cache[entry.key] =
            SubscriptionPlanConfigModel.fromJson(_asMap(entry.value));
      }
      _lastFetch = DateTime.now();
      debugPrint('SubscriptionConfigService: loaded ${_cache.length} plans');
    } catch (e) {
      // Keep whatever was cached. A paywall that renders last week's copy
      // beats one that renders nothing because the network blinked.
      debugPrint('SubscriptionConfigService: $e');
    }
    return _sorted(_cache.values);
  }

  List<SubscriptionPlanConfigModel> _sorted(
    Iterable<SubscriptionPlanConfigModel> plans,
  ) {
    final visible = plans
        .where((p) => p.isActive && p.availability != 'hidden')
        .where((p) => p.accountType == AccountCategoryType.customer)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return visible;
  }
}
