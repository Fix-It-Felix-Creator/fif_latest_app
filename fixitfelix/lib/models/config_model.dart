import '../core/config/config_service.dart';

class AppConfigModel {
  final String? appStoreLink;
  final String? playStoreLink;
  final RemoteConfigVariable devVariable;
  final RemoteConfigVariable prodVariable;
  final bool? forceAppUpdate;
  final bool? devForceAppUpdate;
  final String androidAppVersion;
  final String iosAppVersion;
  final MaintenanceConfig devMaintenance;
  final MaintenanceConfig prodMaintenance;

  AppConfigModel({
    required this.appStoreLink,
    required this.playStoreLink,
    required this.devVariable,
    required this.prodVariable,
    required this.forceAppUpdate,
    required this.devForceAppUpdate,
    required this.androidAppVersion,
    required this.iosAppVersion,
    required this.devMaintenance,
    required this.prodMaintenance,
  });

  factory AppConfigModel.fromRemoteConfig(ConfigService configService) {
    return AppConfigModel(
      appStoreLink: configService.appstoreLink,
      playStoreLink: configService.playstoreLink,
      devVariable: configService.devVariable,
      prodVariable: configService.prodVariable,
      forceAppUpdate: configService.prodForceAppUpdate,
      devForceAppUpdate: configService.devForceAppUpdate,
      androidAppVersion: configService.androidAppVersion,
      iosAppVersion: configService.iosAppVersion,
      devMaintenance: configService.devMaintenance,
      prodMaintenance: configService.prodMaintenance,
    );
  }

  /// Get the current force app update value based on APP_TYPE
  bool get currentForceAppUpdate {
    final config = ConfigService();
    if (config.isProduction) {
      return forceAppUpdate ?? false;
    }
    return devForceAppUpdate ?? false;
  }

  /// Get the current maintenance config based on APP_TYPE
  MaintenanceConfig get currentMaintenance {
    final config = ConfigService();
    if (config.isProduction) {
      return prodMaintenance;
    }
    return devMaintenance;
  }

  /// Check if app is under maintenance
  bool get isUnderMaintenance {
    return currentMaintenance.isEnabled;
  }

  @override
  String toString() {
    return 'AppConfig(appStoreLink: $appStoreLink, playStoreLink: $playStoreLink, devVariable: $devVariable, prodVariable: $prodVariable, androidAppVersion: $androidAppVersion, iosAppVersion: $iosAppVersion, forceAppUpdate: $forceAppUpdate, devForceAppUpdate: $devForceAppUpdate, devMaintenance: ${devMaintenance.toJson()}, prodMaintenance: ${prodMaintenance.toJson()})';
  }
}
