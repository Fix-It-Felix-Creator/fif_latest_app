import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/services/cache_service.dart';
import '../../core/services/supabase_service.dart';
import '../base/owned_collection_repository.dart';

/// Shared storage + row mapping for the four Tools collections.
///
/// RTDB kept these as sibling nodes — `userTools/{uid}/{notes|photos|videos|
/// files}` — but the schema unifies them in `tool_assets`, split by `kind`.
///
/// Composed rather than inherited: the four repositories expose APIs like
/// `delete(ToolPhoto)` and `create({title, body})` that would collide with the
/// base class's `delete(String)` / `create(T)`. Holding a store instead of
/// extending one keeps every caller unchanged.
class ToolAssetStore<T> extends OwnedCollectionRepository<T> {
  ToolAssetStore({
    required this.kind,
    required Map<String, dynamic> Function(T) toRowFn,
    required T Function(Map<String, dynamic>) fromRowFn,
    required String Function(T) idOfFn,
    required int Function(T, T) compareFn,
  })  : _toRow = toRowFn,
        _fromRow = fromRowFn,
        _idOf = idOfFn,
        _compare = compareFn;

  /// Bucket holding every Tools upload.
  static const String bucket = 'user-tools';

  /// Value of the `kind` column for this collection.
  final String kind;

  final Map<String, dynamic> Function(T) _toRow;
  final T Function(Map<String, dynamic>) _fromRow;
  final String Function(T) _idOf;
  final int Function(T, T) _compare;

  @override
  String get table => 'tool_assets';

  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  bool includeRow(Map<String, dynamic> row) => row['kind'] == kind;

  @override
  Map<String, dynamic> toRow(T item) => {..._toRow(item), 'kind': kind};

  @override
  T fromRow(Map<String, dynamic> row) => _fromRow(row);

  @override
  String idOf(T item) => _idOf(item);

  @override
  int compare(T a, T b) => _compare(a, b);

  /// Uploads a file and returns its object key, signed URL and size.
  ///
  /// NOTE: Firebase's `putFile` exposed a byte-progress stream; the Supabase
  /// Dart client has no equivalent. [onProgress] is therefore called once at 0
  /// and once at 1 rather than continuously — the upload still works, but a
  /// determinate progress bar jumps rather than fills. Flagged rather than
  /// silently dropped, since three screens pass a callback.
  Future<({String url, String path, int size})?> uploadObject({
    required File file,
    required String storagePath,
    String? contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0);
      final size = await file.length();

      await SupabaseService().client.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType),
          );

      final url = await signedUrl(storagePath);
      onProgress?.call(1);
      return (url: url, path: storagePath, size: size);
    } catch (e) {
      debugPrint('ToolAssetStore($kind).uploadObject failed: $e');
      await removeObject(storagePath);
      return null;
    }
  }

  /// The bucket is private, so a signed URL replaces `getDownloadURL()`.
  /// Ten years keeps the stored value stable for the life of the record,
  /// matching Firebase download URLs, which never expired.
  Future<String> signedUrl(String path) => SupabaseService()
      .client
      .storage
      .from(bucket)
      .createSignedUrl(path, 60 * 60 * 24 * 365 * 10);

  /// Best-effort object removal — a missing blob must not fail the caller.
  Future<void> removeObject(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await SupabaseService().client.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('ToolAssetStore($kind).removeObject($path) failed: $e');
    }
  }

  /// Object key for an asset, preserving the paths the app already builds so
  /// the Phase 8 copy from Firebase Storage is a straight key move.
  String objectPath(String owner, String folder, String id, String fileName) =>
      'users/$owner/tools/$folder/$id/$fileName';
}
