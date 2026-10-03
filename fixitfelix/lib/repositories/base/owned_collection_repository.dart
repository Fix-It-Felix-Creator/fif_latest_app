import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/services/cache_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/supabase_service.dart';

/// Shared behaviour for the owner-scoped collections that used to live under
/// `/{collection}/{uid}/{id}` in Realtime Database.
///
/// Every one of those tables is `id` + `owner_id` + payload with
/// `auth.uid() = owner_id` RLS, so the CRUD and streaming logic is identical
/// across ~15 repositories. Subclasses supply the table name, the row
/// mapping and the sort order.
///
/// Offline behaviour is reproduced deliberately. RTDB persisted writes and
/// replayed them on reconnect inside the SDK; here, reads fall back to the
/// Hive cache and writes are queued through [OfflineSyncService], with the
/// cache updated optimistically so the UI looks the same either way.
abstract class OwnedCollectionRepository<T> {
  /// Postgres table backing this collection.
  String get table;

  /// Hive box used for the offline copy.
  String get cacheBox;

  /// Columns to select. Override when child rows need embedding.
  String get selectColumns => '*';

  Map<String, dynamic> toRow(T item);
  T fromRow(Map<String, dynamic> row);
  String idOf(T item);

  /// Sort applied to every emission, matching what the RTDB repository did
  /// client-side after reading the whole node.
  int compare(T a, T b);

  /// Optional secondary filter.
  ///
  /// Supabase's realtime `stream()` accepts a single `.eq()`, which is spent
  /// on `owner_id`. Collections that shared one table in Postgres but were
  /// separate nodes in RTDB — `tool_assets`, where `kind` splits notes from
  /// photos, videos and files — narrow the rows here instead.
  bool includeRow(Map<String, dynamic> row) => true;

  final CacheService cache = CacheService();
  final ConnectivityService connectivity = ConnectivityService();
  final OfflineSyncService sync = OfflineSyncService();

  /// Table names whose local cache has just been mutated.
  ///
  /// An optimistic write updates the Hive cache, but an already-open
  /// [watchAll] stream only reads that cache once, when it is first listened
  /// to — so without this the UI kept showing a row the user had just
  /// deleted until realtime confirmed it, or the app restarted.
  ///
  /// Realtime cannot be the only path here. A queued offline mutation never
  /// reaches the server at all, and a delete only arrives once the database
  /// is on `replica identity full` (see the 20260824 migration). Emitting
  /// locally keeps the list correct in both cases, and makes every write feel
  /// immediate rather than waiting on a server round trip.
  ///
  /// Broadcast and static: one bus shared by every repository instance, since
  /// two instances of the same repository must not diverge.
  static final StreamController<String> _localChanges =
      StreamController<String>.broadcast();

  String? get uid => SupabaseService().auth.currentUser?.id;

  String get _cacheKey => 'rows_${table}_${uid ?? 'anon'}';

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Live list of the signed-in user's rows.
  ///
  /// Emits the cached copy first so the UI paints immediately (and works
  /// offline), then switches to the realtime feed.
  Stream<List<T>> watchAll() {
    final owner = uid;
    if (owner == null) return Stream.value(const []);

    final controller = StreamController<List<T>>();
    StreamSubscription<List<Map<String, dynamic>>>? sub;
    StreamSubscription<String>? localSub;

    controller.onListen = () {
      final cached = _readCache();
      if (cached.isNotEmpty) controller.add(cached);

      // Re-emit whenever this table's cache is mutated locally, so an
      // optimistic create/update/delete shows up without waiting for the
      // server to echo it back.
      localSub = _localChanges.stream.where((t) => t == table).listen((_) {
        if (!controller.isClosed) controller.add(_readCache());
      });

      sub = SupabaseService()
          .client
          .from(table)
          .stream(primaryKey: const ['id'])
          .eq('owner_id', owner)
          .listen(
        (rows) {
          final items = _decode(rows);
          unawaited(_writeCache(rows));
          if (!controller.isClosed) controller.add(items);
        },
        onError: (Object e) {
          // Never break the stream: a dropped connection should leave the UI
          // showing cached data, exactly as RTDB did.
          debugPrint('$runtimeType.watchAll stream error: $e');
          if (!controller.isClosed) controller.add(_readCache());
        },
      );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      await localSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// One-shot fetch, cache-first when offline.
  Future<List<T>> fetchAll() async {
    final owner = uid;
    if (owner == null) return const [];

    if (!connectivity.isConnected) return _readCache();

    try {
      final rows = await SupabaseService()
          .client
          .from(table)
          .select(selectColumns)
          .eq('owner_id', owner);
      final list = List<Map<String, dynamic>>.from(rows)
          .where(includeRow)
          .toList();
      await _writeCache(list);
      return _decode(list);
    } catch (e) {
      debugPrint('$runtimeType.fetchAll failed, using cache: $e');
      return _readCache();
    }
  }

  Future<T?> findById(String id) async {
    final owner = uid;
    if (owner == null) return null;
    try {
      final row = await SupabaseService()
          .client
          .from(table)
          .select(selectColumns)
          .eq('id', id)
          .eq('owner_id', owner)
          .maybeSingle();
      return row == null ? null : fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('$runtimeType.findById failed: $e');
      for (final item in _readCache()) {
        if (idOf(item) == id) return item;
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a row and returns its id, or null when there is no signed-in user.
  ///
  /// The id is generated on the client so an offline insert already has its
  /// final primary key — which is what makes the queued mutation safe to
  /// replay, and lets the UI navigate to the new record straight away.
  Future<String?> create(T item) async {
    final owner = uid;
    if (owner == null) return null;

    final row = toRow(item);
    final id = (row['id']?.toString().isNotEmpty ?? false)
        ? row['id'].toString()
        : newId();
    row['id'] = id;
    row['owner_id'] = owner;

    await _upsertCacheRow(row);

    if (!connectivity.isConnected) {
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.insert,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return id;
    }

    try {
      await SupabaseService().client.from(table).insert(row);
      return id;
    } catch (e) {
      debugPrint('$runtimeType.create failed, queuing: $e');
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.insert,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return id;
    }
  }

  Future<bool> update(T item) async {
    final owner = uid;
    if (owner == null) return false;

    final id = idOf(item);
    final row = toRow(item)
      ..remove('id')
      ..remove('owner_id')
      // created_at is immutable; updated_at is maintained by a trigger.
      ..remove('created_at')
      ..remove('updated_at');

    await _upsertCacheRow({...row, 'id': id, 'owner_id': owner});

    if (!connectivity.isConnected) {
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.update,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return true;
    }

    try {
      await SupabaseService().client.from(table).update(row).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('$runtimeType.update failed, queuing: $e');
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.update,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return true;
    }
  }

  /// Partial column update.
  ///
  /// Some collections (todos, journal entries) expose per-field setters rather
  /// than whole-object saves, and need explicit nulls to *clear* a column —
  /// which a whole-row write cannot express without nulling everything else.
  Future<bool> patch(String id, Map<String, dynamic> columns) async {
    final owner = uid;
    if (owner == null) return false;
    if (columns.isEmpty) return true;

    final row = Map<String, dynamic>.from(columns)
      ..remove('id')
      ..remove('owner_id')
      ..remove('created_at')
      ..remove('updated_at');

    await _upsertCacheRow({...row, 'id': id, 'owner_id': owner});

    if (!connectivity.isConnected) {
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.update,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return true;
    }

    try {
      await SupabaseService().client.from(table).update(row).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('$runtimeType.patch failed, queuing: $e');
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.update,
        rowId: id,
        payload: row,
        queuedAt: DateTime.now(),
      ));
      return true;
    }
  }

  Future<bool> delete(String id) async {
    final owner = uid;
    if (owner == null) return false;

    await _removeCacheRow(id);

    if (!connectivity.isConnected) {
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.delete,
        rowId: id,
        payload: const {},
        queuedAt: DateTime.now(),
      ));
      return true;
    }

    try {
      await SupabaseService().client.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('$runtimeType.delete failed, queuing: $e');
      await sync.enqueue(PendingMutation(
        id: newId(),
        table: table,
        op: SyncOp.delete,
        rowId: id,
        payload: const {},
        queuedAt: DateTime.now(),
      ));
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Cache plumbing
  // ---------------------------------------------------------------------------

  List<T> _decode(List<Map<String, dynamic>> rows) {
    final out = <T>[];
    for (final r in rows) {
      if (!includeRow(r)) continue;
      try {
        out.add(fromRow(r));
      } catch (e) {
        // One malformed row must not blank the whole list.
        debugPrint('$runtimeType: skipping unreadable row ${r['id']}: $e');
      }
    }
    out.sort(compare);
    return out;
  }

  List<T> _readCache() => _decode(cache.getJsonList(cacheBox, _cacheKey));

  Future<void> _writeCache(List<Map<String, dynamic>> rows) =>
      cache.put(cacheBox, _cacheKey, rows);

  /// Tell any open [watchAll] stream on this table to re-read the cache.
  ///
  /// Only the local-mutation helpers below call this. `_writeCache` must not:
  /// the realtime listener writes the cache on every server emission, and
  /// notifying from there would make each server update produce a second,
  /// redundant emission.
  void _notifyLocalChange() {
    if (!_localChanges.isClosed) _localChanges.add(table);
  }

  Future<void> _upsertCacheRow(Map<String, dynamic> row) async {
    final rows = cache.getJsonList(cacheBox, _cacheKey).toList();
    final i = rows.indexWhere((r) => r['id'] == row['id']);
    if (i >= 0) {
      rows[i] = {...rows[i], ...row};
    } else {
      rows.add(row);
    }
    await _writeCache(rows);
    _notifyLocalChange();
  }

  Future<void> _removeCacheRow(String id) async {
    final rows = cache.getJsonList(cacheBox, _cacheKey).toList()
      ..removeWhere((r) => r['id'] == id);
    await _writeCache(rows);
    _notifyLocalChange();
  }

  /// RFC 4122 v4 UUID. Postgres generates these server-side, but an offline
  /// insert needs its key before it can reach the server.
  static String newId() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String hex(int start, int end) => b
        .sublist(start, end)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Helper for nullable timestamps coming back from Postgres.
  static DateTime? parseTs(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static DateTime parseTsOr(Object? v, DateTime fallback) =>
      parseTs(v) ?? fallback;
}
