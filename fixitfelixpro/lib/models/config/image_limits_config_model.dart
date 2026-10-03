import 'package:equatable/equatable.dart';

/// Model for individual image type size limit configuration
class ImageLimitConfig extends Equatable {
  /// Maximum file size in MB (for display)
  final double maxSizeMB;

  /// Maximum file size in bytes (for validation)
  final int maxSizeBytes;

  const ImageLimitConfig({
    this.maxSizeMB = 5.0,
    this.maxSizeBytes = 5242880, // 5 MB default
  });

  /// Check if a file size is within the limit
  bool isFileSizeWithinLimit(int fileSize) => fileSize <= maxSizeBytes;

  /// Get formatted size string (e.g., "5 MB")
  String get formattedMaxSize =>
      '${maxSizeMB.toStringAsFixed(maxSizeMB == maxSizeMB.roundToDouble() ? 0 : 1)} MB';

  /// Create from JSON
  factory ImageLimitConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ImageLimitConfig();
    final maxSizeMB = (json['maxSizeMB'] as num?)?.toDouble() ?? 5.0;
    return ImageLimitConfig(
      maxSizeMB: maxSizeMB,
      maxSizeBytes:
          (json['maxSizeBytes'] as num?)?.toInt() ??
          (maxSizeMB * 1024 * 1024).toInt(),
    );
  }

  /// Create with specific size in MB
  factory ImageLimitConfig.withSizeMB(double sizeMB) {
    return ImageLimitConfig(
      maxSizeMB: sizeMB,
      maxSizeBytes: (sizeMB * 1024 * 1024).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'maxSizeMB': maxSizeMB, 'maxSizeBytes': maxSizeBytes};
  }

  @override
  List<Object?> get props => [maxSizeMB, maxSizeBytes];
}

/// Model for all image limits configuration
/// Contains size limits for different image types used in the app
class ImageLimitsConfigModel extends Equatable {
  /// Profile image size limit
  final ImageLimitConfig profileImage;

  /// Identity document (passport, ID card, driver license) size limit
  final ImageLimitConfig identityDocument;

  /// Selfie image size limit
  final ImageLimitConfig selfie;

  /// Logo image size limit
  final ImageLimitConfig logo;

  /// Extra document (certificate, license, etc.) size limit
  final ImageLimitConfig extraDocument;

  /// Portfolio image size limit
  final ImageLimitConfig portfolioImage;

  /// Job image size limit
  final ImageLimitConfig jobImage;

  /// Chat image size limit
  final ImageLimitConfig chatImage;

  /// Last updated timestamp
  final DateTime? updatedAt;

  /// User who last updated the limits
  final String? updatedBy;

  const ImageLimitsConfigModel({
    this.profileImage = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.identityDocument = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.selfie = const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
    this.logo = const ImageLimitConfig(maxSizeMB: 2.0, maxSizeBytes: 2097152),
    this.extraDocument = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.portfolioImage = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.jobImage = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.chatImage = const ImageLimitConfig(
      maxSizeMB: 5.0,
      maxSizeBytes: 5242880,
    ),
    this.updatedAt,
    this.updatedBy,
  });

  /// Get limit by image type name
  ImageLimitConfig getLimitByType(String type) {
    switch (type.toLowerCase()) {
      case 'profileimage':
      case 'profile_image':
      case 'profile':
        return profileImage;
      case 'identitydocument':
      case 'identity_document':
      case 'identity':
        return identityDocument;
      case 'selfie':
        return selfie;
      case 'logo':
        return logo;
      case 'extradocument':
      case 'extra_document':
      case 'extra':
      case 'document':
        return extraDocument;
      case 'portfolioimage':
      case 'portfolio_image':
      case 'portfolio':
        return portfolioImage;
      case 'jobimage':
      case 'job_image':
      case 'job':
        return jobImage;
      case 'chatimage':
      case 'chat_image':
      case 'chat':
        return chatImage;
      default:
        return const ImageLimitConfig();
    }
  }

  /// Create from JSON (Firebase format)
  factory ImageLimitsConfigModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ImageLimitsConfigModel();
    return ImageLimitsConfigModel(
      profileImage: json['profileImage'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['profileImage'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      identityDocument: json['identityDocument'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['identityDocument'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      selfie: json['selfie'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['selfie'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      logo: json['logo'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['logo'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 2.0, maxSizeBytes: 2097152),
      extraDocument: json['extraDocument'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['extraDocument'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      portfolioImage: json['portfolioImage'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['portfolioImage'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      jobImage: json['jobImage'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['jobImage'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      chatImage: json['chatImage'] != null
          ? ImageLimitConfig.fromJson(
              Map<String, dynamic>.from(json['chatImage'] as Map),
            )
          : const ImageLimitConfig(maxSizeMB: 5.0, maxSizeBytes: 5242880),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profileImage': profileImage.toJson(),
      'identityDocument': identityDocument.toJson(),
      'selfie': selfie.toJson(),
      'logo': logo.toJson(),
      'extraDocument': extraDocument.toJson(),
      'portfolioImage': portfolioImage.toJson(),
      'jobImage': jobImage.toJson(),
      'chatImage': chatImage.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  ImageLimitsConfigModel copyWith({
    ImageLimitConfig? profileImage,
    ImageLimitConfig? identityDocument,
    ImageLimitConfig? selfie,
    ImageLimitConfig? logo,
    ImageLimitConfig? extraDocument,
    ImageLimitConfig? portfolioImage,
    ImageLimitConfig? jobImage,
    ImageLimitConfig? chatImage,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ImageLimitsConfigModel(
      profileImage: profileImage ?? this.profileImage,
      identityDocument: identityDocument ?? this.identityDocument,
      selfie: selfie ?? this.selfie,
      logo: logo ?? this.logo,
      extraDocument: extraDocument ?? this.extraDocument,
      portfolioImage: portfolioImage ?? this.portfolioImage,
      jobImage: jobImage ?? this.jobImage,
      chatImage: chatImage ?? this.chatImage,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
    profileImage,
    identityDocument,
    selfie,
    logo,
    extraDocument,
    portfolioImage,
    jobImage,
    chatImage,
    updatedAt,
    updatedBy,
  ];
}
