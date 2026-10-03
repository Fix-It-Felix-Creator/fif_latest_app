import 'package:equatable/equatable.dart';

class PhotoCollection extends Equatable {
  final String id;
  final String title;
  final String? jobId;
  final String? beforePhotoId;
  final String? afterPhotoId;
  final List<String> photoIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotoCollection({
    required this.id,
    required this.title,
    this.jobId,
    this.beforePhotoId,
    this.afterPhotoId,
    this.photoIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotoCollection.fromJson(Map<String, dynamic> json, String id) {
    return PhotoCollection(
      id: id,
      title: json['title'] as String? ?? '',
      jobId: json['jobId'] as String?,
      beforePhotoId: json['beforePhotoId'] as String?,
      afterPhotoId: json['afterPhotoId'] as String?,
      photoIds: (json['photoIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
      'title': title,
      if (jobId != null) 'jobId': jobId,
      if (beforePhotoId != null) 'beforePhotoId': beforePhotoId,
      if (afterPhotoId != null) 'afterPhotoId': afterPhotoId,
      'photoIds': photoIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PhotoCollection copyWith({
    String? id,
    String? title,
    String? jobId,
    String? beforePhotoId,
    String? afterPhotoId,
    List<String>? photoIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhotoCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      jobId: jobId ?? this.jobId,
      beforePhotoId: beforePhotoId ?? this.beforePhotoId,
      afterPhotoId: afterPhotoId ?? this.afterPhotoId,
      photoIds: photoIds ?? this.photoIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id, title, jobId, beforePhotoId, afterPhotoId, photoIds,
        createdAt, updatedAt,
      ];
}
