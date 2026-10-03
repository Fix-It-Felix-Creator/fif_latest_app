import 'package:equatable/equatable.dart';

enum PhotoCategory {
  general,
  beforeWork,
  afterWork,
  progress,
  damage,
  measurement,
  receipt,
}

extension PhotoCategoryExtension on PhotoCategory {
  String get displayName {
    switch (this) {
      case PhotoCategory.general:
        return 'General';
      case PhotoCategory.beforeWork:
        return 'Before';
      case PhotoCategory.afterWork:
        return 'After';
      case PhotoCategory.progress:
        return 'Progress';
      case PhotoCategory.damage:
        return 'Damage';
      case PhotoCategory.measurement:
        return 'Measurement';
      case PhotoCategory.receipt:
        return 'Receipt';
    }
  }

  static PhotoCategory fromString(String value) {
    return PhotoCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PhotoCategory.general,
    );
  }
}

class PhotoItem extends Equatable {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final PhotoCategory category;
  final List<String> tags;
  final String notes;
  final String? jobId;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotoItem({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    this.category = PhotoCategory.general,
    this.tags = const [],
    this.notes = '',
    this.jobId,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json, String id) {
    return PhotoItem(
      id: id,
      imageUrl: json['imageUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      category: PhotoCategoryExtension.fromString(
          json['category'] as String? ?? 'general'),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
      jobId: json['jobId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'category': category.name,
      'tags': tags,
      'notes': notes,
      if (jobId != null) 'jobId': jobId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PhotoItem copyWith({
    String? id,
    String? imageUrl,
    String? thumbnailUrl,
    PhotoCategory? category,
    List<String>? tags,
    String? notes,
    String? jobId,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      jobId: jobId ?? this.jobId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, imageUrl, thumbnailUrl, category, tags, notes,
        jobId, latitude, longitude, createdAt, updatedAt,
      ];
}
