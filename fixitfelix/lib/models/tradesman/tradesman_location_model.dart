import 'package:equatable/equatable.dart';

import '../../core/enum.dart';

class TradesmanLocation extends Equatable {
  final String uid;
  final String name;
  final String? profileImage;
  final String trade;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool isPremium;
  final double rating;
  final int reviewCount;
  final int jobsDone;
  final double? distance;
  final VerificationStatus verificationStatus;

  const TradesmanLocation({
    required this.uid,
    required this.name,
    this.profileImage,
    required this.trade,
    required this.latitude,
    required this.longitude,
    this.isAvailable = false,
    this.isPremium = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.jobsDone = 0,
    this.distance,
    this.verificationStatus = VerificationStatus.waiting,
  });

  factory TradesmanLocation.fromFirebase(Map<String, dynamic> json, String uid) {
    final subscription = json['subscription'] as Map?;
    final planType = subscription?['planType'] as String? ?? 'standard';
    final isPremium =
        planType == 'plus' || planType == 'advance' || planType == 'vip';

    final location = json['location'] as Map?;
    final lat = (location?['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (location?['longitude'] as num?)?.toDouble() ?? 0.0;

    return TradesmanLocation(
      uid: uid,
      name: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      profileImage: json['profileImage'] as String?,
      trade: json['trade'] as String? ?? 'General',
      latitude: lat,
      longitude: lng,
      isAvailable: json['isAvailable'] == true,
      isPremium: isPremium,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      jobsDone: (json['jobsDone'] as num?)?.toInt() ?? 0,
      verificationStatus: _parseVerificationStatus(
          json['verificationStatus'] as String?),
    );
  }

  TradesmanLocation copyWith({double? distance}) {
    return TradesmanLocation(
      uid: uid,
      name: name,
      profileImage: profileImage,
      trade: trade,
      latitude: latitude,
      longitude: longitude,
      isAvailable: isAvailable,
      isPremium: isPremium,
      rating: rating,
      reviewCount: reviewCount,
      jobsDone: jobsDone,
      distance: distance ?? this.distance,
      verificationStatus: verificationStatus,
    );
  }

  static VerificationStatus _parseVerificationStatus(String? status) {
    switch (status) {
      case 'verified':
        return VerificationStatus.verified;
      case 'unverified':
        return VerificationStatus.unverified;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.waiting;
    }
  }

  @override
  List<Object?> get props => [uid, name, trade, latitude, longitude,
      isAvailable, isPremium, rating, distance];
}
