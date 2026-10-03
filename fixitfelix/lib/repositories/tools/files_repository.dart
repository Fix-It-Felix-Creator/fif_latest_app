import 'dart:io';

import '../../models/tools/tool_file.dart';
import '../base/owned_collection_repository.dart';
import 'tool_asset_store.dart';

/// Upload + live stream for the Files tool.
///
/// Was `/userTools/{uid}/files/{id}`; now `tool_assets` rows with
/// `kind = 'file'`. Public API unchanged.
class FilesRepository {
  final ToolAssetStore<ToolFile> _store = ToolAssetStore<ToolFile>(
    kind: 'file',
    idOfFn: (f) => f.id,
    compareFn: (a, b) => b.createdAt.compareTo(a.createdAt),
    toRowFn: (f) => {
      if (f.id.isNotEmpty) 'id': f.id,
      'title': f.title,
      'description': f.description,
      'url': f.url,
      'storage_path': f.storagePath,
      'file_name': f.fileName,
      'mime_type': f.mimeType,
      'size_bytes': f.sizeBytes,
    },
    fromRowFn: (row) => ToolFile(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      url: row['url']?.toString() ?? '',
      storagePath: row['storage_path']?.toString() ?? '',
      fileName: row['file_name']?.toString() ?? '',
      mimeType: row['mime_type']?.toString() ?? '',
      sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
    ),
  );

  Stream<List<ToolFile>> watchAll() => _store.watchAll();

  Future<ToolFile?> upload({
    required File file,
    required String title,
    required String description,
    required String fileName,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final owner = _store.uid;
    if (owner == null) return null;

    final id = OwnedCollectionRepository.newId();
    final path = _store.objectPath(owner, 'files', id, fileName);

    final up = await _store.uploadObject(
      file: file,
      storagePath: path,
      contentType: mimeType,
      onProgress: onProgress,
    );
    if (up == null) return null;

    final record = ToolFile(
      id: id,
      title: title,
      description: description,
      url: up.url,
      storagePath: up.path,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: up.size,
      createdAt: DateTime.now(),
    );

    if (await _store.create(record) == null) {
      await _store.removeObject(path);
      return null;
    }
    return record;
  }

  Future<bool> delete(ToolFile f) async {
    await _store.removeObject(f.storagePath);
    return _store.delete(f.id);
  }
}
