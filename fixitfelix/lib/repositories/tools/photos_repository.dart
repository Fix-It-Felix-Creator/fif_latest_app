import 'dart:io';

import '../../models/tools/tool_photo.dart';
import '../base/owned_collection_repository.dart';
import 'tool_asset_store.dart';

/// Upload + live stream for the Photos tool.
///
/// Was `/userTools/{uid}/photos/{id}`; now `tool_assets` rows with
/// `kind = 'photo'` and blobs in the `user-tools` bucket. Public API unchanged.
class PhotosRepository {
  final ToolAssetStore<ToolPhoto> _store = ToolAssetStore<ToolPhoto>(
    kind: 'photo',
    idOfFn: (p) => p.id,
    compareFn: (a, b) => b.createdAt.compareTo(a.createdAt),
    toRowFn: (p) => {
      if (p.id.isNotEmpty) 'id': p.id,
      'title': p.title,
      'description': p.description,
      'url': p.url,
      'storage_path': p.storagePath,
      'size_bytes': p.sizeBytes,
    },
    fromRowFn: (row) => ToolPhoto(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      url: row['url']?.toString() ?? '',
      storagePath: row['storage_path']?.toString() ?? '',
      sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
    ),
  );

  Stream<List<ToolPhoto>> watchAll() => _store.watchAll();

  Future<ToolPhoto?> upload({
    required File file,
    required String title,
    required String description,
    void Function(double progress)? onProgress,
  }) async {
    final owner = _store.uid;
    if (owner == null) return null;

    final id = OwnedCollectionRepository.newId();
    final fileName = file.path.split('/').last;
    final path = _store.objectPath(owner, 'photos', id, fileName);

    final up = await _store.uploadObject(
      file: file,
      storagePath: path,
      onProgress: onProgress,
    );
    if (up == null) return null;

    final record = ToolPhoto(
      id: id,
      title: title,
      description: description,
      url: up.url,
      storagePath: up.path,
      sizeBytes: up.size,
      createdAt: DateTime.now(),
    );

    if (await _store.create(record) == null) {
      // Metadata write failed — drop the blob so orphans don't pile up.
      await _store.removeObject(path);
      return null;
    }
    return record;
  }

  Future<bool> updateMeta({
    required String id,
    required String title,
    required String description,
  }) =>
      _store.patch(id, {'title': title, 'description': description});

  Future<bool> delete(ToolPhoto photo) async {
    // Storage first: if the row goes but the blob survives, nothing
    // references it any more and it leaks. This order lets a retry finish.
    await _store.removeObject(photo.storagePath);
    return _store.delete(photo.id);
  }
}
