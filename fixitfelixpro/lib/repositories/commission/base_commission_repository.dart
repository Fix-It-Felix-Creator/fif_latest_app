import '../../models/config/commission_rates_model.dart';

/// Abstract base class for commission repository operations
/// Defines the contract for commission rate operations
abstract class BaseCommissionRepository {
  // ============================================
  // Commission Rate Operations
  // ============================================

  /// Get commission rates from Firebase (with caching)
  Future<CommissionRatesModel> getRates();

  /// Watch commission rates for real-time updates
  Stream<CommissionRatesModel> watchRates();

  /// Get commission rate for a specific account type
  Future<double> getCommissionForAccountType(String accountType);

  // ============================================
  // Cache Operations
  // ============================================

  /// Clear the cache
  Future<void> clearCache();

  /// Dispose resources
  void dispose();
}
