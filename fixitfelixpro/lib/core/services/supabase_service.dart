import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing the Supabase client.
///
/// Mirrors [DatabaseService]'s singleton shape so the two can run
/// side by side during the Firebase → Supabase migration.
///
/// Credentials come from the env file selected in `main.dart`:
/// - `config/staging/.env`    → fif-pro-development
/// - `config/production/.env` → fif-pro-production
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  bool _initialized = false;

  /// Initialize the Supabase client for the current environment.
  ///
  /// Safe to call when credentials are absent: it logs and no-ops rather
  /// than throwing, so a missing key can never white-screen the launch.
  Future<void> initialize() async {
    if (_initialized) return;

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

    if (url.isEmpty || publishableKey.isEmpty) {
      debugPrint(
        'SupabaseService: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY missing — skipping init',
      );
      return;
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: kDebugMode,
    );

    _initialized = true;
    debugPrint('SupabaseService: Initialized against $url');
  }

  /// The configured Supabase client.
  SupabaseClient get client => Supabase.instance.client;

  /// Convenience accessor for the Postgres query builder.
  SupabaseQueryBuilder from(String table) => client.from(table);

  /// Convenience accessor for auth.
  GoTrueClient get auth => client.auth;

  /// Convenience accessor for storage.
  SupabaseStorageClient get storage => client.storage;

  bool get isInitialized => _initialized;

  String get currentUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Round-trips a trivial query to prove connectivity, RLS and the anon
  /// key are all working. Used as the Phase 0 health check.
  Future<bool> healthCheck() async {
    if (!_initialized) return false;
    try {
      await client.from('profiles').select('id').limit(1);
      debugPrint('SupabaseService: health check OK');
      return true;
    } catch (e) {
      debugPrint('SupabaseService: health check FAILED — $e');
      return false;
    }
  }
}
