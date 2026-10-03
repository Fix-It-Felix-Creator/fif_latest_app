/// Model representing a trade competency card (CSCS, ECS, JIB-PMES, Gas Safe)
class TradeCardModel {
  final String id;
  final String cardScheme; // 'cscs', 'ecs', 'jib_pmes', 'gas_safe'
  final String cardColor; // 'green', 'red', 'blue', 'gold', 'black', 'white', 'standard'
  final String qualificationLevel; // e.g. 'Labourer', 'Skilled Worker', etc.
  final String? registrationNumber;
  final DateTime? expiryDate;
  final String imageUrl; // Firebase Storage download URL
  final String mappedTrade; // Trade key derived from scheme
  final DateTime uploadedAt;
  final DateTime updatedAt;
  final String verificationStatus; // 'pending', 'verified', 'rejected'
  final String? rejectionReason;
  final int fileSize; // in bytes

  const TradeCardModel({
    required this.id,
    required this.cardScheme,
    required this.cardColor,
    required this.qualificationLevel,
    this.registrationNumber,
    this.expiryDate,
    required this.imageUrl,
    required this.mappedTrade,
    required this.uploadedAt,
    required this.updatedAt,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.fileSize = 0,
  });

  TradeCardModel copyWith({
    String? id,
    String? cardScheme,
    String? cardColor,
    String? qualificationLevel,
    String? registrationNumber,
    DateTime? expiryDate,
    String? imageUrl,
    String? mappedTrade,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    String? verificationStatus,
    String? rejectionReason,
    int? fileSize,
  }) {
    return TradeCardModel(
      id: id ?? this.id,
      cardScheme: cardScheme ?? this.cardScheme,
      cardColor: cardColor ?? this.cardColor,
      qualificationLevel: qualificationLevel ?? this.qualificationLevel,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      mappedTrade: mappedTrade ?? this.mappedTrade,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardScheme': cardScheme,
      'cardColor': cardColor,
      'qualificationLevel': qualificationLevel,
      'registrationNumber': registrationNumber,
      'expiryDate': expiryDate?.toIso8601String(),
      'imageUrl': imageUrl,
      'mappedTrade': mappedTrade,
      'uploadedAt': uploadedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'verificationStatus': verificationStatus,
      'rejectionReason': rejectionReason,
      'fileSize': fileSize,
    };
  }

  factory TradeCardModel.fromJson(Map<String, dynamic> json) {
    return TradeCardModel(
      id: json['id'] as String? ?? '',
      cardScheme: json['cardScheme'] as String? ?? '',
      cardColor: json['cardColor'] as String? ?? '',
      qualificationLevel: json['qualificationLevel'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      imageUrl: json['imageUrl'] as String? ?? '',
      mappedTrade: json['mappedTrade'] as String? ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      verificationStatus: json['verificationStatus'] as String? ?? 'pending',
      rejectionReason: json['rejectionReason'] as String?,
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }

  /// Display name for the verification status
  String get statusDisplayName {
    switch (verificationStatus) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }

  /// Whether the card has expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  /// Whether the card expires within the next 30 days
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
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
}
