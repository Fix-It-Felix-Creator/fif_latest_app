import 'package:equatable/equatable.dart';

/// Helper function to parse DateTime from various formats
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Helper function to parse DateTime with fallback to now
DateTime _parseDateTimeOrNow(dynamic value) {
  return _parseDateTime(value) ?? DateTime.now();
}

/// Review model for customer feedback on tradesman services
class Review extends Equatable {
  final String id;
  final String jobId;
  final String reviewerId; // Customer UID
  final String reviewerName;
  final String? reviewerImage;
  final String revieweeId; // Tradesman UID
  final String revieweeName;
  final double rating; // 1-5 stars
  final String? comment;
  final String? serviceType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerImage,
    required this.revieweeId,
    required this.revieweeName,
    required this.rating,
    this.comment,
    this.serviceType,
    required this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json, String id) {
    return Review(
      id: id,
      jobId: json['jobId'] ?? '',
      reviewerId: json['reviewerId'] ?? '',
      reviewerName: json['reviewerName'] ?? '',
      reviewerImage: json['reviewerImage'],
      revieweeId: json['revieweeId'] ?? '',
      revieweeName: json['revieweeName'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment'],
      serviceType: json['serviceType'],
      createdAt: _parseDateTimeOrNow(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerImage': reviewerImage,
      'revieweeId': revieweeId,
      'revieweeName': revieweeName,
      'rating': rating,
      'comment': comment,
      'serviceType': serviceType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Review copyWith({
    String? id,
    String? jobId,
    String? reviewerId,
    String? reviewerName,
    String? reviewerImage,
    String? revieweeId,
    String? revieweeName,
    double? rating,
    String? comment,
    String? serviceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerImage: reviewerImage ?? this.reviewerImage,
      revieweeId: revieweeId ?? this.revieweeId,
      revieweeName: revieweeName ?? this.revieweeName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      serviceType: serviceType ?? this.serviceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    jobId,
    reviewerId,
    reviewerName,
    reviewerImage,
    revieweeId,
    revieweeName,
    rating,
    comment,
    serviceType,
    createdAt,
    updatedAt,
  ];
}

/// Rating summary for a tradesman
class RatingSummary extends Equatable {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // 1-5 star counts

  const RatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
      ratingDistribution: {
        1: json['rating1'] ?? 0,
        2: json['rating2'] ?? 0,
        3: json['rating3'] ?? 0,
        4: json['rating4'] ?? 0,
        5: json['rating5'] ?? 0,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'rating1': ratingDistribution[1] ?? 0,
      'rating2': ratingDistribution[2] ?? 0,
      'rating3': ratingDistribution[3] ?? 0,
      'rating4': ratingDistribution[4] ?? 0,
      'rating5': ratingDistribution[5] ?? 0,
    };
  }

  factory RatingSummary.empty() {
    return const RatingSummary(
      averageRating: 0,
      totalReviews: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    );
  }

  @override
  List<Object?> get props => [averageRating, totalReviews, ratingDistribution];
}
