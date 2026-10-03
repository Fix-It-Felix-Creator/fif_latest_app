import '../../core/enum.dart';
import '../../models/subscription_plan_model.dart';

/// Base abstract class for subscription plan repository
abstract class BaseSubscriptionRepository {
  /// Get all subscription plans for a specific account type
  Future<List<SubscriptionPlanModel>> getPlans(AccountCategoryType accountType);

  /// Watch subscription plans for real-time updates
  Stream<List<SubscriptionPlanModel>> watchPlans(
    AccountCategoryType accountType,
  );

  /// Get all active plans for a specific account type
  Future<List<SubscriptionPlanModel>> getActivePlans(
    AccountCategoryType accountType,
  );

  /// Get a specific plan by ID and account type
  Future<SubscriptionPlanModel?> getPlanById(
    AccountCategoryType accountType,
    int planId,
  );

  /// Get plans by plan type
  Future<List<SubscriptionPlanModel>> getPlansByType(
    AccountCategoryType accountType,
    PlanType planType,
  );

  /// Clear cached plans data
  Future<void> clearCache();
}
