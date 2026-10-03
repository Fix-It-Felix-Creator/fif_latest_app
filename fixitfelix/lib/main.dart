import 'dart:async';

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
import 'fix_it_felix_app.dart';
import 'repositories/configurations/configurations_repositories.dart';
import 'services/app_config_service.dart';

/// Runs a startup initialization step under a hard timeout so a stalled
/// network call can NEVER block `runApp` and leave the app on a permanent
/// white screen.
///
/// A plain `try/catch` is not enough here: it rescues *errors*, not *hangs*.
/// Each service below already has safe in-memory defaults, so continuing past
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

/// Shown when the app cannot start at all.
///
/// The alternative is what this app was doing: throwing before `runApp` and
/// leaving a white screen. A white screen is the worst possible failure — it
/// is indistinguishable from a hang, from a crash, and from a slow network,
/// so nobody can tell you what went wrong. This says what broke.
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFF5900),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 44),
                const SizedBox(height: 14),
                const Text(
                  'Fix It Felix could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Unprotected before: either of these throwing meant `runApp` was never
  // reached and the app sat on a white screen with nothing in the log.
  await _bootStep('CacheService.initialize', () => CacheService().initialize(),
      timeout: const Duration(seconds: 8));
  await _bootStep('ConnectivityService.initialize',
      () => ConnectivityService().initialize(),
      timeout: const Duration(seconds: 8));

  // Firebase is not initialised here. The pro app needs it for push
  // notifications; this app has no Firebase project registered against
  // com.techkushx.fixitfelix yet, and initialising without a config file
  // throws on launch. Push comes back when that app is registered.

  // Env selection rules (highest priority first):
  //   1. Explicit --dart-define=ENV=staging|production always wins.
  //   2. Release builds: decided by BUILD NUMBER PARITY so one Archive flow
  //      can ship either variant —
  //         ODD  build number  → staging
  //         EVEN build number  → production
  //   3. Debug/profile builds: always staging.
  //
  // Safety: if the build number can't be parsed, fall back to STAGING — a
  // misconfigured prod build hitting staging fails safely; the reverse does
  // not.
  const explicitEnv = String.fromEnvironment('ENV');
  String buildEnv;
  if (explicitEnv.isNotEmpty) {
    buildEnv = explicitEnv;
  } else if (kReleaseMode) {
    int? buildNumber;
    try {
      final info = await PackageInfo.fromPlatform();
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
  // NOT wrapped in _bootStep, because this one is not survivable: without the
  // env file there is no Supabase URL and no key, so every screen would load
  // and then fail. Better to say so than to run a broken app — or, as before,
  // to throw here and show nothing at all.
  try {
    await dotenv.load(fileName: envFile);
    debugPrint(
        'Loaded env file: $envFile (ENV=$buildEnv, release=$kReleaseMode)');
  } catch (e) {
    debugPrint('FATAL: could not load $envFile: $e');
    runApp(_BootFailureApp(
      detail: 'The configuration file $envFile is missing from this build.\n\n'
          'Rebuild the app — a full "flutter clean" then rebuild — so the '
          'config/ assets are bundled again.',
    ));
    return;
  }

  final remoteConfigRepository = ConfigurationRepository();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ORDER MATTERS: ConfigService reads the `app_config` table, so the Supabase
  // client must exist first.
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
  OfflineSyncService().initialize();
  await _bootStep(
    'AppConfigService.initialize',
    () => AppConfigService().initialize(),
    timeout: const Duration(seconds: 10),
  );

  runApp(FixItFelixApp(remoteConfigRepository: remoteConfigRepository));
}
