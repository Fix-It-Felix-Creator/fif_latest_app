import 'package:equatable/equatable.dart';

/// A single uploaded photo in the Photos tool. Stored as RTDB
/// metadata at `/userTools/{uid}/photos/{photoId}` plus the binary
/// blob in Firebase Storage at `users/{uid}/tools/photos/{photoId}/{filename}`.
class ToolPhoto extends Equatable {
  const ToolPhoto({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.storagePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;

  /// Public download URL — what the viewer renders.
  final String url;

  /// Storage path so we can delete the blob when the user removes
  /// the photo. Without this, deleting the RTDB row would leak the
  /// underlying file.
  final String storagePath;

  final int sizeBytes;
  final DateTime createdAt;

  Map<String, dynamic> toRtdb() => {
    'title': title,
    'description': description,
    'url': url,
    'storagePath': storagePath,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ToolPhoto.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    return ToolPhoto(
      id: id,
      title: raw['title']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      url: raw['url']?.toString() ?? '',
      storagePath: raw['storagePath']?.toString() ?? '',
      sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, description, url, storagePath, sizeBytes, createdAt];
}
