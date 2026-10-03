import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/app_config_store.dart';
import '../../models/config/commission_rates_model.dart';
import 'base_commission_repository.dart';

/// Repository for fetching commission rates configuration.
///
/// Was RTDB `config/commissionRates`; now the `commissionRates` key in
/// `app_config`. A missing key still falls back to
/// [CommissionRatesModel.defaultRates], exactly as a missing RTDB node did.
class CommissionRepository implements BaseCommissionRepository {
  static const String _configKey = 'commissionRates';

  final AppConfigStore _config = AppConfigStore();

  /// In-memory cache for commission rates
  CommissionRatesModel? _cache;

  StreamSubscription? _subscription;

  final _ratesController = StreamController<CommissionRatesModel>.broadcast();

  CommissionRepository();

  /// Get commission rates (with caching)
  Future<CommissionRatesModel> getRates() async {
    try {
      if (_cache != null) {
        return _cache!;
      }

      await _config.load();
      final data = _config.map(_configKey);

      if (data == null || data.isEmpty) {
        debugPrint('No commission rates found, using defaults');
        return CommissionRatesModel.defaultRates;
      }

      final rates = CommissionRatesModel.fromJson(data);
      _cache = rates;

      debugPrint(
        'Fetched commission rates: '
        'tradesman=${rates.tradesmanCommission}%, '
        'business=${rates.businessCommission}%, '
        'emergency=${rates.emergencyJobPremium}%',
      );

      return rates;
    } catch (e) {
      debugPrint('Error fetching commission rates: $e');
      return _cache ?? CommissionRatesModel.defaultRates;
    }
  }

  /// Watch commission rates for real-time updates
  Stream<CommissionRatesModel> watchRates() {
    if (_subscription == null) {
      _subscription = _config.watchKey(_configKey).listen(
        (value) {
          if (value is Map && value.isNotEmpty) {
            final rates = CommissionRatesModel.fromJson(
              Map<String, dynamic>.from(value),
            );
            _cache = rates;
            _ratesController.add(rates);
          } else {
            _ratesController.add(CommissionRatesModel.defaultRates);
          }
        },
        onError: (Object error) {
          debugPrint('Error watching commission rates: $error');
          _ratesController.addError(error);
        },
      );
    }

    if (_cache != null) {
      Future.microtask(() => _ratesController.add(_cache!));
    }

    return _ratesController.stream;
  }

  /// Get commission rate for a specific account type
  Future<double> getCommissionForAccountType(String accountType) async {
    final rates = await getRates();
    return rates.getCommissionByAccountType(accountType);
  }

  Future<void> clearCache() async {
    _cache = null;
    debugPrint('Commission rates cache cleared');
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _ratesController.close();
  }
}
