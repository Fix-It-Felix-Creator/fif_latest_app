import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache_service.dart';
import 'connectivity_service.dart';
import 'supabase_service.dart';

/// Reads the `app_config` table — the replacement for both Firebase Remote
/// Config and the RTDB `config/` node.
///
/// The table is publicly readable by design (it is client configuration), so
/// values are available before sign-in. Rows are cached in memory and in Hive
/// so a cold, offline launch still gets the last-known configuration rather
/// than falling back to hard-coded defaults.
class AppConfigStore {
  static final AppConfigStore _instance = AppConfigStore._internal();
  factory AppConfigStore() => _instance;
  AppConfigStore._internal();

  static const String _cacheKey = 'app_config_rows';

  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  final Map<String, dynamic> _memory = {};
  bool _loaded = false;

  final _changes = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits the whole config map whenever it changes.
  Stream<Map<String, dynamic>> get changes => _changes.stream;

  /// Loads every key. Safe to call repeatedly; the network read is skipped
  /// when a fresh in-memory copy already exists.
  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;

    // Seed from disk first so an offline launch has values immediately.
    if (_memory.isEmpty) {
      final cached = _cache.getJson(CacheBoxes.settings, _cacheKey);
      if (cached != null) _memory.addAll(cached);
    }

    if (!_connectivity.isConnected || !SupabaseService().isInitialized) {
      _loaded = _memory.isNotEmpty;
      return;
    }

    try {
      final rows = await SupabaseService()
          .client
          .from('app_config')
          .select('key, value');

      final next = <String, dynamic>{};
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        next[r['key'].toString()] = r['value'];
      }

      _memory
        ..clear()
        ..addAll(next);
      _loaded = true;
      await _cache.put(CacheBoxes.settings, _cacheKey, next);
      if (!_changes.isClosed) _changes.add(Map.of(_memory));
    } catch (e) {
      // Keep whatever we already have — a config fetch failure must never
      // block launch, matching the old Remote Config behaviour.
      debugPrint('AppConfigStore.load failed, using cached values: $e');
      _loaded = _memory.isNotEmpty;
    }
  }

  /// Live updates for one key. Emits the current value first.
  Stream<dynamic> watchKey(String key) async* {
    await load();
    yield _memory[key];
    yield* _changes.stream.map((m) => m[key]);
  }

  /// Raw value for [key], or null.
  dynamic value(String key) => _memory[key];

  /// Object-valued key as a map. Scalar keys are stored as `{"value": ...}`,
  /// so this returns null for those — use [scalar] instead.
  Map<String, dynamic>? map(String key) {
    final v = _memory[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Scalar key, unwrapping the `{"value": ...}` envelope the seed uses.
  String? scalar(String key) {
    final v = _memory[key];
    if (v is Map && v.containsKey('value')) return v['value']?.toString();
    if (v == null) return null;
    return v.toString();
  }

  bool boolean(String key, {bool orElse = false}) {
    final s = scalar(key)?.toLowerCase();
    if (s == null) return orElse;
    return s == 'true' || s == '1';
  }

  /// Drops the in-memory copy so the next [load] refetches.
  void clear() {
    _memory.clear();
    _loaded = false;
  }
}
