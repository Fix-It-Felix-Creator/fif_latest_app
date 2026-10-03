import 'package:equatable/equatable.dart';

/// Tradesman-specific limits model
/// Contains limits specific to tradesman accounts (job applications, staff, etc.)
class TradesmanLimitsModel extends Equatable {
  /// Maximum freelance hires per month (-1 = unlimited, 0 = not available)
  final int maxFreelanceHiresPerMonth;

  /// Maximum job applications per month (-1 = unlimited)
  final int maxJobApplicationsPerMonth;

  /// Maximum photo uploads (-1 = unlimited)
  final int maxPhotoUploads;

  /// Maximum staff members (-1 = unlimited, 0 = not available)
  final int maxStaffMembers;

  /// Maximum video uploads (-1 = unlimited)
  final int maxVideoUploads;

  /// Service radius in miles (-1 = unlimited)
  final int serviceRadiusMiles;

  /// Maximum cancellations allowed per month (default 2)
  final int maxCancellationsPerMonth;

  /// Maximum visible leads per month (-1 = unlimited, default 10)
  final int maxVisibleLeadsPerMonth;

  const TradesmanLimitsModel({
    this.maxFreelanceHiresPerMonth = 0,
    this.maxJobApplicationsPerMonth = -1,
    this.maxPhotoUploads = 5,
    this.maxStaffMembers = 0,
    this.maxVideoUploads = 2,
    this.serviceRadiusMiles = 5,
    this.maxCancellationsPerMonth = 2,
    this.maxVisibleLeadsPerMonth = 10,
  });

  /// Check if freelance hiring is available
  bool get hasFreelanceHiring => maxFreelanceHiresPerMonth != 0;

  /// Check if freelance hires limit is unlimited (-1)
  bool get isFreelanceHiresUnlimited => maxFreelanceHiresPerMonth == -1;

  /// Check if job applications limit is unlimited (-1)
  bool get isJobApplicationsUnlimited => maxJobApplicationsPerMonth == -1;

  /// Check if photo uploads limit is unlimited (-1)
  bool get isPhotoUploadsUnlimited => maxPhotoUploads == -1;

  /// Check if staff management is available
  bool get hasStaffManagement => maxStaffMembers != 0;

  /// Check if staff members limit is unlimited (-1)
  bool get isStaffMembersUnlimited => maxStaffMembers == -1;

  /// Check if video uploads limit is unlimited (-1)
  bool get isVideoUploadsUnlimited => maxVideoUploads == -1;

  /// Check if service radius is unlimited (-1)
  bool get isServiceRadiusUnlimited => serviceRadiusMiles == -1;

  /// Check if user can hire more freelancers this month
  bool canHireFreelancer(int currentMonthlyHires) =>
      hasFreelanceHiring &&
      (isFreelanceHiresUnlimited ||
          currentMonthlyHires < maxFreelanceHiresPerMonth);

  /// Check if user can apply to more jobs this month
  bool canApplyToJob(int currentMonthlyApplications) =>
      isJobApplicationsUnlimited ||
      currentMonthlyApplications < maxJobApplicationsPerMonth;

  /// Check if user can upload more photos
  bool canUploadPhoto(int currentPhotoCount) =>
      isPhotoUploadsUnlimited || currentPhotoCount < maxPhotoUploads;

  /// Check if user can add more staff members
  bool canAddStaff(int currentStaffCount) =>
      hasStaffManagement &&
      (isStaffMembersUnlimited || currentStaffCount < maxStaffMembers);

  /// Check if user can upload more videos
  bool canUploadVideo(int currentVideoCount) =>
      isVideoUploadsUnlimited || currentVideoCount < maxVideoUploads;

  /// Check if a job is within the service radius
  bool isJobWithinRadius(double distanceMiles) =>
      isServiceRadiusUnlimited || distanceMiles <= serviceRadiusMiles;

  /// Check if cancellation limit is unlimited
  bool get isCancellationsUnlimited => maxCancellationsPerMonth == -1;

  /// Check if tradesman can cancel more jobs this month
  bool canCancelMore(int currentCancellations) =>
      isCancellationsUnlimited ||
      currentCancellations < maxCancellationsPerMonth;

  /// Check if leads visibility is unlimited
  bool get isLeadsUnlimited => maxVisibleLeadsPerMonth == -1;

  /// Format limit display string
  String formatLimit(int limit) {
    if (limit == -1) return 'Unlimited';
    if (limit == 0) return 'Not available';
    return limit.toString();
  }

  /// Format staff limit for display (e.g., "2/5" or "2/∞")
  String formatStaffLimit(int currentCount) {
    if (!hasStaffManagement) return 'Not available';
    if (isStaffMembersUnlimited) return '$currentCount/∞';
    return '$currentCount/$maxStaffMembers';
  }

  TradesmanLimitsModel copyWith({
    int? maxFreelanceHiresPerMonth,
    int? maxJobApplicationsPerMonth,
    int? maxPhotoUploads,
    int? maxStaffMembers,
    int? maxVideoUploads,
    int? serviceRadiusMiles,
    int? maxCancellationsPerMonth,
    int? maxVisibleLeadsPerMonth,
  }) {
    return TradesmanLimitsModel(
      maxFreelanceHiresPerMonth:
          maxFreelanceHiresPerMonth ?? this.maxFreelanceHiresPerMonth,
      maxJobApplicationsPerMonth:
          maxJobApplicationsPerMonth ?? this.maxJobApplicationsPerMonth,
      maxPhotoUploads: maxPhotoUploads ?? this.maxPhotoUploads,
      maxStaffMembers: maxStaffMembers ?? this.maxStaffMembers,
      maxVideoUploads: maxVideoUploads ?? this.maxVideoUploads,
      serviceRadiusMiles: serviceRadiusMiles ?? this.serviceRadiusMiles,
      maxCancellationsPerMonth:
          maxCancellationsPerMonth ?? this.maxCancellationsPerMonth,
      maxVisibleLeadsPerMonth:
          maxVisibleLeadsPerMonth ?? this.maxVisibleLeadsPerMonth,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxFreelanceHiresPerMonth': maxFreelanceHiresPerMonth,
      'maxJobApplicationsPerMonth': maxJobApplicationsPerMonth,
      'maxPhotoUploads': maxPhotoUploads,
      'maxStaffMembers': maxStaffMembers,
      'maxVideoUploads': maxVideoUploads,
      'serviceRadiusMiles': serviceRadiusMiles,
      'maxCancellationsPerMonth': maxCancellationsPerMonth,
      'maxVisibleLeadsPerMonth': maxVisibleLeadsPerMonth,
    };
  }

  factory TradesmanLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TradesmanLimitsModel();
    return TradesmanLimitsModel(
      maxFreelanceHiresPerMonth: json['maxFreelanceHiresPerMonth'] ?? 0,
      maxJobApplicationsPerMonth: json['maxJobApplicationsPerMonth'] ?? -1,
      maxPhotoUploads: json['maxPhotoUploads'] ?? 5,
      maxStaffMembers: json['maxStaffMembers'] ?? 0,
      maxVideoUploads: json['maxVideoUploads'] ?? 2,
      serviceRadiusMiles: json['serviceRadiusMiles'] ?? 5,
      maxCancellationsPerMonth: json['maxCancellationsPerMonth'] ?? 2,
      maxVisibleLeadsPerMonth: json['maxVisibleLeadsPerMonth'] ?? 10,
    );
  }

  @override
  List<Object?> get props => [
    maxFreelanceHiresPerMonth,
    maxJobApplicationsPerMonth,
    maxPhotoUploads,
    maxStaffMembers,
    maxVideoUploads,
    serviceRadiusMiles,
    maxCancellationsPerMonth,
    maxVisibleLeadsPerMonth,
  ];
}
