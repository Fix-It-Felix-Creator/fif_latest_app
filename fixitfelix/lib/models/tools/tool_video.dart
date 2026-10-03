import 'package:equatable/equatable.dart';

/// A single uploaded video in the Videos tool. Stored as RTDB
/// metadata at `/userTools/{uid}/videos/{videoId}` plus the binary at
/// Firebase Storage `users/{uid}/tools/videos/{videoId}/{filename}`.
class ToolVideo extends Equatable {
  const ToolVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.storagePath,
    required this.sizeBytes,
    required this.createdAt,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final String storagePath;
  final int sizeBytes;
  final DateTime createdAt;

  /// First-frame poster generated at upload time. Nullable so legacy
  /// uploads (before this field existed) still render — the list
  /// falls back to a play icon when this is missing.
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;

  Map<String, dynamic> toRtdb() => {
    'title': title,
    'description': description,
    'url': url,
    'storagePath': storagePath,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (thumbnailStoragePath != null)
      'thumbnailStoragePath': thumbnailStoragePath,
  };

  factory ToolVideo.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    return ToolVideo(
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
      thumbnailUrl: raw['thumbnailUrl']?.toString(),
      thumbnailStoragePath: raw['thumbnailStoragePath']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    url,
    storagePath,
    sizeBytes,
    createdAt,
    thumbnailUrl,
    thumbnailStoragePath,
  ];
}
