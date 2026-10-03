import 'package:flutter/foundation.dart';

import '../core/enum.dart';
import '../core/services/app_config_store.dart';
import '../models/config/app_config_model.dart';
import '../models/config/commission_rates_model.dart';
import '../models/config/image_limits_config_model.dart';
import '../models/config/subscription_plan_config_model.dart';
import '../models/config/video_limits_config_model.dart';

/// Global singleton that loads the app configuration at startup and exposes
/// it in-memory so any screen can read without re-fetching.
///
/// Was the RTDB `config/` node — one subtree holding `commissionRates`,
/// `imageLimits`, `videoLimits` and `subscriptions`. Those are now four rows
/// in `app_config`, reassembled here into the same shape
/// [AppConfigModel.fromJson] already expects, so the model and its consumers
/// are unchanged.
///
/// Call [initialize] once in `main.dart` after `SupabaseService().initialize()`.
/// Read the cached config from anywhere:
///   `AppConfigService().config.commissionRates`
///   `AppConfigService().plan('business', PlanType.vip)`
class AppConfigService {
  AppConfigService._internal();
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;

  AppConfigModel _config = AppConfigModel.empty;
  bool _loaded = false;

  AppConfigModel get config => _config;
  bool get isLoaded => _loaded;

  CommissionRatesModel get commissionRates => _config.commissionRates;
  ImageLimitsConfigModel get imageLimits => _config.imageLimits;
  VideoLimitsConfigModel get videoLimits => _config.videoLimits;

  Map<String, SubscriptionPlanConfigModel> plansFor(String accountType) =>
      _config.plansFor(accountType);

  SubscriptionPlanConfigModel? plan(String accountType, PlanType planType) =>
      _config.plan(accountType, planType);

  /// Keys that made up the old `config/` subtree.
  static const List<String> _configKeys = [
    'commissionRates',
    'imageLimits',
    'videoLimits',
    'subscriptions',
  ];

  /// Load the configuration and cache it. Safe to call repeatedly;
  /// pass `forceRefresh: true` to re-fetch.
  Future<void> initialize({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    try {
      final store = AppConfigStore();
      await store.load(forceRefresh: forceRefresh);

      // Reassemble the four rows into the single map the model expects.
      final data = <String, dynamic>{};
      for (final key in _configKeys) {
        final value = store.map(key);
        if (value != null && value.isNotEmpty) data[key] = value;
      }

      if (data.isEmpty) {
        debugPrint('AppConfigService: no config data found, using defaults');
        _loaded = true;
        return;
      }

      _config = AppConfigModel.fromJson(data);
      _loaded = true;
      final planCount = _config.subscriptions.values
          .fold<int>(0, (n, m) => n + m.length);
      debugPrint(
        'AppConfigService: loaded config (plans: $planCount, '
        'tradesmanCommission: ${_config.commissionRates.tradesmanCommission}%)',
      );
    } catch (e) {
      debugPrint('AppConfigService: initialize failed: $e');
      // Leave defaults; retry on next call.
    }
  }

  Future<void> refresh() => initialize(forceRefresh: true);

}
