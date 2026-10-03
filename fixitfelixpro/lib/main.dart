import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/config/config_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';
import 'fix_it_felix_app.dart';
import 'repositories/configurations/configurations_repositories.dart';
import 'services/app_config_service.dart';
import 'services/iap_service.dart';
import 'services/push_notifications_service.dart' show firebaseMessagingBackgroundHandler;

/// Runs a startup initialization step under a hard timeout so a stalled
/// network call (an RTDB `.get()` that never returns, a Remote Config fetch
/// blocked by App Check on a side-loaded build, or plain bad connectivity)
/// can NEVER block `runApp` and leave the app on a permanent white screen.
///
/// A plain `try/catch` is not enough here: it rescues *errors*, not *hangs*.
/// Each service below already has safe in-memory defaults (canonical env
/// URLs, `AppConfigModel.empty`, cached Remote Config), and the relevant
/// screens refresh their data once connectivity returns — so continuing past
/// a timed-out step degrades gracefully instead of freezing the launch.
Future<void> _bootStep(
  String name,
  Future<void> Function() step, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    await step().timeout(timeout);
  } on TimeoutException {
    debugPrint(
      'Boot step "$name" timed out after ${timeout.inSeconds}s — '
      'continuing with defaults.',
    );
  } catch (e) {
    debugPrint('Boot step "$name" failed: $e — continuing with defaults.');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CacheService().initialize();
  await ConnectivityService().initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Env selection rules (highest priority first):
  //   1. Explicit --dart-define=ENV=staging|production always wins
  //      (local debugging against either backend).
  //   2. Release builds: decided by BUILD NUMBER PARITY so the same
  //      Archive flow can ship either variant to TestFlight —
  //         ODD  build number  → staging   (dev TestFlight)
  //         EVEN build number  → production (prod TestFlight)
  //      e.g. 1.0.3+5 → staging, 1.0.3+6 → production.
  //   3. Debug/profile builds: always staging (fast local dev).
  //
  // Safety: if the build number can't be parsed, fall back to STAGING
  // — a misconfigured prod build hitting the staging backend just fails
  // safely, which is preferable to the reverse. Staging is the safer
  // ambiguous default.
  const explicitEnv = String.fromEnvironment('ENV');
  String buildEnv;
  if (explicitEnv.isNotEmpty) {
    buildEnv = explicitEnv;
  } else if (kReleaseMode) {
    int? buildNumber;
    try {
      final info = await PackageInfo.fromPlatform();
      // CFBundleVersion / versionCode — take leading integer only
      // (handles "6", "6.1", "1.0.3" gracefully).
      final match = RegExp(r'\d+').firstMatch(info.buildNumber);
      buildNumber = match != null ? int.tryParse(match.group(0)!) : null;
    } catch (_) {
      buildNumber = null;
    }
    buildEnv = (buildNumber != null && buildNumber.isEven)
        ? 'production'
        : 'staging';
    debugPrint(
      'Env by build-number parity: buildNumber=$buildNumber → $buildEnv',
    );
  } else {
    buildEnv = 'staging';
  }
  final envFile = buildEnv == 'production'
      ? 'config/production/.env'
      : 'config/staging/.env';
  await dotenv.load(fileName: envFile);
  debugPrint('Loaded env file: $envFile (ENV=$buildEnv, release=$kReleaseMode)');

  final remoteConfigRepository = ConfigurationRepository();

  // App Check removed with the Firebase backends it protected.
  //
  // It attested callers to Realtime Database, Storage and Remote Config —
  // all now Supabase, which App Check cannot gate. Supabase's equivalents are
  // RLS (every table is owner-scoped and verified) plus rate limiting on the
  // Edge Functions; abuse protection therefore moved from "is this a genuine
  // app build" to "is this caller authorised for this row", which is the
  // stronger guarantee for data access.
  //
  // What is genuinely lost: anonymous-endpoint abuse protection on the public
  // share routes, which have no authenticated caller to scope. Phase 5 should
  // put rate limiting in front of those.

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ORDER MATTERS: ConfigService now reads the `app_config` table, so the
  // Supabase client must exist first. AppConfigStore silently no-ops when it
  // is not initialised, which would leave maintenance mode and force-update
  // permanently on their built-in defaults.
  await _bootStep(
    'SupabaseService.initialize',
    () => SupabaseService().initialize(),
    timeout: const Duration(seconds: 8),
  );
  await _bootStep(
    'ConfigService.initialize',
    () => ConfigService().initialize(),
    timeout: const Duration(seconds: 12),
  );
  // Replaces Realtime Database's offline persistence: replays writes that
  // were queued while offline as soon as connectivity returns. Must run
  // after SupabaseService so the drain has a client to write through.
  OfflineSyncService().initialize();
  // Reads app_config; kept behind the same timeout guard as before so a slow
  // config fetch can never block launch.
  await _bootStep(
    'AppConfigService.initialize',
    () => AppConfigService().initialize(),
    timeout: const Duration(seconds: 10),
  );

  // In-App Purchase: wire the global purchase stream early so past /
  // interrupted StoreKit transactions are re-delivered, verified and
  // finished on launch (restores entitlement after a reinstall).
  await _bootStep(
    'IapService.initialize',
    () => IapService().initialize(),
    timeout: const Duration(seconds: 10),
  );

  // FCM: background isolate handler must be registered BEFORE runApp.
  // The rest of push init (permission prompt, token fetch, listeners)
  // is deferred until the user reaches the home screen.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(FixItFelixApp(remoteConfigRepository: remoteConfigRepository));
}
