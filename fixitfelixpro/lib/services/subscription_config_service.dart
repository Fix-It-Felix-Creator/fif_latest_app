import 'package:flutter/foundation.dart';

import '../core/enum.dart';
import '../core/services/app_config_store.dart';
import '../models/config/config_models.dart';
import '../models/feature_limits_model.dart';

/// Service for fetching and caching subscription plan configurations.
///
/// Was the RTDB `config/subscriptions` and `config/videoLimits` nodes; both are
/// now keys in `app_config`, read through [AppConfigStore].
class SubscriptionConfigService {
  static final SubscriptionConfigService _instance =
      SubscriptionConfigService._internal();

  factory SubscriptionConfigService() => _instance;

  SubscriptionConfigService._internal();

  /// Normalises a nested jsonb value to a typed Map<String, dynamic>.
  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _convertToMap(value));
        } else if (value is List) {
          return MapEntry(key.toString(), _convertToList(value));
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  List<dynamic> _convertToList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToMap(item);
      } else if (item is List) {
        return _convertToList(item);
      }
      return item;
    }).toList();
  }

  // Cache for plan configs
  final Map<String, SubscriptionPlanConfigModel> _planConfigCache = {};
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 30);

  /// Get all subscription plan configs from Firebase
  Future<Map<String, SubscriptionPlanConfigModel>> getAllPlanConfigs({
    bool forceRefresh = false,
  }) async {
    // Return cached data if available and not expired
    if (!forceRefresh &&
        _planConfigCache.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return Map.from(_planConfigCache);
    }

    try {
      await AppConfigStore().load();
      final raw = AppConfigStore().map('subscriptions');
      if (raw == null || raw.isEmpty) {
        debugPrint('SubscriptionConfigService: No subscription configs found');
        return {};
      }

      final data = _convertToMap(raw);
      _planConfigCache.clear();

      // Parse each account type's plans
      // 'customer' was missing, so the three customer_* plans that have
      // always been in this document were parsed by nobody. The customer
      // app reads the same key.
      for (final accountType in ['tradesman', 'business', 'customer']) {
        if (data.containsKey(accountType)) {
          final plans = _convertToMap(data[accountType]);
          for (final entry in plans.entries) {
            final planData = _convertToMap(entry.value);
            final config = SubscriptionPlanConfigModel.fromJson(planData);
            // entry.key already includes accountType prefix (e.g., "customer_advance")
            final cacheKey = entry.key;
            _planConfigCache[cacheKey] = config;
            debugPrint(
              'SubscriptionConfigService: Cached config for $cacheKey',
            );
          }
        }
      }

      _lastFetch = DateTime.now();
      debugPrint(
        'SubscriptionConfigService: Loaded ${_planConfigCache.length} plan configs',
      );
      return Map.from(_planConfigCache);
    } catch (e) {
      debugPrint('SubscriptionConfigService: Error fetching configs: $e');
      return Map.from(_planConfigCache);
    }
  }

  /// Get a specific plan config by plan ID
  Future<SubscriptionPlanConfigModel?> getPlanConfig(String planId) async {
    if (_planConfigCache.containsKey(planId)) {
      return _planConfigCache[planId];
    }

    await getAllPlanConfigs();
    return _planConfigCache[planId];
  }

  /// Get plan config by account type and plan type
  Future<SubscriptionPlanConfigModel?> getPlanConfigByType(
    AccountCategoryType accountType,
    PlanType planType,
  ) async {
    final planId = '${accountType.name}_${planType.name}';
    return getPlanConfig(planId);
  }

  /// Get feature limits for a specific plan
  Future<FeatureLimitsModel> getFeatureLimits(
    AccountCategoryType accountType,
    PlanType planType,
  ) async {
    debugPrint(
      'SubscriptionConfigService.getFeatureLimits: accountType=${accountType.name}, planType=${planType.name}',
    );

    final config = await getPlanConfigByType(accountType, planType);
    if (config == null) {
      debugPrint(
        'SubscriptionConfigService: No config for ${accountType.name}_${planType.name}, using defaults',
      );
      // Return hardcoded defaults based on account type and plan type
      return _getDefaultLimits(accountType, planType);
    }

    debugPrint(
      'SubscriptionConfigService: Found config for ${accountType.name}_${planType.name}',
    );
    debugPrint('  - baseLimits: ${config.limits}');
    debugPrint('  - tradesmanLimits: ${config.tradesmanLimits}');
    debugPrint('  - businessLimits: ${config.businessLimits}');

    return FeatureLimitsModel(
      baseLimits: config.limits,
      tradesmanLimits: config.tradesmanLimits,
      businessLimits: config.businessLimits,
    );
  }

  /// Get feature limits by account type and plan type strings
  Future<FeatureLimitsModel> getFeatureLimitsByStrings(
    String accountType,
    String planType,
  ) async {
    debugPrint(
      'SubscriptionConfigService.getFeatureLimitsByStrings: accountType=$accountType, planType=$planType',
    );

    // Normalize strings to lowercase to match enum names
    final normalizedAccountType = accountType.toLowerCase();
    final normalizedPlanType = planType.toLowerCase();

    final accType = AccountCategoryType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalizedAccountType,
      orElse: () {
        debugPrint(
          'SubscriptionConfigService: Unknown accountType "$accountType", defaulting to tradesman',
        );
        return AccountCategoryType.tradesman;
      },
    );
    final plnType = PlanType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalizedPlanType,
      orElse: () {
        debugPrint(
          'SubscriptionConfigService: Unknown planType "$planType", defaulting to standard',
        );
        return PlanType.standard;
      },
    );

    debugPrint(
      'SubscriptionConfigService: Resolved to accType=${accType.name}, plnType=${plnType.name}',
    );
    return getFeatureLimits(accType, plnType);
  }

  /// Get plans for a specific account type
  Future<List<SubscriptionPlanConfigModel>> getPlansForAccountType(
    AccountCategoryType accountType,
  ) async {
    await getAllPlanConfigs();
    return _planConfigCache.values
        .where((config) => config.accountType == accountType && config.isActive)
        .toList()
      ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
  }

  /// Get video limits config
  Future<VideoLimitsConfigModel> getVideoLimits() async {
    try {
      await AppConfigStore().load();
      final raw = AppConfigStore().map('videoLimits');
      if (raw == null || raw.isEmpty) {
        return const VideoLimitsConfigModel();
      }
      final data = _convertToMap(raw);
      return VideoLimitsConfigModel.fromJson(data);
    } catch (e) {
      debugPrint('SubscriptionConfigService: Error fetching video limits: $e');
      return const VideoLimitsConfigModel();
    }
  }

  /// Clear the cache
  void clearCache() {
    _planConfigCache.clear();
    _lastFetch = null;
  }

  /// Synchronous method to get cached feature limits (returns defaults if not cached)
  /// Use this only when you need synchronous access and have already called async methods
  FeatureLimitsModel getCachedFeatureLimits(
    AccountCategoryType accountType,
    PlanType planType,
  ) {
    final planId = '${accountType.name}_${planType.name}';
    final config = _planConfigCache[planId];

    if (config == null) {
      // Return defaults if not cached
      return _getDefaultLimits(accountType, planType);
    }

    return FeatureLimitsModel(
      baseLimits: config.limits,
      tradesmanLimits: config.tradesmanLimits,
      businessLimits: config.businessLimits,
    );
  }

  /// Get default limits (fallback when Firebase is not available)
  FeatureLimitsModel _getDefaultLimits(
    AccountCategoryType accountType,
    PlanType planType,
  ) {
    // Default limits based on account type and plan
    switch (accountType) {
      case AccountCategoryType.tradesman:
        return FeatureLimitsModel(
          baseLimits: _getTradesmanBaseLimits(planType),
          tradesmanLimits: _getTradesmanSpecificLimits(planType),
        );
      case AccountCategoryType.business:
        return FeatureLimitsModel(
          baseLimits: _getBusinessBaseLimits(planType),
          businessLimits: _getBusinessSpecificLimits(planType),
        );
      case AccountCategoryType.customer:
        return FeatureLimitsModel(
          baseLimits: _getTradesmanBaseLimits(planType),
        );
    }
  }

  BaseLimitsModel _getTradesmanBaseLimits(PlanType planType) {
    switch (planType) {
      case PlanType.standard:
        return const BaseLimitsModel(
          maxAddresses: 1,
          maxCustomers: 10,
          maxInvoices: 5,
          maxJobs: -1,
          maxQuotations: 5,
          maxServices: 10,
          maxTemplates: 1,
          maxVoiceMinutesPerMonth: 5,
          maxSuggestionsPerMonth: 20,
        );
      case PlanType.pro:
      case PlanType.plus:
        return const BaseLimitsModel(
          maxAddresses: 2,
          maxCustomers: 50,
          maxInvoices: 20,
          maxJobs: -1,
          maxQuotations: 20,
          maxServices: 50,
          maxTemplates: 3,
          maxVoiceMinutesPerMonth: 30,
          maxSuggestionsPerMonth: 100,
        );
      case PlanType.advance:
        return const BaseLimitsModel(
          maxAddresses: -1,
          maxCustomers: -1,
          maxInvoices: -1,
          maxJobs: -1,
          maxQuotations: -1,
          maxServices: -1,
          maxTemplates: -1,
          maxVoiceMinutesPerMonth: 120,
          maxSuggestionsPerMonth: 500,
        );
      case PlanType.vip:
        return const BaseLimitsModel(
          maxAddresses: -1,
          maxCustomers: -1,
          maxInvoices: -1,
          maxJobs: -1,
          maxQuotations: -1,
          maxServices: -1,
          maxTemplates: -1,
          maxVoiceMinutesPerMonth: -1,
          maxSuggestionsPerMonth: -1,
        );
    }
  }

  TradesmanLimitsModel _getTradesmanSpecificLimits(PlanType planType) {
    switch (planType) {
      case PlanType.standard:
        return const TradesmanLimitsModel(
          maxFreelanceHiresPerMonth: 0,
          maxJobApplicationsPerMonth: 10,
          maxPhotoUploads: 5,
          maxStaffMembers: 0,
          maxVideoUploads: 2,
          serviceRadiusMiles: 5,
        );
      case PlanType.pro:
      case PlanType.plus:
        return const TradesmanLimitsModel(
          maxFreelanceHiresPerMonth: 0,
          maxJobApplicationsPerMonth: 50,
          maxPhotoUploads: 10,
          maxStaffMembers: 2,
          maxVideoUploads: 5,
          serviceRadiusMiles: 20,
        );
      case PlanType.advance:
        return const TradesmanLimitsModel(
          maxFreelanceHiresPerMonth: 2,
          maxJobApplicationsPerMonth: -1,
          maxPhotoUploads: -1,
          maxStaffMembers: 5,
          maxVideoUploads: -1,
          serviceRadiusMiles: -1,
        );
      case PlanType.vip:
        return const TradesmanLimitsModel(
          maxFreelanceHiresPerMonth: 5,
          maxJobApplicationsPerMonth: -1,
          maxPhotoUploads: -1,
          maxStaffMembers: -1,
          maxVideoUploads: -1,
          serviceRadiusMiles: -1,
        );
    }
  }

  BaseLimitsModel _getBusinessBaseLimits(PlanType planType) {
    switch (planType) {
      case PlanType.standard:
        return const BaseLimitsModel(
          maxAddresses: 2,
          maxCustomers: 50,
          maxInvoices: 20,
          maxJobs: -1,
          maxQuotations: 20,
          maxServices: 50,
          maxTemplates: 3,
          maxVoiceMinutesPerMonth: 10,
          maxSuggestionsPerMonth: 50,
        );
      case PlanType.pro:
      case PlanType.plus:
        return const BaseLimitsModel(
          maxAddresses: 5,
          maxCustomers: -1,
          maxInvoices: -1,
          maxJobs: -1,
          maxQuotations: -1,
          maxServices: -1,
          maxTemplates: 10,
          maxVoiceMinutesPerMonth: 60,
          maxSuggestionsPerMonth: 200,
        );
      case PlanType.advance:
        return const BaseLimitsModel(
          maxAddresses: -1,
          maxCustomers: -1,
          maxInvoices: -1,
          maxJobs: -1,
          maxQuotations: -1,
          maxServices: -1,
          maxTemplates: -1,
          maxVoiceMinutesPerMonth: 240,
          maxSuggestionsPerMonth: 1000,
        );
      case PlanType.vip:
        return const BaseLimitsModel(
          maxAddresses: -1,
          maxCustomers: -1,
          maxInvoices: -1,
          maxJobs: -1,
          maxQuotations: -1,
          maxServices: -1,
          maxTemplates: -1,
          maxVoiceMinutesPerMonth: -1,
          maxSuggestionsPerMonth: -1,
        );
    }
  }

  BusinessLimitsModel _getBusinessSpecificLimits(PlanType planType) {
    switch (planType) {
      case PlanType.standard:
        return const BusinessLimitsModel(
          apiAccess: false,
          maxBranches: 1,
          maxPhotoUploads: 20,
          maxProjectsPerMonth: 10,
          maxStaffMembers: 3,
          maxVideoUploads: 5,
          prioritySupport: false,
          serviceRadiusMiles: 10,
        );
      case PlanType.pro:
      case PlanType.plus:
        return const BusinessLimitsModel(
          apiAccess: false,
          maxBranches: 3,
          maxPhotoUploads: 50,
          maxProjectsPerMonth: 50,
          maxStaffMembers: 10,
          maxVideoUploads: 20,
          prioritySupport: false,
          serviceRadiusMiles: 50,
        );
      case PlanType.advance:
        return const BusinessLimitsModel(
          apiAccess: true,
          maxBranches: 10,
          maxPhotoUploads: -1,
          maxProjectsPerMonth: -1,
          maxStaffMembers: 30,
          maxVideoUploads: -1,
          prioritySupport: true,
          serviceRadiusMiles: -1,
        );
      case PlanType.vip:
        return const BusinessLimitsModel(
          apiAccess: true,
          maxBranches: -1,
          maxPhotoUploads: -1,
          maxProjectsPerMonth: -1,
          maxStaffMembers: -1,
          maxVideoUploads: -1,
          prioritySupport: true,
          serviceRadiusMiles: -1,
        );
    }
  }
}
