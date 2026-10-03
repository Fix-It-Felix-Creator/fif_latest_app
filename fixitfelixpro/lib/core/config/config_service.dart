import 'dart:convert';
import 'dart:io';

import 'package:fixitfelix/core/config/environment_variables.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/app_config_store.dart';

/// App type enum for environment switching
enum AppType { development, production }

/// Remote config variable model for prod/dev environments
class RemoteConfigVariable {
  final String databaseUrl;
  // General Cloud Functions base URL. Named `stripeBackendUrl` for
  // historical reasons; it now serves all backend endpoints (invoices,
  // quotes, account, notifications, IAP validation) — not just payments.
  final String stripeBackendUrl;
  final bool debug;
  final String privacyPolicyUrl;
  final String termsAndConditionsUrl;
  final String helpCenterUrl;
  // Contact support details
  final String supportEmail;
  final String supportPhone;
  final String supportWhatsApp;
  final String supportHours;
  // Chat Agent
  final String chatAgentBaseUrl;
  // YouTube channel for the home-screen learn banner. Empty string
  // means the banner stays hidden.
  final String youtubeChannelUrl;
  // Facebook community group for the settings-screen banner. Empty
  // string means the banner stays hidden.
  final String facebookGroupUrl;

  RemoteConfigVariable({
    required this.databaseUrl,
    required this.stripeBackendUrl,
    required this.debug,
    required this.privacyPolicyUrl,
    required this.termsAndConditionsUrl,
    required this.helpCenterUrl,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportWhatsApp,
    required this.supportHours,
    required this.chatAgentBaseUrl,
    required this.youtubeChannelUrl,
    required this.facebookGroupUrl,
  });

  factory RemoteConfigVariable.fromJson(Map<String, dynamic> json) {
    return RemoteConfigVariable(
      databaseUrl: json['databaseUrl'] ?? '',
      stripeBackendUrl: json['stripeBackendUrl'] ?? '',
      debug: json['debug'] ?? false,
      privacyPolicyUrl: json['privacyPolicyUrl'] ?? '',
      termsAndConditionsUrl: json['termsAndConditionsUrl'] ?? '',
      helpCenterUrl: json['helpCenterUrl'] ?? '',
      supportEmail: json['supportEmail'] ?? '',
      supportPhone: json['supportPhone'] ?? '',
      supportWhatsApp: json['supportWhatsApp'] ?? '',
      supportHours: json['supportHours'] ?? '',
      chatAgentBaseUrl: json['chatAgentBaseUrl'] ?? '',
      youtubeChannelUrl: json['youtubeChannelUrl'] ?? '',
      facebookGroupUrl: json['facebookGroupUrl'] ?? '',
    );
  }

  factory RemoteConfigVariable.empty() {
    return RemoteConfigVariable(
      databaseUrl: '',
      stripeBackendUrl: '',
      debug: false,
      privacyPolicyUrl: '',
      termsAndConditionsUrl: '',
      helpCenterUrl: '',
      supportEmail: '',
      supportPhone: '',
      supportWhatsApp: '',
      supportHours: '',
      chatAgentBaseUrl: '',
      youtubeChannelUrl: '',
      facebookGroupUrl: '',
    );
  }

}

/// Maintenance config model
class MaintenanceConfig {
  final bool isEnabled;
  final String title;
  final String message;
  final String? estimatedEndTime;
  final bool allowBypass;

  MaintenanceConfig({
    required this.isEnabled,
    required this.title,
    required this.message,
    this.estimatedEndTime,
    this.allowBypass = false,
  });

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    return MaintenanceConfig(
      isEnabled: json['isEnabled'] ?? false,
      title: json['title'] ?? 'Under Maintenance',
      message:
          json['message'] ??
          'We are currently performing maintenance. Please try again later.',
      estimatedEndTime: json['estimatedEndTime'],
      allowBypass: json['allowBypass'] ?? false,
    );
  }

  factory MaintenanceConfig.disabled() {
    return MaintenanceConfig(isEnabled: false, title: '', message: '');
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'title': title,
      'message': message,
      'estimatedEndTime': estimatedEndTime,
      'allowBypass': allowBypass,
    };
  }
}

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  // Canonical per-environment endpoints. These are the source of truth for
  // routing and are used to SELF-HEAL a stale/mismatched Remote Config:
  // the compile-time APP_TYPE (.env, baked into the binary) decides the
  // environment, and these guarantee the RTDB + backend always belong to
  // that same environment even if RC hands back the wrong env's URL.
  // Must stay in sync with functions/src/lib/env.ts (RTDB_URL) and the
  // Supabase Edge Function `api`, one per project.
  //
  // Environments used to be distinguished by a name suffix on a single
  // Firebase project (`api` vs `apiProd`); they are now separate Supabase
  // projects, so the project ref IS the environment. That makes the
  // mismatch check below stricter than it could ever be before: a staging
  // build cannot silently talk to the production database.
  static const String _stagingProjectRef = 'mjteytegbjvemuxoimlq';
  static const String _prodProjectRef = 'nhghuurzmwoirnjkpvaa';

  static const String _stagingBackendUrl =
      'https://$_stagingProjectRef.supabase.co/functions/v1/api';
  static const String _prodBackendUrl =
      'https://$_prodProjectRef.supabase.co/functions/v1/api';

  // Cached remote config values
  RemoteConfigVariable? _prodVariable;
  RemoteConfigVariable? _devVariable;
  String? _androidAppVersion;
  String? _iosAppVersion;
  String? _appstoreLink;
  String? _playstoreLink;
  bool? _forceAppUpdate;
  bool? _devForceAppUpdate;
  MaintenanceConfig? _prodMaintenance;
  MaintenanceConfig? _devMaintenance;

  Future<void> initialize() async {
    // `.env` is already loaded by main.dart (config/{staging|production}/.env)
    // — don't re-load here. Calling `dotenv.load` a second time would
    // clear the map, and a failing second load leaves it empty, wiping
    // every key main.dart populated.
    debugPrint(
      "ConfigService: APP_VERSION from .env: ${dotenv.env['APP_VERSION']}",
    );

    // Load client configuration.
    //
    // Was Firebase Remote Config; now the `app_config` table, which is
    // publicly readable so values are available before sign-in. AppConfigStore
    // caches to Hive, so a cold offline launch still gets the last-known
    // configuration instead of falling back to built-in defaults.
    try {
      // A failure here (offline, timeout) must NOT be swallowed silently: the
      // app would then keep running on whatever values are cached on disk —
      // potentially a stale env that routes writes to the wrong backend. The
      // store logs loudly and keeps its cached copy, and the APP_TYPE-
      // authoritative self-heal in the `databaseUrl` / `stripeBackendUrl`
      // getters still guarantees routing correctness.
      await AppConfigStore().load(forceRefresh: true);

      // Parse and cache config values
      _parseAppConfig();

      // Sanity check: the RTDB url and the backend (Cloud Functions) url
      // for the active env must agree. If a stale/partial config leaves
      // them split (e.g. production RTDB + staging `/api` backend), every
      // subscription write lands in a different database than reads — the
      // exact failure that breaks the free-trial flow. Surface it.
      _assertBackendMatchesDatabase();

      debugPrint("ConfigService: app config initialized");
      debugPrint("ConfigService: APP_TYPE=$appType");
      debugPrint("ConfigService: isProduction=$isProduction");
      debugPrint("ConfigService: isDevelopment=$isDevelopment");
      debugPrint("ConfigService: Current Platform=$currentPlatform");
      debugPrint("ConfigService: Current App Version=$currentAppVersion");
      debugPrint("ConfigService: android_app_version=$androidAppVersion");
      debugPrint("ConfigService: ios_app_version=$iosAppVersion");
      debugPrint(
        "ConfigService: Min Required Version ($currentPlatform)=$minRequiredVersion",
      );
      debugPrint("ConfigService: force_app_update (prod)=$prodForceAppUpdate");
      debugPrint("ConfigService: dev_force_app_update=$devForceAppUpdate");
      debugPrint(
        "ConfigService: Active force_app_update ($appType)=$forceAppUpdate",
      );
      debugPrint("ConfigService: requiresForceUpdate=$requiresForceUpdate");
      debugPrint("ConfigService: ---- MAINTENANCE CONFIG ----");
      debugPrint(
        "ConfigService: dev_maintenance.isEnabled=${_devMaintenance?.isEnabled}",
      );
      debugPrint(
        "ConfigService: prod_maintenance.isEnabled=${_prodMaintenance?.isEnabled}",
      );
      debugPrint(
        "ConfigService: Active isUnderMaintenance ($appType)=$isUnderMaintenance",
      );
      debugPrint("ConfigService: maintenanceTitle=$maintenanceTitle");
      debugPrint(
        "ConfigService: allowMaintenanceBypass=$allowMaintenanceBypass",
      );
    } catch (e) {
      debugPrint("ConfigService: Failed to initialize Remote Config: $e");
    }
  }

  /// Reads the config keys out of [AppConfigStore] into typed fields.
  ///
  /// Remote Config returned JSON as strings that had to be decoded; app_config
  /// stores real jsonb, so object-valued keys arrive as maps directly. Scalar
  /// keys are wrapped as `{"value": ...}` by the seed, which
  /// [AppConfigStore.scalar] unwraps.
  ///
  /// Each block keeps its own try/catch and leaves the existing field value
  /// untouched on failure, so a missing or malformed key degrades to the
  /// built-in default exactly as Remote Config's `setDefaults` did.
  void _parseAppConfig() {
    final store = AppConfigStore();

    // Parse prod_variable
    try {
      final prod = store.map('prod_variable');
      if (prod != null && prod.isNotEmpty) {
        _prodVariable = RemoteConfigVariable.fromJson(prod);
      }
    } catch (e) {
      debugPrint("ConfigService: Failed to parse prod_variable: $e");
    }

    // Parse dev_variable
    try {
      final dev = store.map('dev_variable');
      if (dev != null && dev.isNotEmpty) {
        _devVariable = RemoteConfigVariable.fromJson(dev);
      }
    } catch (e) {
      debugPrint("ConfigService: Failed to parse dev_variable: $e");
    }

    // Parse prod_maintenance
    try {
      final prodMaintenance = store.map('prod_maintenance');
      if (prodMaintenance != null && prodMaintenance.isNotEmpty) {
        _prodMaintenance = MaintenanceConfig.fromJson(prodMaintenance);
      }
    } catch (e) {
      debugPrint("ConfigService: Failed to parse prod_maintenance: $e");
    }

    // Parse dev_maintenance
    try {
      final devMaintenance = store.map('dev_maintenance');
      if (devMaintenance != null && devMaintenance.isNotEmpty) {
        _devMaintenance = MaintenanceConfig.fromJson(devMaintenance);
      }
    } catch (e) {
      debugPrint("ConfigService: Failed to parse dev_maintenance: $e");
    }

    // Parse other values (used for all app types)
    _androidAppVersion =
        store.scalar('android_app_version') ?? _androidAppVersion;
    _iosAppVersion = store.scalar('ios_app_version') ?? _iosAppVersion;
    _appstoreLink = store.scalar('appstore_link') ?? _appstoreLink;
    _playstoreLink = store.scalar('playstore_link') ?? _playstoreLink;

    // Parse force app update values
    _forceAppUpdate = store.boolean('force_app_update');
    _devForceAppUpdate = store.boolean('dev_force_app_update');
  }

  /// Guard against a split-environment config where the RTDB url and the
  /// backend (Cloud Functions) url for the active env disagree. The
  /// production backend is `.../apiProd` (writes to the production RTDB);
  /// staging is `.../api` (writes to the staging RTDB). If the database
  /// url is production but the backend is staging (or vice-versa), every
  /// HTTP-backed write (free-trial activation, IAP validation) lands in a
  /// different database than the SDK reads from — silently corrupting the
  /// subscription gate. We can't safely auto-correct (we don't know which
  /// side is right), so we make it loud: assert in debug, error-log in
  /// release.
  /// Guard against a config that routes this build at the wrong environment.
  ///
  /// This used to compare the RTDB url against the Cloud Function name, after
  /// a split config (production database + staging backend) silently sent
  /// every subscription write to the wrong place and broke the free-trial
  /// flow. Realtime Database is gone, but the failure it guarded against is
  /// not: dev and prod are separate Supabase projects, and a stale
  /// `stripeBackendUrl` would point a staging build at production data.
  ///
  /// The getter above already self-heals to the canonical URL, so reaching
  /// the assert means the config is wrong in a way worth seeing in debug.
  void _assertBackendMatchesDatabase() {
    final backend = stripeBackendUrl;
    // Empty means config never loaded (offline first run) — the empty-url
    // fallbacks handle that case elsewhere.
    if (backend.isEmpty) return;

    final expectedRef = isProduction ? _prodProjectRef : _stagingProjectRef;
    if (!backend.contains(expectedRef)) {
      final msg =
          'ConfigService: ENV MISMATCH — stripeBackendUrl=$backend does not '
          'name the expected project ($expectedRef) for APP_TYPE=$appType. '
          'Subscription/trial writes would land in the wrong project. '
          '`app_config.${isProduction ? 'prod' : 'dev'}_variable` is likely '
          'stale on this device.';
      debugPrint(msg);
      assert(false, msg);
    }
  }

  // ===========================================================================
  // APP TYPE DETECTION
  // ===========================================================================

  /// Get APP_TYPE from .env file
  String get appType {
    return dotenv.env['APP_TYPE'] ?? 'DEVELOPMENT';
  }

  /// Check if app is running in production mode
  bool get isProduction {
    return appType.toUpperCase() == 'PRODUCTION';
  }

  /// Check if app is running in development mode
  bool get isDevelopment {
    return appType.toUpperCase() == 'DEVELOPMENT';
  }

  /// Get current environment variable based on APP_TYPE from .env
  RemoteConfigVariable get currentEnvVariable {
    if (isProduction) {
      return _prodVariable ?? RemoteConfigVariable.empty();
    }
    return _devVariable ?? RemoteConfigVariable.empty();
  }

  // ===========================================================================
  // USER STORAGE PATH
  // ===========================================================================

  /// Get users storage root path based on APP_TYPE
  /// DEVELOPMENT: 'users'
  /// PRODUCTION: 'pod_users'
  String get usersStoragePath {
    if (isProduction) {
      return 'pod_users';
    }
    return 'users';
  }

  // ===========================================================================
  // LEGAL & HELP URLS (from dev_variable/prod_variable)
  // ===========================================================================

  /// Get privacy policy URL based on APP_TYPE
  String get privacyPolicyUrl {
    return currentEnvVariable.privacyPolicyUrl;
  }

  /// Get terms and conditions URL based on APP_TYPE
  String get termsAndConditionsUrl {
    return currentEnvVariable.termsAndConditionsUrl;
  }

  /// Get help center URL based on APP_TYPE
  String get helpCenterUrl {
    return currentEnvVariable.helpCenterUrl;
  }

  // ===========================================================================
  // CONTACT SUPPORT (from dev_variable/prod_variable)
  // ===========================================================================

  /// Get support email based on APP_TYPE
  String get supportEmail {
    return currentEnvVariable.supportEmail;
  }

  /// Get support phone number based on APP_TYPE
  String get supportPhone {
    return currentEnvVariable.supportPhone;
  }

  /// Get support WhatsApp number based on APP_TYPE
  String get supportWhatsApp {
    return currentEnvVariable.supportWhatsApp;
  }

  /// Get support hours based on APP_TYPE
  String get supportHours {
    return currentEnvVariable.supportHours;
  }

  // ===========================================================================
  // APP CONFIG
  // ===========================================================================

  /// The build's own version.
  ///
  /// Remote Config carried an APP_VERSION key, but only ever as a default
  /// mirroring `.env` — it was never set server-side, and shipping a version
  /// number from the server would be wrong anyway: it describes the binary
  /// the user is running, not what the backend thinks is current. Read
  /// straight from `.env`. (`android_app_version` / `ios_app_version`, which
  /// ARE server-driven, remain in app_config for the force-update check.)
  String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';

  /// Get current app version from .env file
  /// This is used for force update comparison with remote config versions
  String get currentAppVersion {
    return dotenv.env['APP_VERSION'] ?? '1.0.0';
  }

  // ===========================================================================
  // PLATFORM DETECTION
  // ===========================================================================

  /// Check if running on Android
  bool get isAndroid => Platform.isAndroid;

  /// Check if running on iOS
  bool get isIOS => Platform.isIOS;

  /// Get current platform name
  String get currentPlatform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  // ===========================================================================
  // VERSION CONFIG (used for all app types)
  // ===========================================================================

  String get androidAppVersion {
    return _androidAppVersion ?? '1.0.0';
  }

  String get iosAppVersion {
    return _iosAppVersion ?? '1.0.0';
  }

  /// Get minimum required app version based on current platform
  /// Android: uses android_app_version from remote config
  /// iOS: uses ios_app_version from remote config
  String get minRequiredVersion {
    if (Platform.isAndroid) {
      return androidAppVersion;
    } else if (Platform.isIOS) {
      return iosAppVersion;
    }
    return '1.0.0';
  }

  /// Get force app update based on APP_TYPE
  /// DEVELOPMENT: uses dev_force_app_update
  /// PRODUCTION: uses force_app_update
  bool get forceAppUpdate {
    if (isProduction) {
      return _forceAppUpdate ?? false;
    }
    return _devForceAppUpdate ?? false;
  }

  /// Get dev force app update value directly
  bool get devForceAppUpdate {
    return _devForceAppUpdate ?? false;
  }

  /// Get prod force app update value directly
  bool get prodForceAppUpdate {
    return _forceAppUpdate ?? false;
  }

  /// Check if current app version requires force update
  /// Uses platform-specific version from remote config:
  /// - Android: compares with android_app_version
  /// - iOS: compares with ios_app_version
  /// And APP_TYPE-specific force update flag:
  /// - DEVELOPMENT: uses dev_force_app_update
  /// - PRODUCTION: uses force_app_update
  bool get requiresForceUpdate {
    if (!forceAppUpdate) {
      debugPrint("ConfigService: Force update disabled for $appType");
      return false;
    }

    try {
      final currentVersion = _parseVersion(currentAppVersion);
      final requiredVersion = _parseVersion(minRequiredVersion);

      debugPrint("ConfigService: Checking force update for $currentPlatform");
      debugPrint("ConfigService: Current version: $currentAppVersion");
      debugPrint(
        "ConfigService: Required version ($currentPlatform): $minRequiredVersion",
      );

      // Compare versions: if current < required, update needed
      for (int i = 0; i < 3; i++) {
        if (currentVersion[i] < requiredVersion[i]) {
          debugPrint("ConfigService: Update required - current < required");
          return true;
        }
        if (currentVersion[i] > requiredVersion[i]) {
          debugPrint("ConfigService: No update needed - current > required");
          return false;
        }
      }
      debugPrint("ConfigService: No update needed - versions equal");
      return false; // Versions are equal
    } catch (e) {
      debugPrint("ConfigService: Failed to compare versions: $e");
      return false;
    }
  }

  /// Parse version string to list of integers [major, minor, patch]
  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  // ===========================================================================
  // MAINTENANCE CONFIG
  // ===========================================================================

  /// Get maintenance config based on APP_TYPE
  /// DEVELOPMENT: uses dev_maintenance
  /// PRODUCTION: uses prod_maintenance
  MaintenanceConfig get maintenanceConfig {
    if (isProduction) {
      return _prodMaintenance ?? MaintenanceConfig.disabled();
    }
    return _devMaintenance ?? MaintenanceConfig.disabled();
  }

  /// Get dev maintenance config directly
  MaintenanceConfig get devMaintenance {
    return _devMaintenance ?? MaintenanceConfig.disabled();
  }

  /// Get prod maintenance config directly
  MaintenanceConfig get prodMaintenance {
    return _prodMaintenance ?? MaintenanceConfig.disabled();
  }

  /// Check if app is under maintenance based on APP_TYPE
  bool get isUnderMaintenance {
    return maintenanceConfig.isEnabled;
  }

  /// Get maintenance title
  String get maintenanceTitle {
    return maintenanceConfig.title;
  }

  /// Get maintenance message
  String get maintenanceMessage {
    return maintenanceConfig.message;
  }

  /// Get estimated maintenance end time
  String? get maintenanceEndTime {
    return maintenanceConfig.estimatedEndTime;
  }

  /// Check if maintenance bypass is allowed
  bool get allowMaintenanceBypass {
    return maintenanceConfig.allowBypass;
  }

  // ===========================================================================
  // STORE LINKS (used for all app types)
  // ===========================================================================

  String? get appstoreLink {
    final link = _appstoreLink;
    if (link == null || link == 'null' || link.isEmpty) return null;
    return link;
  }

  String? get playstoreLink {
    final link = _playstoreLink;
    if (link == null || link == 'null' || link.isEmpty) return null;
    return link;
  }

  /// Get store link based on platform
  String? get storeLink {
    if (Platform.isAndroid) {
      return playstoreLink;
    } else if (Platform.isIOS) {
      return appstoreLink;
    }
    return null;
  }

  // ===========================================================================
  // ENVIRONMENT VARIABLES (from prod/dev config based on APP_TYPE)
  // ===========================================================================

  /// Database URL for the current environment.
  ///
  /// Remote Config supplies this, but the compile-time APP_TYPE is
  /// authoritative: if RC is empty (offline first run) or hands back the
  /// *other* environment's URL (stale config), we fall back to the
  /// canonical URL for this build so reads never land in the wrong RTDB.
  /// Legacy field. Realtime Database is gone; the value is still parsed from
  /// config for backwards compatibility with older records but nothing reads
  /// it, so no canonical fallback is applied.
  @Deprecated('Realtime Database has been migrated to Supabase Postgres')
  String get databaseUrl => currentEnvVariable.databaseUrl;

  /// General Cloud Functions base URL (kept name for compatibility).
  ///
  /// Same self-heal as [databaseUrl]: a production build must hit
  /// `/apiProd` (writes to the production RTDB) and a dev build must hit
  /// `/api` (staging). A stale RC pointing the wrong way would silently
  /// route subscription/trial writes into the other environment's
  /// database — so APP_TYPE wins when they disagree.
  String get stripeBackendUrl {
    final rc = currentEnvVariable.stripeBackendUrl;
    final canonical = isProduction ? _prodBackendUrl : _stagingBackendUrl;
    if (rc.isEmpty) return canonical;
    // The project ref in the URL is the environment. A config that names the
    // other project — stale on the device, or edited wrongly — is ignored in
    // favour of the canonical URL for this build's APP_TYPE.
    final rcIsProd = rc.contains(_prodProjectRef);
    final rcIsStaging = rc.contains(_stagingProjectRef);
    if ((rcIsProd || rcIsStaging) && rcIsProd != isProduction) {
      debugPrint(
        'ConfigService: stripeBackendUrl env mismatch (rc=$rc, '
        'APP_TYPE=$appType) → using canonical $canonical',
      );
      return canonical;
    }
    return rc;
  }

  /// Chat Agent base URL from current environment
  String get chatAgentBaseUrl {
    return currentEnvVariable.chatAgentBaseUrl;
  }

  /// YouTube channel URL backing the home-screen learn banner.
  /// Empty string means the banner stays hidden.
  String get youtubeChannelUrl {
    return currentEnvVariable.youtubeChannelUrl;
  }

  /// Facebook community group URL backing the settings-screen banner.
  /// Empty string means the banner stays hidden.
  String get facebookGroupUrl {
    return currentEnvVariable.facebookGroupUrl;
  }

  /// Debug mode from current environment
  bool get isDebugMode {
    return currentEnvVariable.debug;
  }

  // ===========================================================================
  // PROD/DEV VARIABLES (direct access)
  // ===========================================================================

  RemoteConfigVariable get prodVariable {
    return _prodVariable ?? RemoteConfigVariable.empty();
  }

  RemoteConfigVariable get devVariable {
    return _devVariable ?? RemoteConfigVariable.empty();
  }

  // ===========================================================================
  // LEGACY SUPPORT
  // ===========================================================================

  EnvironmentVariables get environmentVariables =>
      EnvironmentVariables(appType: appType, appVersion: appVersion);

  // ===========================================================================
  // REFRESH REMOTE CONFIG
  // ===========================================================================

  /// Refresh remote config values
  Future<void> refresh() async {
    try {
      await AppConfigStore().load(forceRefresh: true);
      _parseAppConfig();
      debugPrint("ConfigService: app config refreshed");
    } catch (e) {
      debugPrint("ConfigService: Failed to refresh app config: $e");
    }
  }
}
