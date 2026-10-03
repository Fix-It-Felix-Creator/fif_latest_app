import 'package:equatable/equatable.dart';

/// Where an application has got to.
///
/// [unknown] exists because the database may grow a status this build has
/// never heard of; a row that arrives with one should render as itself rather
/// than crash the screen.
enum LeadApplicationStatus {
  submitted,
  approved,
  rejected,
  withdrawn,
  superseded,
  unknown,
}

extension LeadApplicationStatusX on LeadApplicationStatus {
  String get wire => switch (this) {
        LeadApplicationStatus.submitted => 'submitted',
        LeadApplicationStatus.approved => 'approved',
        LeadApplicationStatus.rejected => 'rejected',
        LeadApplicationStatus.withdrawn => 'withdrawn',
        LeadApplicationStatus.superseded => 'superseded',
        LeadApplicationStatus.unknown => 'submitted',
      };

  static LeadApplicationStatus fromWire(String? v) => switch (v) {
        'submitted' => LeadApplicationStatus.submitted,
        'approved' => LeadApplicationStatus.approved,
        'rejected' => LeadApplicationStatus.rejected,
        'withdrawn' => LeadApplicationStatus.withdrawn,
        'superseded' => LeadApplicationStatus.superseded,
        _ => LeadApplicationStatus.unknown,
      };

  /// Whether this is the application currently in force or being decided.
  ///
  /// Withdrawn, rejected and superseded rows are history: they stay for the
  /// record, and they are what a new application is prefilled from, but they
  /// are not the applicant's current state.
  bool get isLive =>
      this == LeadApplicationStatus.submitted ||
      this == LeadApplicationStatus.approved;

  /// Whether the applicant may start a fresh application.
  bool get allowsReapply =>
      this == LeadApplicationStatus.rejected ||
      this == LeadApplicationStatus.withdrawn ||
      this == LeadApplicationStatus.superseded;
}

/// A tradesperson's request to receive live leads.
class LeadApplication extends Equatable {
  const LeadApplication({
    required this.id,
    required this.applicantType,
    required this.services,
    required this.registrations,
    required this.status,
    required this.headline,
    required this.about,
    this.movesWaste,
    this.wasteCarrierNumber,
    this.baseAddress = '',
    this.baseLatitude,
    this.baseLongitude,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.takesEmergencies = false,
    this.hasOwnInsurance = true,
    this.insurer,
    this.policyNumber,
    this.coverAmount,
    this.policyExpiresAt,
    this.yearsExperience,
    this.documentType,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String applicantType;
  final List<String> services;
  final Map<String, String> registrations;
  final LeadApplicationStatus status;

  final bool? movesWaste;
  final String? wasteCarrierNumber;

  final String baseAddress;
  final double? baseLatitude;
  final double? baseLongitude;
  final List<int> workingDays;
  final bool takesEmergencies;

  final bool hasOwnInsurance;
  final String? insurer;
  final String? policyNumber;
  final String? coverAmount;
  final DateTime? policyExpiresAt;

  final String headline;
  final String about;
  final int? yearsExperience;

  /// Which photo ID was submitted, as stored on the row.
  final String? documentType;

  /// Why staff turned it down. Always present on a rejected row — the database
  /// will not accept one without it.
  final String? rejectionReason;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  bool get isSolo => applicantType == 'solo';

  factory LeadApplication.fromRow(Map<String, dynamic> row) {
    final regs = row['registrations'];
    return LeadApplication(
      id: (row['id'] ?? '').toString(),
      applicantType: (row['applicant_type'] ?? 'solo').toString(),
      services: [
        for (final s in (row['services'] as List? ?? const [])) s.toString(),
      ],
      registrations: regs is Map
          ? {
              for (final e in regs.entries)
                e.key.toString(): (e.value ?? '').toString(),
            }
          : const {},
      status: LeadApplicationStatusX.fromWire(row['status'] as String?),
      movesWaste: row['moves_waste'] as bool?,
      wasteCarrierNumber: row['waste_carrier_number'] as String?,
      baseAddress: (row['base_address'] ?? '').toString(),
      baseLatitude: (row['base_latitude'] as num?)?.toDouble(),
      baseLongitude: (row['base_longitude'] as num?)?.toDouble(),
      workingDays: [
        for (final d in (row['working_days'] as List? ?? const []))
          int.tryParse(d.toString()) ?? 0,
      ],
      takesEmergencies: row['takes_emergencies'] as bool? ?? false,
      hasOwnInsurance: row['has_own_insurance'] as bool? ?? true,
      insurer: row['insurer'] as String?,
      policyNumber: row['policy_number'] as String?,
      coverAmount: row['cover_amount'] as String?,
      policyExpiresAt:
          DateTime.tryParse((row['policy_expires_at'] ?? '').toString()),
      headline: (row['headline'] ?? '').toString(),
      about: (row['about'] ?? '').toString(),
      yearsExperience: (row['years_experience'] as num?)?.toInt(),
      documentType: row['document_type'] as String?,
      rejectionReason: row['rejection_reason'] as String?,
      submittedAt: DateTime.tryParse((row['submitted_at'] ?? '').toString()),
      reviewedAt: DateTime.tryParse((row['reviewed_at'] ?? '').toString()),
    );
  }

  @override
  List<Object?> get props => [id, status, rejectionReason, reviewedAt];
}
