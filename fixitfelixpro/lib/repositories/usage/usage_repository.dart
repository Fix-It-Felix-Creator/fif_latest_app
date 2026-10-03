import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/cache_service.dart';
import '../../core/services/app_config_store.dart';
import '../../core/services/supabase_service.dart';
import 'usage_mapper.dart';
import '../../globals.dart';
import '../../models/config/business_limits_model.dart';
import '../../models/feature_limits_model.dart';
import '../../models/user_usage_model.dart';
import '../../services/subscription_config_service.dart';
import 'base_usage_repository.dart';

/// Repository for managing user usage stats and feature limits
class UsageRepository implements BaseUsageRepository {
  final CacheService _cache = CacheService();
  final SubscriptionConfigService _configService;

  UsageRepository({
    SubscriptionConfigService? configService,
  }) :        _configService = configService ?? SubscriptionConfigService();

  String get _uid {
    final id = SupabaseService().auth.currentUser?.id;
    if (id == null) {
      throw CustomException(message: 'User not authenticated');
    }
    return id;
  }

  bool get _isAuthenticated => SupabaseService().auth.currentUser != null;

  // ---------------------------------------------------------------------------
  // Data access
  //
  // These two helpers return the SAME camelCase shape the RTDB nodes had, so
  // every consumer below (`userData['accountType']`,
  // `usageData['addressCount']`, ...) keeps working unchanged. Only the
  // transport moved.
  // ---------------------------------------------------------------------------

  /// Profile fields this repository needs, in the old `users/{uid}` shape.
  ///
  /// `subscription` lived on the user record in RTDB; it is now its own table,
  /// so it is re-nested here as `subscription.member` — the shape the plan-type
  /// lookup below already reads, including its legacy fallback.
  Future<Map<String, dynamic>?> _fetchUserMap(String userId) async {
    try {
      final client = SupabaseService().client;
      final profile = await client
          .from('profiles')
          .select('account_type')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return null;

      final sub = await client
          .from('subscriptions')
          .select('plan_type, status, billing_cycle, current_period_end')
          .eq('owner_id', userId)
          .maybeSingle();

      return <String, dynamic>{
        'accountType': profile['account_type']?.toString() ?? 'customer',
        if (sub != null)
          'subscription': <String, dynamic>{
            'member': <String, dynamic>{
              'planType': sub['plan_type']?.toString(),
              'status': sub['status']?.toString(),
              'billingCycle': sub['billing_cycle']?.toString(),
              'endDate': sub['current_period_end']?.toString(),
            },
          },
      };
    } catch (e) {
      debugPrint('UsageRepository._fetchUserMap failed: $e');
      return null;
    }
  }

  /// Usage counters in the old `usages/{uid}` shape.
  Future<Map<String, dynamic>?> _fetchUsageMap(String userId) async {
    try {
      final row = await SupabaseService()
          .client
          .from('usage_counters')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UsageMapper.rowToModelJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('UsageRepository._fetchUsageMap failed: $e');
      return null;
    }
  }

  /// Limits for one accountType/planType from `app_config`.
  ///
  /// Was RTDB `config/subscriptions/{accountType}/{planId}/limits`. Returns
  /// null when the key is absent, which sends the caller down the same
  /// plan-specific fallback path a missing RTDB node did.
  Future<Map<String, dynamic>?> _fetchPlanLimits(
    String accountType,
    String planType,
  ) async {
    try {
      await AppConfigStore().load();
      final subs = AppConfigStore().map('subscriptions');
      final forType = subs?[accountType];
      if (forType is! Map) return null;
      final plan = forType[planType];
      if (plan is! Map) return null;
      final limits = plan['limits'];
      return limits is Map ? Map<String, dynamic>.from(limits) : null;
    } catch (e) {
      debugPrint('UsageRepository._fetchPlanLimits failed: $e');
      return null;
    }
  }

  /// Live usage counters in the old `usages/{uid}` shape.
  Stream<Map<String, dynamic>?> _watchUsageMap(String userId) {
    return SupabaseService()
        .client
        .from('usage_counters')
        .stream(primaryKey: const ['owner_id'])
        .eq('owner_id', userId)
        .map((rows) => rows.isEmpty
            ? null
            : UsageMapper.rowToModelJson(
                Map<String, dynamic>.from(rows.first)));
  }

  /// Atomic counter change.
  ///
  /// Replaces `ServerValue.increment`. The `bump_usage` function floors at
  /// zero, matching decrementUsageCount()'s guard, and rejects any field that
  /// is not a real counter column.
  Future<void> _bump(String fieldName, int amount) async {
    final column = UsageMapper.columnFor(fieldName);
    if (column == null) {
      debugPrint('UsageRepository._bump: no column for $fieldName');
      return;
    }
    await SupabaseService()
        .client
        .rpc('bump_usage', params: {'p_field': column, 'p_amount': amount});
  }

  // Cache keys
  String get _usageCacheKey => 'usage_$_uid';
  String get _limitsCacheKey => 'limits_$_uid';

  // Default limits for fallback (customer standard)
  static const _fallbackLimits = FeatureLimitsModel();

  @override
  Future<FeatureLimitsModel> getUserLimits() async {
    try {
      // Get user data to determine account type and plan type
      final userData = await _fetchUserMap(_uid);

      if (userData == null) {
        debugPrint('User not found, using fallback limits');
        return _fallbackLimits;
      }

      final accountType = userData['accountType'] as String? ?? 'customer';
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      final member = subscription?['member'] as Map<String, dynamic>?;
      // Try member.planType first, then subscription.planType for backwards compatibility
      final planType =
          member?['planType'] as String? ??
          subscription?['planType'] as String? ??
          'standard';
      debugPrint(
        'UsageRepository.getUserLimits: accountType=$accountType, planType=$planType',
      );

      // Limits now come from app_config through the subscription config
      // service, which owns the same accountType/planType lookup and its
      // fallbacks — so there is no separate raw read here any more.
      final limitsSnapshot = await _fetchPlanLimits(accountType, planType);

      if (limitsSnapshot == null) {
        debugPrint(
          'No limits found for $accountType/$planType, using plan-specific fallback',
        );
        // Use plan-specific fallback limits from config service
        return await _configService.getFeatureLimitsByStrings(
          accountType,
          planType,
        );
      }

      final limits = FeatureLimitsModel.fromJson(limitsSnapshot);

      // Cache the limits
      await _cache.put(CacheBoxes.settings, _limitsCacheKey, limits.toJson());

      return limits;
    } catch (e) {
      debugPrint('Error fetching user limits: $e');

      // Try to return cached limits
      final cachedLimits = _cache.getJson(CacheBoxes.settings, _limitsCacheKey);
      if (cachedLimits != null) {
        return FeatureLimitsModel.fromJson(cachedLimits);
      }

      return _fallbackLimits;
    }
  }

  @override
  Future<UserUsageModel> getUserUsageStats() async {
    try {
      // Get user data for account type and plan
      final userData = await _fetchUserMap(_uid);

      String accountType = 'customer';
      String planType = 'standard';

      if (userData != null) {
        accountType = userData['accountType'] as String? ?? 'customer';
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        final member = subscription?['member'] as Map<String, dynamic>?;
        // Try member.planType first, then subscription.planType for backwards compatibility
        planType =
            member?['planType'] as String? ??
            subscription?['planType'] as String? ??
            'standard';
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('UsageRepository.getUserUsageStats:');
        debugPrint('  accountType: $accountType');
        debugPrint('  planType: $planType');
        debugPrint('  subscription data: $subscription');
        debugPrint('  member data: $member');
        debugPrint('═══════════════════════════════════════════════════════');
      } else {
        debugPrint(
          'UsageRepository.getUserUsageStats: User data not found, using defaults',
        );
      }

      // Get limits based on plan
      debugPrint(
        'UsageRepository: Fetching limits for accountType=$accountType, planType=$planType',
      );
      final limits = await _configService.getFeatureLimitsByStrings(
        accountType,
        planType,
      );
      debugPrint('UsageRepository: Received limits:');
      debugPrint('  baseLimits.maxAddresses: ${limits.maxAddresses}');
      debugPrint('  baseLimits.maxCustomers: ${limits.maxCustomers}');
      debugPrint('  baseLimits.maxInvoices: ${limits.maxInvoices}');
      debugPrint('  baseLimits.maxQuotations: ${limits.maxQuotations}');
      debugPrint('  baseLimits.maxServices: ${limits.maxServices}');
      debugPrint('  baseLimits.maxTemplates: ${limits.maxTemplates}');
      debugPrint('  tradesmanLimits: ${limits.tradesmanLimits}');
      if (limits.tradesmanLimits != null) {
        debugPrint(
          '    maxJobApplicationsPerMonth: ${limits.maxJobApplicationsPerMonth}',
        );
        debugPrint('    maxPhotoUploads: ${limits.maxPhotoUploads}');
        debugPrint('    maxVideoUploads: ${limits.maxVideoUploads}');
        debugPrint('    maxStaffMembers: ${limits.maxStaffMembers}');
        debugPrint('    serviceRadiusMiles: ${limits.serviceRadiusMiles}');
      }

      // Get usage counts from usages/{uid} path
      final usageData = await _fetchUsageMap(_uid);

      int addressCount = 0;
      int jobCount = 0;
      int invoiceCount = 0;
      int quotationCount = 0;
      int templateCount = 0;
      int serviceCount = 0;
      int customerCount = 0;
      int jobApplicationsThisMonth = 0;
      int photoUploadCount = 0;
      int videoUploadCount = 0;
      int staffCount = 0;
      int freelanceHiresThisMonth = 0;
      int voiceSecondsUsedThisMonth = 0;
      int suggestionsUsedThisMonth = 0;

      if (usageData != null) {
        addressCount = usageData['addressCount'] ?? 0;
        jobCount = usageData['jobCount'] ?? 0;
        invoiceCount = usageData['invoiceCount'] ?? 0;
        quotationCount = usageData['quotationCount'] ?? 0;
        templateCount = usageData['templateCount'] ?? 0;
        serviceCount = usageData['serviceCount'] ?? 0;
        customerCount = usageData['customerCount'] ?? 0;
        jobApplicationsThisMonth = usageData['jobApplicationsThisMonth'] ?? 0;
        photoUploadCount = usageData['photoUploadCount'] ?? 0;
        videoUploadCount = usageData['videoUploadCount'] ?? 0;
        staffCount = usageData['staffCount'] ?? 0;
        freelanceHiresThisMonth = usageData['freelanceHiresThisMonth'] ?? 0;
        voiceSecondsUsedThisMonth =
            usageData['voiceSecondsUsedThisMonth'] ?? 0;
        suggestionsUsedThisMonth =
            usageData['suggestionsUsedThisMonth'] ?? 0;
      }

      final usage = UserUsageModel(
        addressCount: addressCount,
        jobCount: jobCount,
        invoiceCount: invoiceCount,
        quotationCount: quotationCount,
        templateCount: templateCount,
        serviceCount: serviceCount,
        customerCount: customerCount,
        jobApplicationsThisMonth: jobApplicationsThisMonth,
        photoUploadCount: photoUploadCount,
        videoUploadCount: videoUploadCount,
        staffCount: staffCount,
        freelanceHiresThisMonth: freelanceHiresThisMonth,
        voiceSecondsUsedThisMonth: voiceSecondsUsedThisMonth,
        suggestionsUsedThisMonth: suggestionsUsedThisMonth,
        limits: limits,
      );

      // Cache the usage stats
      await _cache.put(CacheBoxes.settings, _usageCacheKey, usage.toJson());

      return usage;
    } catch (e) {
      debugPrint('Error fetching user usage stats: $e');

      // Try to return cached stats
      final cachedUsage = _cache.getJson(CacheBoxes.settings, _usageCacheKey);
      if (cachedUsage != null) {
        return UserUsageModel.fromJson(cachedUsage);
      }

      return UserUsageModel.empty;
    }
  }

  @override
  Stream<UserUsageModel> watchUsageStats() async* {
    // First emit cached data if available
    final cachedUsage = _cache.getJson(CacheBoxes.settings, _usageCacheKey);
    if (cachedUsage != null) {
      yield UserUsageModel.fromJson(cachedUsage);
    }

    // Get user data for account type and plan
    String accountType = 'customer';
    String planType = 'standard';

    try {
      final userData = await _fetchUserMap(_uid);

      if (userData != null) {
        accountType = userData['accountType'] as String? ?? 'customer';
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        final member = subscription?['member'] as Map<String, dynamic>?;
        // Try member.planType first, then subscription.planType for backwards compatibility
        planType =
            member?['planType'] as String? ??
            subscription?['planType'] as String? ??
            'standard';
        debugPrint(
          'UsageRepository.watchUsageStats: accountType=$accountType, planType=$planType',
        );
      }
    } catch (e) {
      debugPrint('Error fetching user data for watch: $e');
    }

    // Get limits based on plan
    final limits = await _configService.getFeatureLimitsByStrings(
      accountType,
      planType,
    );

    // Follow usage_counters changes in realtime.
    await for (final usageData in _watchUsageMap(_uid)) {
      try {
        int addressCount = 0;
        int jobCount = 0;
        int invoiceCount = 0;
        int quotationCount = 0;
        int templateCount = 0;
        int serviceCount = 0;
        int customerCount = 0;
        int jobApplicationsThisMonth = 0;
        int photoUploadCount = 0;
        int videoUploadCount = 0;
        int staffCount = 0;
        int freelanceHiresThisMonth = 0;
        int voiceSecondsUsedThisMonth = 0;
        int suggestionsUsedThisMonth = 0;

        if (usageData != null) {
          addressCount = usageData['addressCount'] ?? 0;
          jobCount = usageData['jobCount'] ?? 0;
          invoiceCount = usageData['invoiceCount'] ?? 0;
          quotationCount = usageData['quotationCount'] ?? 0;
          templateCount = usageData['templateCount'] ?? 0;
          serviceCount = usageData['serviceCount'] ?? 0;
          customerCount = usageData['customerCount'] ?? 0;
          jobApplicationsThisMonth = usageData['jobApplicationsThisMonth'] ?? 0;
          photoUploadCount = usageData['photoUploadCount'] ?? 0;
          videoUploadCount = usageData['videoUploadCount'] ?? 0;
          staffCount = usageData['staffCount'] ?? 0;
          freelanceHiresThisMonth = usageData['freelanceHiresThisMonth'] ?? 0;
          voiceSecondsUsedThisMonth =
              usageData['voiceSecondsUsedThisMonth'] ?? 0;
          suggestionsUsedThisMonth =
              usageData['suggestionsUsedThisMonth'] ?? 0;
        }

        final usage = UserUsageModel(
          addressCount: addressCount,
          jobCount: jobCount,
          invoiceCount: invoiceCount,
          quotationCount: quotationCount,
          templateCount: templateCount,
          serviceCount: serviceCount,
          customerCount: customerCount,
          jobApplicationsThisMonth: jobApplicationsThisMonth,
          photoUploadCount: photoUploadCount,
          videoUploadCount: videoUploadCount,
          staffCount: staffCount,
          freelanceHiresThisMonth: freelanceHiresThisMonth,
          voiceSecondsUsedThisMonth: voiceSecondsUsedThisMonth,
          suggestionsUsedThisMonth: suggestionsUsedThisMonth,
          limits: limits,
        );

        // Cache the usage stats
        await _cache.put(CacheBoxes.settings, _usageCacheKey, usage.toJson());

        yield usage;
      } catch (e) {
        debugPrint('Error processing usage update: $e');
      }
    }
  }

  @override
  Future<bool> canAddAddress() async {
    final usage = await getUserUsageStats();
    return usage.canAddAddress;
  }

  @override
  Future<bool> canCreateJob() async {
    final usage = await getUserUsageStats();
    return usage.canCreateJob;
  }

  @override
  Future<bool> canCreateInvoice() async {
    final usage = await getUserUsageStats();
    return usage.canCreateInvoice;
  }

  @override
  Future<bool> canCreateQuotation() async {
    final usage = await getUserUsageStats();
    return usage.canCreateQuotation;
  }

  @override
  Future<bool> canCreateTemplate() async {
    final usage = await getUserUsageStats();
    return usage.canCreateTemplate;
  }

  @override
  Future<bool> canCreateService() async {
    final usage = await getUserUsageStats();
    return usage.canCreateService;
  }

  @override
  Future<bool> canAddCustomer() async {
    final usage = await getUserUsageStats();
    return usage.canAddCustomer;
  }

  @override
  UserUsageModel? getCachedUsageStats() {
    if (!_isAuthenticated) return null;
    try {
      final cachedUsage = _cache.getJson(CacheBoxes.settings, _usageCacheKey);
      if (cachedUsage != null) {
        return UserUsageModel.fromJson(cachedUsage);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached usage stats: $e');
      return null;
    }
  }

  /// Calculate average usage percentage across all non-unlimited usage types
  ///
  /// Used for upgrade eligibility checks:
  /// - User qualifies for prorated pricing if average usage < 70%
  /// - Only includes usage types that have limits (not unlimited)
  /// - Returns 0 if no limited usage types exist
  Future<double> getAverageUsagePercentage() async {
    final usage = await getUserUsageStats();
    return calculateAverageUsagePercentage(usage);
  }

  /// Calculate average usage percentage from a UserUsageModel
  ///
  /// This is a static helper method that can be used without fetching usage data
  double calculateAverageUsagePercentage(UserUsageModel usage) {
    final percentages = <double>[];

    // Only include non-unlimited usage types
    if (!usage.limits.isAddressesUnlimited && usage.limits.maxAddresses > 0) {
      percentages.add(usage.addressUsagePercentage);
    }
    if (!usage.limits.isJobsUnlimited && usage.limits.maxJobs > 0) {
      percentages.add(usage.jobUsagePercentage);
    }
    if (!usage.limits.isInvoicesUnlimited && usage.limits.maxInvoices > 0) {
      percentages.add(usage.invoiceUsagePercentage);
    }
    if (!usage.limits.isQuotationsUnlimited && usage.limits.maxQuotations > 0) {
      percentages.add(usage.quotationUsagePercentage);
    }
    if (!usage.limits.isTemplatesUnlimited && usage.limits.maxTemplates > 0) {
      percentages.add(usage.templateUsagePercentage);
    }
    if (!usage.limits.isServicesUnlimited && usage.limits.maxServices > 0) {
      percentages.add(usage.serviceUsagePercentage);
    }
    if (!usage.limits.isCustomersUnlimited && usage.limits.maxCustomers > 0) {
      percentages.add(usage.customerUsagePercentage);
    }
    if (!usage.limits.isJobApplicationsUnlimited &&
        usage.limits.maxJobApplicationsPerMonth > 0) {
      percentages.add(usage.jobApplicationUsagePercentage);
    }
    if (!usage.limits.isPhotoUploadsUnlimited &&
        usage.limits.maxPhotoUploads > 0) {
      percentages.add(usage.photoUploadUsagePercentage);
    }
    if (!usage.limits.isVideoUploadsUnlimited &&
        usage.limits.maxVideoUploads > 0) {
      percentages.add(usage.videoUploadUsagePercentage);
    }

    if (percentages.isEmpty) return 0.0;

    return percentages.reduce((a, b) => a + b) / percentages.length;
  }

  @override
  Future<void> clearCache() async {
    await _cache.delete(CacheBoxes.settings, _usageCacheKey);
    await _cache.delete(CacheBoxes.settings, _limitsCacheKey);
  }

  @override
  Future<void> saveUsageStats(UserUsageModel usage) async {
    try {
      // upsert, because the counters row is created lazily on first write.
      await SupabaseService().client.from('usage_counters').upsert({
        'owner_id': _uid,
        'address_count': usage.addressCount,
        'job_count': usage.jobCount,
        'invoice_count': usage.invoiceCount,
        'quotation_count': usage.quotationCount,
        'template_count': usage.templateCount,
        'service_count': usage.serviceCount,
        'customer_count': usage.customerCount,
      }, onConflict: 'owner_id');

      debugPrint('Successfully saved usage stats for $_uid');

      // Update cache with new values
      await _cache.put(CacheBoxes.settings, _usageCacheKey, usage.toJson());
    } catch (e) {
      debugPrint('Error saving usage stats: $e');
      rethrow;
    }
  }

  /// Field name for a usage count type. Mapped to a column by UsageMapper.
  String _getCountFieldName(UsageCountType countType) {
    switch (countType) {
      case UsageCountType.address:
        return 'addressCount';
      case UsageCountType.invoice:
        return 'invoiceCount';
      case UsageCountType.quotation:
        return 'quotationCount';
      case UsageCountType.template:
        return 'templateCount';
      case UsageCountType.service:
        return 'serviceCount';
      case UsageCountType.customer:
        return 'customerCount';
      case UsageCountType.job:
        return 'jobCount';
      case UsageCountType.jobApplication:
        return 'jobApplicationsThisMonth';
      case UsageCountType.completedJob:
        return 'completedJobsCount';
      case UsageCountType.staff:
        return 'staffCount';
      // Business-specific usage types
      case UsageCountType.branch:
        return 'branchCount';
      case UsageCountType.project:
        return 'projectsThisMonth';
      case UsageCountType.photoUpload:
        return 'photoUploadCount';
      case UsageCountType.videoUpload:
        return 'videoUploadCount';
      case UsageCountType.voiceSeconds:
        return 'voiceSecondsUsedThisMonth';
      case UsageCountType.suggestion:
        return 'suggestionsUsedThisMonth';
      case UsageCountType.cancellation:
        return 'cancellationsThisMonth';
      case UsageCountType.tradesmanCancellation:
        return 'tradesmanCancellationsThisMonth';
      case UsageCountType.leadsViewed:
        return 'leadsViewedThisMonth';
      case UsageCountType.scheduledVisit:
        return 'scheduledVisitsCount';
    }
  }

  /// Get usage stats for a specific user (used by staff to check employer's limits)
  Future<UserUsageModel> getUserUsageStatsForUser(String userId) async {
    try {
      // Get user data for account type and plan
      final userData = await _fetchUserMap(userId);

      String accountType = 'customer';
      String planType = 'standard';

      if (userData != null) {
        accountType = userData['accountType'] as String? ?? 'customer';
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        final member = subscription?['member'] as Map<String, dynamic>?;
        planType =
            member?['planType'] as String? ??
            subscription?['planType'] as String? ??
            'standard';
        debugPrint(
          'UsageRepository.getUserUsageStatsForUser($userId): accountType=$accountType, planType=$planType',
        );
      }

      // Get limits based on plan
      final limits = await _configService.getFeatureLimitsByStrings(
        accountType,
        planType,
      );

      // Get usage counts from usages/{userId} path
      final usageData = await _fetchUsageMap(userId);

      int addressCount = 0;
      int jobCount = 0;
      int invoiceCount = 0;
      int quotationCount = 0;
      int templateCount = 0;
      int serviceCount = 0;
      int customerCount = 0;
      int jobApplicationsThisMonth = 0;
      int photoUploadCount = 0;
      int videoUploadCount = 0;
      int staffCount = 0;
      int freelanceHiresThisMonth = 0;

      int voiceSecondsUsedThisMonth = 0;
      int suggestionsUsedThisMonth = 0;

      if (usageData != null) {
        addressCount = usageData['addressCount'] ?? 0;
        jobCount = usageData['jobCount'] ?? 0;
        invoiceCount = usageData['invoiceCount'] ?? 0;
        quotationCount = usageData['quotationCount'] ?? 0;
        templateCount = usageData['templateCount'] ?? 0;
        serviceCount = usageData['serviceCount'] ?? 0;
        customerCount = usageData['customerCount'] ?? 0;
        jobApplicationsThisMonth = usageData['jobApplicationsThisMonth'] ?? 0;
        photoUploadCount = usageData['photoUploadCount'] ?? 0;
        videoUploadCount = usageData['videoUploadCount'] ?? 0;
        staffCount = usageData['staffCount'] ?? 0;
        freelanceHiresThisMonth = usageData['freelanceHiresThisMonth'] ?? 0;
        voiceSecondsUsedThisMonth =
            usageData['voiceSecondsUsedThisMonth'] ?? 0;
        suggestionsUsedThisMonth =
            usageData['suggestionsUsedThisMonth'] ?? 0;
      }

      return UserUsageModel(
        addressCount: addressCount,
        jobCount: jobCount,
        invoiceCount: invoiceCount,
        quotationCount: quotationCount,
        templateCount: templateCount,
        serviceCount: serviceCount,
        customerCount: customerCount,
        jobApplicationsThisMonth: jobApplicationsThisMonth,
        photoUploadCount: photoUploadCount,
        videoUploadCount: videoUploadCount,
        staffCount: staffCount,
        freelanceHiresThisMonth: freelanceHiresThisMonth,
        voiceSecondsUsedThisMonth: voiceSecondsUsedThisMonth,
        suggestionsUsedThisMonth: suggestionsUsedThisMonth,
        limits: limits,
      );
    } catch (e) {
      debugPrint('Error fetching user usage stats for $userId: $e');
      return UserUsageModel.empty;
    }
  }

  /// Increment usage count for a specific user (used by staff to update employer's usage)
  Future<void> incrementUsageCountForUser(
    String userId,
    UsageCountType countType,
  ) async {
    try {
      final fieldName = _getCountFieldName(countType);
      debugPrint(
        'incrementUsageCountForUser($userId, $fieldName): not supported — '
        'RLS scopes usage_counters to the signed-in user. This method has no '
        'callers; if cross-user counting is ever needed it must go through an '
        'Edge Function with an explicit staff-to-employer authorisation check.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Error incrementing usage count for user $userId ($countType): $e',
      );
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Decrement usage count for a specific user (used by staff to update employer's usage)
  Future<void> decrementUsageCountForUser(
    String userId,
    UsageCountType countType,
  ) async {
    try {
      final fieldName = _getCountFieldName(countType);
      const currentValue = 0;
      debugPrint(
        'decrementUsageCountForUser($userId, $fieldName): not supported — '
        'see incrementUsageCountForUser.',
      );

      if (currentValue > 0) {
        await _bump(fieldName, -1);
        debugPrint(
          'Successfully decremented $fieldName for user $userId from $currentValue',
        );
      } else {
        debugPrint(
          '$fieldName for user $userId is already 0, skipping decrement',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Error decrementing usage count for user $userId ($countType): $e',
      );
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Increment staff count for a specific user (used when staff invitation is accepted)
  Future<void> incrementStaffCountForUser(String userId) async {
    try {
      debugPrint(
        'incrementStaffCountForUser($userId): not supported — RLS scopes '
        'usage_counters to the signed-in user. No callers today.',
      );
    } catch (e, stackTrace) {
      debugPrint('Error incrementing staff count for user $userId: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Decrement staff count for a specific user (used when staff member is removed)
  Future<void> decrementStaffCountForUser(String userId) async {
    try {
      debugPrint(
        'decrementStaffCountForUser($userId): not supported — see '
        'incrementStaffCountForUser.',
      );
      const currentValue = 0;

      if (currentValue > 0) {
        await _bump('staffCount', -1);
        debugPrint(
          'Successfully decremented staffCount for user $userId from $currentValue',
        );
      } else {
        debugPrint(
          'staffCount for user $userId is already 0, skipping decrement',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error decrementing staff count for user $userId: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Future<void> incrementUsageCount(UsageCountType countType) async {
    try {
      final fieldName = _getCountFieldName(countType);
      debugPrint('Incrementing $fieldName');

      await _bump(fieldName, 1);

      debugPrint('Successfully incremented $fieldName');

      // Clear cache to force refresh
      await _cache.delete(CacheBoxes.settings, _usageCacheKey);
    } catch (e, stackTrace) {
      debugPrint('Error incrementing usage count ($countType): $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - usage tracking failure shouldn't break main operation
    }
  }

  @override
  Future<void> decrementUsageCount(UsageCountType countType) async {
    try {
      final fieldName = _getCountFieldName(countType);
      debugPrint('Decrementing $fieldName');

      // The old code read the value, compared it to 0, then wrote — two round
      // trips with a race between them. bump_usage floors at zero inside a
      // single statement, so the guard is both unnecessary and safer gone.
      await _bump(fieldName, -1);
      debugPrint('Successfully decremented $fieldName');

      // Clear cache to force refresh
      await _cache.delete(CacheBoxes.settings, _usageCacheKey);
    } catch (e, stackTrace) {
      debugPrint('Error decrementing usage count ($countType): $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - usage tracking failure shouldn't break main operation
    }
  }

  @override
  Future<void> resetUsage() async {
    try {
      debugPrint('Resetting usage for $_uid');

      // reset_usage() zeroes exactly the same counter list this method
      // used to write, in one statement.
      await SupabaseService().client.rpc('reset_usage');

      debugPrint('Successfully reset usage');

      // Clear cache to force refresh
      await _cache.delete(CacheBoxes.settings, _usageCacheKey);
    } catch (e, stackTrace) {
      debugPrint('Error resetting usage: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Increment voice seconds used by a specific amount
  Future<void> incrementVoiceSeconds(int seconds) async {
    try {
      await _bump('voiceSecondsUsedThisMonth', seconds);
      await _cache.delete(CacheBoxes.settings, _usageCacheKey);
    } catch (e) {
      debugPrint('Error incrementing voice seconds: $e');
    }
  }

  /// Get business-specific limits for the current user
  /// Fetches dynamic limits from the subscription config service
  Future<BusinessLimitsModel> getBusinessLimits() async {
    try {
      // Get user data to determine subscription plan
      final userData = await _fetchUserMap(_uid);

      if (userData == null) {
        debugPrint('User not found, using default business limits');
        return const BusinessLimitsModel();
      }

      final accountType = userData['accountType'] as String? ?? 'customer';

      // Only business accounts have business limits
      if (accountType != 'business') {
        debugPrint('Not a business account, returning default limits');
        return const BusinessLimitsModel();
      }

      // Get subscription plan name from user's subscription
      // Try multiple possible locations for planId/planType
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      final member = subscription?['member'] as Map<String, dynamic>?;

      // Try member.planType first, then subscription.planType
      String planType =
          member?['planType'] as String? ??
          subscription?['planType'] as String? ??
          'standard';

      debugPrint('User subscription planType: $planType');

      // Use config service to get dynamic limits from app_config
      final featureLimits = await _configService.getFeatureLimitsByStrings(
        accountType,
        planType,
      );

      final businessLimits =
          featureLimits.businessLimits ?? const BusinessLimitsModel();
      debugPrint(
        'Business limits for $planType - maxStaffMembers: ${businessLimits.maxStaffMembers}, isUnlimited: ${businessLimits.isStaffMembersUnlimited}',
      );
      return businessLimits;
    } catch (e, stackTrace) {
      debugPrint('Error fetching business limits: $e');
      debugPrint('Stack trace: $stackTrace');
      return const BusinessLimitsModel();
    }
  }

  /// Get business-specific limits for a specific user
  /// Fetches dynamic limits from the subscription config service
  Future<BusinessLimitsModel> getBusinessLimitsForUser(String userId) async {
    try {
      // Get user data to determine subscription plan
      final userData = await _fetchUserMap(userId);

      if (userData == null) {
        debugPrint('User $userId not found, using default business limits');
        return const BusinessLimitsModel();
      }

      final accountType = userData['accountType'] as String? ?? 'customer';

      // Only business accounts have business limits
      if (accountType != 'business') {
        debugPrint(
          'User $userId is not a business account, returning default limits',
        );
        return const BusinessLimitsModel();
      }

      // Get subscription plan name from user's subscription
      // Try multiple possible locations for planId/planType
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      final member = subscription?['member'] as Map<String, dynamic>?;

      // Try member.planType first, then subscription.planType
      String planType =
          member?['planType'] as String? ??
          subscription?['planType'] as String? ??
          'standard';

      debugPrint('User $userId subscription planType: $planType');

      // Use config service to get dynamic limits from app_config
      final featureLimits = await _configService.getFeatureLimitsByStrings(
        accountType,
        planType,
      );

      final businessLimits =
          featureLimits.businessLimits ?? const BusinessLimitsModel();
      debugPrint(
        'Business limits for user $userId ($planType) - maxStaffMembers: ${businessLimits.maxStaffMembers}',
      );
      return businessLimits;
    } catch (e) {
      debugPrint('Error fetching business limits for user $userId: $e');
      return const BusinessLimitsModel();
    }
  }

  /// Get business usage stats for the current user
  Future<Map<String, int>> getBusinessUsageStats() async {
    try {
      final usageData = await _fetchUsageMap(_uid);

      if (usageData == null) {
        return {
          'branchCount': 0,
          'staffCount': 0,
          'projectsThisMonth': 0,
          'photoUploadCount': 0,
          'videoUploadCount': 0,
        };
      }


      return {
        'branchCount': usageData['branchCount'] ?? 0,
        'staffCount': usageData['staffCount'] ?? 0,
        'projectsThisMonth': usageData['projectsThisMonth'] ?? 0,
        'photoUploadCount': usageData['photoUploadCount'] ?? 0,
        'videoUploadCount': usageData['videoUploadCount'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching business usage stats: $e');
      return {
        'branchCount': 0,
        'staffCount': 0,
        'projectsThisMonth': 0,
        'photoUploadCount': 0,
        'videoUploadCount': 0,
      };
    }
  }

  /// Check if business user can add more staff members
  Future<bool> canAddStaffMember() async {
    try {
      final limits = await getBusinessLimits();
      final usage = await getBusinessUsageStats();
      final currentCount = usage['staffCount'] ?? 0;
      return limits.canAddStaff(currentCount);
    } catch (e) {
      debugPrint('Error checking staff member limit: $e');
      return false;
    }
  }

  /// Check if business user can add more branches
  Future<bool> canAddBranch() async {
    try {
      final limits = await getBusinessLimits();
      final usage = await getBusinessUsageStats();
      final currentCount = usage['branchCount'] ?? 0;
      return limits.canAddBranch(currentCount);
    } catch (e) {
      debugPrint('Error checking branch limit: $e');
      return false;
    }
  }

  /// Check if business user can create more projects this month
  Future<bool> canCreateProject() async {
    try {
      final limits = await getBusinessLimits();
      final usage = await getBusinessUsageStats();
      final currentCount = usage['projectsThisMonth'] ?? 0;
      return limits.canCreateProject(currentCount);
    } catch (e) {
      debugPrint('Error checking project limit: $e');
      return false;
    }
  }

  /// Get staff limit info for business user
  Future<({int current, int max, bool isUnlimited})> getStaffLimitInfo() async {
    try {
      final limits = await getBusinessLimits();
      final usage = await getBusinessUsageStats();
      final currentCount = usage['staffCount'] ?? 0;
      return (
        current: currentCount,
        max: limits.maxStaffMembers,
        isUnlimited: limits.isStaffMembersUnlimited,
      );
    } catch (e) {
      debugPrint('Error getting staff limit info: $e');
      return (current: 0, max: 5, isUnlimited: false);
    }
  }
}
