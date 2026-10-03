import '../../models/feature_limits_model.dart';
import '../../models/user_usage_model.dart';

/// Base repository interface for user usage and feature limits
abstract class BaseUsageRepository {
  /// Get the feature limits for the current user based on their subscription
  Future<FeatureLimitsModel> getUserLimits();

  /// Get the current usage stats for the user
  Future<UserUsageModel> getUserUsageStats();

  /// Stream of usage stats updates
  Stream<UserUsageModel> watchUsageStats();

  /// Check if user can add more addresses
  Future<bool> canAddAddress();

  /// Check if user can create more jobs
  Future<bool> canCreateJob();

  /// Check if user can create more invoices
  Future<bool> canCreateInvoice();

  /// Check if user can create more quotations
  Future<bool> canCreateQuotation();

  /// Check if user can create more templates
  Future<bool> canCreateTemplate();

  /// Check if user can create more services
  Future<bool> canCreateService();

  /// Check if user can add more customers
  Future<bool> canAddCustomer();

  /// Get cached usage stats (synchronous)
  UserUsageModel? getCachedUsageStats();

  /// Clear cached usage stats
  Future<void> clearCache();

  /// Save usage stats to Firebase
  Future<void> saveUsageStats(UserUsageModel usage);

  /// Increment a usage count in Firebase
  Future<void> incrementUsageCount(UsageCountType countType);

  /// Decrement a usage count in Firebase
  Future<void> decrementUsageCount(UsageCountType countType);

  /// Reset all usage counts to 0 (called after subscription renewal/upgrade)
  Future<void> resetUsage();
}

/// Types of usage counts that can be incremented/decremented
enum UsageCountType {
  address,
  invoice,
  quotation,
  template,
  service,
  customer,
  job,
  jobApplication,
  completedJob,
  staff,
  // Business-specific usage types
  branch,
  project,
  photoUpload,
  videoUpload,
  // AI chat agent usage types
  voiceSeconds,
  suggestion,
  // Platform gate usage types
  cancellation,
  tradesmanCancellation,
  leadsViewed,
  scheduledVisit,
}
