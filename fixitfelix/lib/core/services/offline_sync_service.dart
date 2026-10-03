import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cache_service.dart';
import 'connectivity_service.dart';
import 'supabase_service.dart';

/// The kind of write a queued mutation represents.
enum SyncOp { insert, update, delete }

/// A single pending write, persisted so it survives an app restart.
@immutable
class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.table,
    required this.op,
    required this.rowId,
    required this.payload,
    required this.queuedAt,
    this.attempts = 0,
  });

  final String id;
  final String table;
  final SyncOp op;

  /// Primary key of the affected row. For inserts this is the client-generated
  /// UUID, which is why inserts are safe to replay — the id is decided before
  /// the row ever reaches the server.
  final String rowId;

  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  final int attempts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'op': op.name,
        'rowId': rowId,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> j) => PendingMutation(
        id: j['id'].toString(),
        table: j['table'].toString(),
        op: SyncOp.values.firstWhere(
          (e) => e.name == j['op'],
          orElse: () => SyncOp.update,
        ),
        rowId: j['rowId'].toString(),
        payload: Map<String, dynamic>.from(j['payload'] as Map? ?? const {}),
        queuedAt:
            DateTime.tryParse(j['queuedAt'].toString()) ?? DateTime.now(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );

  PendingMutation withAttempt() => PendingMutation(
        id: id,
        table: table,
        op: op,
        rowId: rowId,
        payload: payload,
        queuedAt: queuedAt,
        attempts: attempts + 1,
      );
}

/// Replacement for Realtime Database's offline persistence.
///
/// RTDB queued writes locally and replayed them on reconnect, entirely inside
/// the SDK. Supabase has no equivalent, so writes made while offline are
/// persisted here (Hive, via [CacheService]) and drained when connectivity
/// returns. The app already shipped a `sync_queue` box for this; it was never
/// wired up, because RTDB made it unnecessary.
///
/// Ordering is preserved per row: mutations drain oldest-first, so an insert
/// always lands before the update that follows it.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'pending_mutations';

  /// A mutation is abandoned after this many failed drains, so one poisoned
  /// row cannot block the queue forever.
  static const int _maxAttempts = 5;

  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  StreamSubscription<bool>? _connectivitySub;
  bool _draining = false;

  final _syncedController = StreamController<void>.broadcast();

  /// Emits after a drain that actually flushed something, so repositories can
  /// refresh their views.
  Stream<void> get onSynced => _syncedController.stream;

  void initialize() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.connectivityStream.listen((online) {
      if (online) {
        debugPrint('OfflineSync: back online — draining queue');
        unawaited(drain());
      }
    });
    // Anything left over from a previous session.
    unawaited(drain());
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ---------------------------------------------------------------------------
  // Queue storage
  // ---------------------------------------------------------------------------

  List<PendingMutation> get pending {
    final raw = _cache.get<String>(CacheBoxes.syncQueue, _queueKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingMutation.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('OfflineSync: queue unreadable, dropping — $e');
      return const [];
    }
  }

  int get pendingCount => pending.length;

  Future<void> _writeQueue(List<PendingMutation> items) async {
    await _cache.put(
      CacheBoxes.syncQueue,
      _queueKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enqueue(PendingMutation m) async {
    final items = [...pending, m];
    await _writeQueue(items);
    debugPrint(
      'OfflineSync: queued ${m.op.name} ${m.table}/${m.rowId} '
      '(${items.length} pending)',
    );
  }

  Future<void> clear() => _writeQueue(const []);

  // ---------------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------------

  /// Replays queued mutations oldest-first. Safe to call concurrently — a
  /// second call while draining is a no-op.
  Future<void> drain() async {
    if (_draining) return;
    if (!_connectivity.isConnected) return;
    if (!SupabaseService().isInitialized) return;

    final items = pending;
    if (items.isEmpty) return;

    _draining = true;
    var flushed = 0;
    final remaining = <PendingMutation>[];

    try {
      final client = SupabaseService().client;

      for (final m in items) {
        // Stop at the first failure and keep the rest queued: replaying a
        // later mutation before an earlier one could apply an update to a row
        // that does not exist yet.
        if (remaining.isNotEmpty) {
          remaining.add(m);
          continue;
        }

        try {
          switch (m.op) {
            case SyncOp.insert:
              // upsert, not insert: a drain that half-succeeded before losing
              // connection must not fail on the replay with a duplicate key.
              await client.from(m.table).upsert(m.payload);
            case SyncOp.update:
              await client.from(m.table).update(m.payload).eq('id', m.rowId);
            case SyncOp.delete:
              await client.from(m.table).delete().eq('id', m.rowId);
          }
          flushed++;
        } catch (e) {
          final next = m.withAttempt();
          if (next.attempts >= _maxAttempts) {
            debugPrint(
              'OfflineSync: dropping ${m.table}/${m.rowId} after '
              '${next.attempts} attempts — $e',
            );
            // Dropped rather than retried forever; the cache entry is left in
            // place so the user still sees their data locally.
          } else {
            debugPrint(
              'OfflineSync: ${m.table}/${m.rowId} failed '
              '(attempt ${next.attempts}) — $e',
            );
            remaining.add(next);
          }
        }
      }

      await _writeQueue(remaining);
      if (flushed > 0) {
        debugPrint('OfflineSync: flushed $flushed, ${remaining.length} left');
        if (!_syncedController.isClosed) _syncedController.add(null);
      }
    } finally {
      _draining = false;
    }
  }
}
