import 'package:equatable/equatable.dart';

/// Types of extra documents a tradesman can upload
enum ExtraDocumentType { certificate, license, insurance, qualification, other }

/// Model representing an extra document/certificate uploaded by tradesman
class ExtraDocumentModel extends Equatable {
  final String id;
  final String name;
  final String url;
  final ExtraDocumentType type;
  final String? description;
  final int fileSize; // in bytes
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExtraDocumentModel({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.description,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });

  ExtraDocumentModel copyWith({
    String? id,
    String? name,
    String? url,
    ExtraDocumentType? type,
    String? description,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExtraDocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      description: description ?? this.description,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'description': description,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ExtraDocumentModel.fromJson(Map<String, dynamic> json) {
    return ExtraDocumentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      type: ExtraDocumentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExtraDocumentType.other,
      ),
      description: json['description'] as String?,
      fileSize: json['fileSize'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
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

  /// Get display name for document type
  String get typeDisplayName {
    switch (type) {
      case ExtraDocumentType.certificate:
        return 'Certificate';
      case ExtraDocumentType.license:
        return 'License';
      case ExtraDocumentType.insurance:
        return 'Insurance';
      case ExtraDocumentType.qualification:
        return 'Qualification';
      case ExtraDocumentType.other:
        return 'Other';
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    url,
    type,
    description,
    fileSize,
    createdAt,
    updatedAt,
  ];
}
