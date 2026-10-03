import 'package:equatable/equatable.dart';

/// Categories of trade requirements
enum RequirementCategory { legal, safety, qualification, tradeSpecific }

/// Per-document verification status
enum DocVerificationStatus { pending, verified, rejected }

/// Model representing a UK trade qualification requirement
class TradeRequirement extends Equatable {
  final String id;
  final String name;
  final String description;
  final RequirementCategory category;
  final bool isMandatory;

  /// List of trade keys this applies to, or null = all trades
  final List<String>? applicableTrades;

  const TradeRequirement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.isMandatory,
    this.applicableTrades,
  });

  /// Human-readable category label
  String get categoryLabel {
    switch (category) {
      case RequirementCategory.legal:
        return 'Legal';
      case RequirementCategory.safety:
        return 'Safety';
      case RequirementCategory.qualification:
        return 'Qualification';
      case RequirementCategory.tradeSpecific:
        return 'Trade Specific';
    }
  }

  @override
  List<Object?> get props => [id, name, description, category, isMandatory, applicableTrades];
}

/// Model representing an uploaded trade qualification document
class TradeQualificationDoc extends Equatable {
  final String requirementId;
  final String documentUrl;
  final bool isMandatory;
  final DateTime uploadedAt;
  final DocVerificationStatus verificationStatus;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int fileSize;

  const TradeQualificationDoc({
    required this.requirementId,
    required this.documentUrl,
    required this.isMandatory,
    required this.uploadedAt,
    this.verificationStatus = DocVerificationStatus.pending,
    this.rejectionReason,
    this.verifiedAt,
    this.verifiedBy,
    this.fileSize = 0,
  });

  TradeQualificationDoc copyWith({
    String? requirementId,
    String? documentUrl,
    bool? isMandatory,
    DateTime? uploadedAt,
    DocVerificationStatus? verificationStatus,
    String? rejectionReason,
    DateTime? verifiedAt,
    String? verifiedBy,
    int? fileSize,
  }) {
    return TradeQualificationDoc(
      requirementId: requirementId ?? this.requirementId,
      documentUrl: documentUrl ?? this.documentUrl,
      isMandatory: isMandatory ?? this.isMandatory,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requirementId': requirementId,
      'documentUrl': documentUrl,
      'isMandatory': isMandatory,
      'uploadedAt': uploadedAt.toIso8601String(),
      'verificationStatus': verificationStatus.name,
      'rejectionReason': rejectionReason,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedBy': verifiedBy,
      'fileSize': fileSize,
    };
  }

  factory TradeQualificationDoc.fromJson(Map<String, dynamic> json) {
    return TradeQualificationDoc(
      requirementId: json['requirementId'] as String? ?? '',
      documentUrl: json['documentUrl'] as String? ?? '',
      isMandatory: json['isMandatory'] as bool? ?? false,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'])
          : DateTime.now(),
      verificationStatus: DocVerificationStatus.values.firstWhere(
        (e) => e.name == json['verificationStatus'],
        orElse: () => DocVerificationStatus.pending,
      ),
      rejectionReason: json['rejectionReason'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      verifiedBy: json['verifiedBy'] as String?,
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }

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

  @override
  List<Object?> get props => [
    requirementId,
    documentUrl,
    isMandatory,
    uploadedAt,
    verificationStatus,
    rejectionReason,
    verifiedAt,
    verifiedBy,
    fileSize,
  ];
}
