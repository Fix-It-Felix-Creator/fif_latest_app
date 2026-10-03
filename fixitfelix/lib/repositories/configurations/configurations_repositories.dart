import 'package:flutter/foundation.dart';

import '../../core/config/config_service.dart';
import '../../core/services/app_config_store.dart';
import '../../models/config_model.dart';
import 'base_configurations_repositories.dart';

class ConfigurationRepository extends BaseConfigurationRepositories {
  final ConfigService _configService = ConfigService();

  /// Was constructed with a `FirebaseRemoteConfig` instance. The dependency is
  /// gone — configuration comes from the `app_config` table via
  /// [AppConfigStore] — but the constructor stays no-arg-compatible so
  /// `main.dart` and every call site are unaffected.
  ConfigurationRepository();

  @override
  Future<void> initialize() async {
    try {
      await AppConfigStore().load(forceRefresh: true);
    } catch (e) {
      // Fetch failed — the app falls back to cached values or defaults, as
      // it did when Remote Config was unreachable.
      debugPrint('Failed to fetch app config: $e');
    }
  }

  @override
  AppConfigModel get getENVData =>
      AppConfigModel.fromRemoteConfig(_configService);

  @override
  Map<String, dynamic> getDomainVariable(
    Map<String, dynamic> dev,
    Map<String, dynamic> prod,
  ) {
    if (_configService.isProduction) {
      return prod;
    } else {
      return dev;
    }
  }
}
