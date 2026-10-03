import 'package:equatable/equatable.dart';

/// Types of portfolio media
enum PortfolioMediaType { image, video, jobVideo }

/// Model representing a portfolio media item (image or video)
class PortfolioMediaModel extends Equatable {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final PortfolioMediaType type;
  final String? title;
  final String? description;
  final String? jobId; // For job videos
  final String? jobTitle; // For job videos
  final int fileSize; // in bytes
  final int? durationSeconds; // For videos
  final DateTime createdAt;
  final DateTime updatedAt;

  const PortfolioMediaModel({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.type,
    this.title,
    this.description,
    this.jobId,
    this.jobTitle,
    required this.fileSize,
    this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => type == PortfolioMediaType.image;
  bool get isVideo => type == PortfolioMediaType.video;
  bool get isJobVideo => type == PortfolioMediaType.jobVideo;

  /// Get human readable file size
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get formatted duration for videos
  String get formattedDuration {
    if (durationSeconds == null) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  PortfolioMediaModel copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    PortfolioMediaType? type,
    String? title,
    String? description,
    String? jobId,
    String? jobTitle,
    int? fileSize,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PortfolioMediaModel(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      fileSize: fileSize ?? this.fileSize,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'type': type.name,
      'title': title,
      'description': description,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'fileSize': fileSize,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PortfolioMediaModel.fromJson(Map<String, dynamic> json) {
    return PortfolioMediaModel(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      type: PortfolioMediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PortfolioMediaType.image,
      ),
      title: json['title'] as String?,
      description: json['description'] as String?,
      jobId: json['jobId'] as String?,
      jobTitle: json['jobTitle'] as String?,
      fileSize: json['fileSize'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    url,
    thumbnailUrl,
    type,
    title,
    description,
    jobId,
    jobTitle,
    fileSize,
    durationSeconds,
    createdAt,
    updatedAt,
  ];
}

/// Model representing a portfolio highlight (Instagram-style story highlight)
class PortfolioHighlightModel extends Equatable {
  final String id;
  final String title;
  final String? coverUrl;
  final String? mediaUrl;
  final bool isVideo;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PortfolioHighlightModel({
    required this.id,
    required this.title,
    this.coverUrl,
    this.mediaUrl,
    this.isVideo = false,
    this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get formatted duration for video highlights
  String get formattedDuration {
    if (durationSeconds == null) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  PortfolioHighlightModel copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? mediaUrl,
    bool? isVideo,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PortfolioHighlightModel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isVideo: isVideo ?? this.isVideo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'mediaUrl': mediaUrl,
      'isVideo': isVideo,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PortfolioHighlightModel.fromJson(Map<String, dynamic> json) {
    return PortfolioHighlightModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      coverUrl: json['coverUrl'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      isVideo: json['isVideo'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    coverUrl,
    mediaUrl,
    isVideo,
    durationSeconds,
    createdAt,
    updatedAt,
  ];
}
