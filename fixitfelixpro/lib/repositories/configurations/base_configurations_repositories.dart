import '../../models/config_model.dart';

abstract class BaseConfigurationRepositories {
  /// Initialize the configuration repository
  Future<void> initialize();

  /// Get environment data configuration
  AppConfigModel get getENVData;

  /// Get domain variable based on environment (dev/prod)
  Map<String, dynamic> getDomainVariable(
    Map<String, dynamic> dev,
    Map<String, dynamic> prod,
  );
}
