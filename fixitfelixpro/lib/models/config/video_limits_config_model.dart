import 'package:equatable/equatable.dart';

/// Individual video type limit
class VideoTypeLimit extends Equatable {
  /// Maximum duration in seconds
  final int maxDurationSeconds;

  /// Maximum file size in bytes
  final int maxSizeBytes;

  /// Maximum file size in MB (for display)
  final double maxSizeMB;

  const VideoTypeLimit({
    this.maxDurationSeconds = 30,
    this.maxSizeBytes = 20971520, // 20MB default
    this.maxSizeMB = 20,
  });

  /// Check if a file size is within the limit
  bool isFileSizeWithinLimit(int fileSize) => fileSize <= maxSizeBytes;

  /// Check if a duration is within the limit
  bool isDurationWithinLimit(int durationSeconds) =>
      durationSeconds <= maxDurationSeconds;

  /// Get formatted size string (e.g., "20 MB")
  String get formattedMaxSize =>
      '${maxSizeMB.toStringAsFixed(maxSizeMB == maxSizeMB.roundToDouble() ? 0 : 1)} MB';

  /// Get formatted duration string (e.g., "30 seconds")
  String get formattedMaxDuration => '$maxDurationSeconds seconds';

  Map<String, dynamic> toJson() {
    return {
      'maxDurationSeconds': maxDurationSeconds,
      'maxSizeBytes': maxSizeBytes,
      'maxSizeMB': maxSizeMB,
    };
  }

  factory VideoTypeLimit.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VideoTypeLimit();
    return VideoTypeLimit(
      maxDurationSeconds: json['maxDurationSeconds'] ?? 30,
      maxSizeBytes: json['maxSizeBytes'] ?? 20971520,
      maxSizeMB: (json['maxSizeMB'] ?? 20).toDouble(),
    );
  }

  @override
  List<Object?> get props => [maxDurationSeconds, maxSizeBytes, maxSizeMB];
}

/// Video limits configuration model
/// Contains file size and duration limits for different video types
class VideoLimitsConfigModel extends Equatable {
  /// Limits for job video uploads
  final VideoTypeLimit jobVideo;

  /// Limits for portfolio video uploads
  final VideoTypeLimit portfolioVideo;

  /// Last updated timestamp
  final DateTime? updatedAt;

  /// User who last updated the limits
  final String? updatedBy;

  const VideoLimitsConfigModel({
    this.jobVideo = const VideoTypeLimit(),
    this.portfolioVideo = const VideoTypeLimit(
      maxSizeBytes: 15728640,
      maxSizeMB: 15,
    ),
    this.updatedAt,
    this.updatedBy,
  });

  /// Get limit by video type name
  VideoTypeLimit getLimitByType(String type) {
    switch (type.toLowerCase()) {
      case 'jobvideo':
      case 'job_video':
      case 'job':
        return jobVideo;
      case 'portfoliovideo':
      case 'portfolio_video':
      case 'portfolio':
        return portfolioVideo;
      default:
        return const VideoTypeLimit();
    }
  }

  VideoLimitsConfigModel copyWith({
    VideoTypeLimit? jobVideo,
    VideoTypeLimit? portfolioVideo,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return VideoLimitsConfigModel(
      jobVideo: jobVideo ?? this.jobVideo,
      portfolioVideo: portfolioVideo ?? this.portfolioVideo,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobVideo': jobVideo.toJson(),
      'portfolioVideo': portfolioVideo.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  factory VideoLimitsConfigModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VideoLimitsConfigModel();
    return VideoLimitsConfigModel(
      jobVideo: VideoTypeLimit.fromJson(json['jobVideo']),
      portfolioVideo: VideoTypeLimit.fromJson(json['portfolioVideo']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      updatedBy: json['updatedBy'],
    );
  }

  @override
  List<Object?> get props => [jobVideo, portfolioVideo, updatedAt, updatedBy];
}
