import 'package:equatable/equatable.dart';

/// Where a posted job has got to.
///
/// Mirrors `job_requests_status_check`. [unknown] exists because the database
/// is allowed to grow a status this build has never heard of — a row that
/// arrives with one should render as itself rather than crash a list.
enum JobRequestStatus { posted, assigned, inProgress, completed, cancelled, unknown }

extension JobRequestStatusX on JobRequestStatus {
  String get wire => switch (this) {
        JobRequestStatus.posted => 'posted',
        JobRequestStatus.assigned => 'assigned',
        JobRequestStatus.inProgress => 'in_progress',
        JobRequestStatus.completed => 'completed',
        JobRequestStatus.cancelled => 'cancelled',
        JobRequestStatus.unknown => 'posted',
      };

  String get label => switch (this) {
        JobRequestStatus.posted => 'Finding someone',
        JobRequestStatus.assigned => 'Tradesperson assigned',
        JobRequestStatus.inProgress => 'In progress',
        JobRequestStatus.completed => 'Completed',
        JobRequestStatus.cancelled => 'Cancelled',
        JobRequestStatus.unknown => 'Unknown',
      };

  /// Whether the job still counts towards the Jobs tab badge.
  ///
  /// Anything that is not finished with. An unrecognised status counts as
  /// open: a job the app cannot classify is one the customer should still be
  /// able to see, not one that quietly vanishes from the count.
  bool get isOpen =>
      this != JobRequestStatus.completed && this != JobRequestStatus.cancelled;

  static JobRequestStatus fromWire(String? v) => switch (v) {
        'posted' => JobRequestStatus.posted,
        'assigned' => JobRequestStatus.assigned,
        'in_progress' => JobRequestStatus.inProgress,
        'completed' => JobRequestStatus.completed,
        'cancelled' => JobRequestStatus.cancelled,
        _ => JobRequestStatus.unknown,
      };
}

/// How soon the customer needs someone. Mirrors `job_requests_urgency_check`.
enum JobUrgency { flexible, soon, urgent }

extension JobUrgencyX on JobUrgency {
  String get wire => name;

  /// What the segmented control says. Short enough that three fit across a
  /// phone — the long version is [detail].
  String get short => switch (this) {
        JobUrgency.flexible => 'Flexible',
        JobUrgency.soon => 'Few days',
        JobUrgency.urgent => 'ASAP',
      };

  String get detail => switch (this) {
        JobUrgency.flexible => 'No rush — any time that suits a tradesperson.',
        JobUrgency.soon => 'Within the next few days.',
        JobUrgency.urgent => 'As soon as someone can get there.',
      };

  static JobUrgency fromWire(String? v) => switch (v) {
        'flexible' => JobUrgency.flexible,
        'urgent' => JobUrgency.urgent,
        _ => JobUrgency.soon,
      };
}

/// One step of the path a customer took through a service's questions.
class JobRequestSelection extends Equatable {
  const JobRequestSelection({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory JobRequestSelection.fromJson(Map<String, dynamic> json) =>
      JobRequestSelection(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [id, name];
}

/// A job a homeowner posted.
///
/// Not a [Job] — that is the tradesperson's own record of work. This is the
/// request that goes looking for one.
class JobRequest extends Equatable {
  const JobRequest({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.selections,
    required this.description,
    required this.urgency,
    required this.formattedAddress,
    required this.status,
    this.line1,
    this.line2,
    this.city,
    this.county,
    this.postcode,
    this.latitude,
    this.longitude,
    this.acceptedBy,
    this.acceptedAt,
    this.createdAt,
  });

  final String id;
  final String? serviceId;
  final String serviceName;
  final List<JobRequestSelection> selections;
  final String description;
  final JobUrgency urgency;

  final String formattedAddress;
  final String? line1;
  final String? line2;
  final String? city;
  final String? county;
  final String? postcode;

  /// Where the job is. Null when the address was never geocoded, which is the
  /// one state that stops it reaching anybody — nothing can be matched by
  /// distance to a place with no coordinates.
  final double? latitude;
  final double? longitude;

  final JobRequestStatus status;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// The deepest choice — what the job actually is, in one phrase.
  String get summary =>
      selections.isEmpty ? serviceName : selections.last.name;

  factory JobRequest.fromRow(Map<String, dynamic> row) {
    final raw = row['selections'];
    return JobRequest(
      id: (row['id'] ?? '').toString(),
      serviceId: row['service_id'] as String?,
      serviceName: (row['service_name'] ?? '').toString(),
      selections: raw is List
          ? raw
              .whereType<Map>()
              .map((e) =>
                  JobRequestSelection.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      description: (row['description'] ?? '').toString(),
      urgency: JobUrgencyX.fromWire(row['urgency'] as String?),
      formattedAddress: (row['formatted_address'] ?? '').toString(),
      line1: row['address_line1'] as String?,
      line2: row['address_line2'] as String?,
      city: row['city'] as String?,
      county: row['county'] as String?,
      postcode: row['postcode'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      status: JobRequestStatusX.fromWire(row['status'] as String?),
      acceptedBy: row['accepted_by'] as String?,
      acceptedAt: DateTime.tryParse((row['accepted_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
    );
  }

  @override
  List<Object?> get props => [id, status, serviceName, updatedMarker];

  /// Everything a list row draws, so two states with the same id but different
  /// contents are not treated as equal.
  Object get updatedMarker =>
      '$urgency|$formattedAddress|$description|$acceptedBy';
}
