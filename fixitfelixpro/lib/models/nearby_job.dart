import 'package:equatable/equatable.dart';

/// A job on the board, as a tradesperson may see it before taking it.
///
/// Deliberately not the whole `job_requests` row. The address is withheld and
/// the coordinates are rounded to about a kilometre until the job is theirs —
/// you see the area before you accept, and the door afterwards.
class NearbyJob extends Equatable {
  const NearbyJob({
    required this.id,
    required this.serviceName,
    required this.summary,
    required this.description,
    required this.urgency,
    required this.status,
    required this.distanceKm,
    required this.mine,
    this.serviceId,
    this.latitude,
    this.longitude,
    this.postcodeDistrict,
    this.offersSent = 0,
    this.postedAt,
  });

  final String id;
  final String? serviceId;
  final String serviceName;

  /// The deepest thing the customer picked — what the job actually is.
  final String summary;

  final String description;
  final String urgency;
  final String status;

  final double distanceKm;

  /// Rounded to ~1km. Enough for a map pin, useless for a doorstep.
  final double? latitude;
  final double? longitude;

  /// "G74", not "G74 3NN".
  final String? postcodeDistrict;

  /// How many tradespeople this job has reached. Competition, plainly stated.
  final int offersSent;

  final DateTime? postedAt;

  /// Whether this one is already theirs.
  final bool mine;

  bool get hasPin => latitude != null && longitude != null;

  String get distanceLabel => distanceKm < 1
      ? 'Under a mile'
      : '${(distanceKm * 0.621371).toStringAsFixed(distanceKm < 16 ? 1 : 0)} mi';

  String get urgencyLabel => switch (urgency) {
        'urgent' => 'ASAP',
        'flexible' => 'Flexible',
        _ => 'Few days',
      };

  factory NearbyJob.fromRow(Map<String, dynamic> row) => NearbyJob(
        id: (row['id'] ?? '').toString(),
        serviceId: row['service_id'] as String?,
        serviceName: (row['service_name'] ?? '').toString(),
        summary: (row['summary'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        urgency: (row['urgency'] ?? 'soon').toString(),
        status: (row['status'] ?? 'posted').toString(),
        distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0,
        latitude: (row['approx_latitude'] as num?)?.toDouble(),
        longitude: (row['approx_longitude'] as num?)?.toDouble(),
        postcodeDistrict: row['postcode_district'] as String?,
        offersSent: (row['offers_sent'] as num?)?.toInt() ?? 0,
        postedAt: DateTime.tryParse((row['posted_at'] ?? '').toString()),
        mine: row['mine'] == true,
      );

  @override
  List<Object?> get props => [id, status, mine, offersSent];
}
