import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/tools/tool_video.dart';
import '../base/owned_collection_repository.dart';
import 'tool_asset_store.dart';

/// Upload + live stream for the Videos tool.
///
/// Was `/userTools/{uid}/videos/{id}`; now `tool_assets` rows with
/// `kind = 'video'`. Public API unchanged.
class VideosRepository {
  final ToolAssetStore<ToolVideo> _store = ToolAssetStore<ToolVideo>(
    kind: 'video',
    idOfFn: (v) => v.id,
    compareFn: (a, b) => b.createdAt.compareTo(a.createdAt),
    toRowFn: (v) => {
      if (v.id.isNotEmpty) 'id': v.id,
      'title': v.title,
      'description': v.description,
      'url': v.url,
      'storage_path': v.storagePath,
      'size_bytes': v.sizeBytes,
      'thumbnail_url': v.thumbnailUrl,
      'thumbnail_storage_path': v.thumbnailStoragePath,
    },
    fromRowFn: (row) => ToolVideo(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      url: row['url']?.toString() ?? '',
      storagePath: row['storage_path']?.toString() ?? '',
      sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      thumbnailStoragePath: row['thumbnail_storage_path']?.toString(),
    ),
  );

  Stream<List<ToolVideo>> watchAll() => _store.watchAll();

  Future<ToolVideo?> upload({
    required File file,
    required String title,
    required String description,
    void Function(double progress)? onProgress,
  }) async {
    final owner = _store.uid;
    if (owner == null) return null;

    final id = OwnedCollectionRepository.newId();
    final fileName = file.path.split('/').last;
    final path = _store.objectPath(owner, 'videos', id, fileName);
    String? thumbPath;

    // Upload the video first — bandwidth-heaviest step. The thumb is
    // best-effort: extraction or upload failure still keeps the video, the
    // list just falls back to the play-icon tile.
    final up = await _store.uploadObject(
      file: file,
      storagePath: path,
      onProgress: onProgress,
    );
    if (up == null) return null;

    String? thumbUrl;
    try {
      final thumbFile = await _extractThumbnail(file);
      if (thumbFile != null) {
        thumbPath = _store.objectPath(owner, 'videos', id, 'thumb.jpg');
        final thumbUp = await _store.uploadObject(
          file: thumbFile,
          storagePath: thumbPath,
          contentType: 'image/jpeg',
        );
        thumbUrl = thumbUp?.url;
        if (thumbUp == null) thumbPath = null;
      }
    } catch (e) {
      debugPrint('VideosRepository.upload: thumbnail step failed: $e');
      thumbPath = null;
    }

    final record = ToolVideo(
      id: id,
      title: title,
      description: description,
      url: up.url,
      storagePath: up.path,
      sizeBytes: up.size,
      createdAt: DateTime.now(),
      thumbnailUrl: thumbUrl,
      thumbnailStoragePath: thumbPath,
    );

    if (await _store.create(record) == null) {
      // Cleanup partial uploads so we don't leak Storage blobs.
      await _store.removeObject(path);
      await _store.removeObject(thumbPath);
      return null;
    }
    return record;
  }

  Future<bool> delete(ToolVideo video) async {
    await _store.removeObject(video.storagePath);
    await _store.removeObject(video.thumbnailStoragePath);
    return _store.delete(video.id);
  }

  /// Extract the first frame as a temp JPEG. Returns null on failure.
  /// Capped at 720px wide — list rows render small, no point paying the
  /// bandwidth for a 4K poster.
  Future<File?> _extractThumbnail(File source) async {
    try {
      final dir = await getTemporaryDirectory();
      final outPath = await VideoThumbnail.thumbnailFile(
        video: source.path,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
      );
      if (outPath == null) return null;
      final f = File(outPath);
      if (!await f.exists()) return null;
      return f;
    } catch (e) {
      debugPrint('VideosRepository._extractThumbnail failed: $e');
      return null;
    }
  }
}
