import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/services/supabase_service.dart';
import '../../core/utils/image_compressor.dart';
import '../../globals.dart';

/// Storage and table access for the tradesman profile area.
///
/// The RTDB version spread this across `users/{uid}/…` sub-nodes — portfolio
/// images, videos, job videos, highlights, trade card, qualifications, extra
/// documents — plus Firebase Storage. Postgres gives each its own table
/// (`portfolio_media` keyed by `kind`, `trade_cards`, `trade_qualifications`,
/// `extra_documents`), and blobs live in the `user-documents` bucket.
///
/// Collected here so the 52 methods in TradesmanRegistrationRepository keep
/// their shapes and only their plumbing changes.
class TradesmanStore {
  /// Bucket for profile documents and portfolio media. Object keys keep the
  /// paths DatabasePaths already produces, so the Phase 8 copy from Firebase
  /// Storage is a straight key move.
  static const String bucket = 'user-documents';

  static const int _signedUrlSeconds = 60 * 60 * 24 * 365 * 10;

  String? get uid => SupabaseService().auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------

  /// Uploads an image with the same smart compression as before and returns a
  /// signed URL.
  ///
  /// The bucket is private, so a long-lived signed URL replaces Firebase's
  /// `getDownloadURL()`, which never expired.
  Future<String> uploadImage({
    required String localPath,
    required String storagePath,
    String? imageType,
    String? contentType,
  }) async {
    try {
      debugPrint('Uploading to: $storagePath');

      var file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'Image file does not exist: $localPath');
      }

      if (imageType != null) {
        final result = await ImageCompressor.compressIfNeeded(file, imageType);
        if (result != null) {
          file = result.file;
          if (result.wasCompressed) {
            debugPrint(
              'Compressed: ${result.originalSize} -> ${result.finalSize} bytes',
            );
          }
        }
      }

      await SupabaseService().client.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              // Re-uploading the same key (re-taking a document photo) must
              // replace the object rather than fail on a duplicate.
              upsert: true,
            ),
          );

      return signedUrl(storagePath);
    } catch (e) {
      if (e is CustomException) rethrow;
      debugPrint('Image upload failed: $e');
      throw CustomException(message: 'Failed to upload image: $e');
    }
  }

  Future<String> signedUrl(String path) => SupabaseService()
      .client
      .storage
      .from(bucket)
      .createSignedUrl(path, _signedUrlSeconds);

  /// Best-effort delete — a missing object must not fail the caller.
  Future<void> deleteObject(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await SupabaseService().client.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('TradesmanStore.deleteObject($path) failed: $e');
    }
  }

  /// Recursively removes everything under [prefix].
  ///
  /// Supabase Storage has no folder delete; `list` returns one level at a
  /// time, so this walks the tree the way `_deleteFolder(Reference)` did.
  Future<void> deleteTree(String prefix) async {
    try {
      final entries =
          await SupabaseService().client.storage.from(bucket).list(path: prefix);
      if (entries.isEmpty) return;

      final files = <String>[];
      for (final e in entries) {
        // A synthesised "folder" has no id.
        if (e.id == null) {
          await deleteTree('$prefix/${e.name}');
        } else {
          files.add('$prefix/${e.name}');
        }
      }
      if (files.isNotEmpty) {
        await SupabaseService().client.storage.from(bucket).remove(files);
      }
    } catch (e) {
      debugPrint('TradesmanStore.deleteTree($prefix) failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // profiles
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> readProfile(String userId,
      [String columns = '*']) async {
    try {
      final row = await SupabaseService()
          .client
          .from('profiles')
          .select(columns)
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('TradesmanStore.readProfile failed: $e');
      return null;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    await SupabaseService().client.from('profiles').update(row).eq('id', userId);
  }

  /// Live view of one profile column.
  Stream<dynamic> streamProfileField(String userId, String column) {
    return SupabaseService()
        .client
        .from('profiles')
        .stream(primaryKey: const ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : rows.first[column]);
  }

  // ---------------------------------------------------------------------------
  // Owned child tables
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> list(
    String table, {
    String? kind,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    final owner = uid;
    if (owner == null) return const [];
    try {
      var q = SupabaseService().client.from(table).select().eq('owner_id', owner);
      if (kind != null) q = q.eq('kind', kind);
      final rows = await q.order(orderBy, ascending: ascending);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('TradesmanStore.list($table) failed: $e');
      return const [];
    }
  }

  /// Live list. `kind` is filtered client-side because realtime `stream()`
  /// accepts a single `.eq()`, which is spent on `owner_id`.
  Stream<List<Map<String, dynamic>>> watch(String table, {String? kind}) {
    final owner = uid;
    if (owner == null) return Stream.value(const []);
    return SupabaseService()
        .client
        .from(table)
        .stream(primaryKey: const ['id'])
        .eq('owner_id', owner)
        .map((rows) {
      final list = List<Map<String, dynamic>>.from(rows);
      final filtered =
          kind == null ? list : list.where((r) => r['kind'] == kind).toList();
      filtered.sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
      return filtered;
    });
  }

  Future<Map<String, dynamic>?> insert(
      String table, Map<String, dynamic> row) async {
    final owner = uid;
    if (owner == null) return null;
    final result = await SupabaseService()
        .client
        .from(table)
        .insert({...row, 'owner_id': owner})
        .select()
        .maybeSingle();
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  Future<void> updateById(
      String table, String id, Map<String, dynamic> row) async {
    final owner = uid;
    if (owner == null || row.isEmpty) return;
    await SupabaseService()
        .client
        .from(table)
        .update(row)
        .eq('id', id)
        .eq('owner_id', owner);
  }

  Future<Map<String, dynamic>?> findById(String table, String id) async {
    final owner = uid;
    if (owner == null) return null;
    try {
      final row = await SupabaseService()
          .client
          .from(table)
          .select()
          .eq('id', id)
          .eq('owner_id', owner)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('TradesmanStore.findById($table, $id) failed: $e');
      return null;
    }
  }

  Future<void> deleteById(String table, String id) async {
    final owner = uid;
    if (owner == null) return;
    await SupabaseService()
        .client
        .from(table)
        .delete()
        .eq('id', id)
        .eq('owner_id', owner);
  }

  /// Single-row-per-user tables keyed by `owner_id` (trade_cards).
  Future<Map<String, dynamic>?> readOwned(String table) async {
    final owner = uid;
    if (owner == null) return null;
    try {
      final row = await SupabaseService()
          .client
          .from(table)
          .select()
          .eq('owner_id', owner)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('TradesmanStore.readOwned($table) failed: $e');
      return null;
    }
  }

  Future<void> upsertOwned(String table, Map<String, dynamic> row) async {
    final owner = uid;
    if (owner == null) return;
    await SupabaseService()
        .client
        .from(table)
        .upsert({...row, 'owner_id': owner}, onConflict: 'owner_id');
  }

  Future<void> deleteOwned(String table) async {
    final owner = uid;
    if (owner == null) return;
    await SupabaseService().client.from(table).delete().eq('owner_id', owner);
  }
}
