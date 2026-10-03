import 'package:equatable/equatable.dart';

/// Business-specific limits model
/// Contains limits specific to business accounts (branches, team members, etc.)
class BusinessLimitsModel extends Equatable {
  /// Whether API access is available
  final bool apiAccess;

  /// Maximum number of branches (-1 = unlimited)
  final int maxBranches;

  /// Maximum photo uploads (-1 = unlimited)
  final int maxPhotoUploads;

  /// Maximum projects per month (-1 = unlimited)
  final int maxProjectsPerMonth;

  /// Maximum staff members (-1 = unlimited)
  final int maxStaffMembers;

  /// Maximum video uploads (-1 = unlimited)
  final int maxVideoUploads;

  /// Whether priority support is available
  final bool prioritySupport;

  /// Service radius in miles (-1 = unlimited)
  final int serviceRadiusMiles;

  const BusinessLimitsModel({
    this.apiAccess = false,
    this.maxBranches = 1,
    this.maxPhotoUploads = 10,
    this.maxProjectsPerMonth = 10,
    this.maxStaffMembers = 5,
    this.maxVideoUploads = 5,
    this.prioritySupport = false,
    this.serviceRadiusMiles = 50,
  });

  /// Check if branches limit is unlimited (-1)
  bool get isBranchesUnlimited => maxBranches == -1;

  /// Check if photo uploads limit is unlimited (-1)
  bool get isPhotoUploadsUnlimited => maxPhotoUploads == -1;

  /// Check if projects per month limit is unlimited (-1)
  bool get isProjectsUnlimited => maxProjectsPerMonth == -1;

  /// Check if staff members limit is unlimited (-1)
  bool get isStaffMembersUnlimited => maxStaffMembers == -1;

  /// Check if video uploads limit is unlimited (-1)
  bool get isVideoUploadsUnlimited => maxVideoUploads == -1;

  /// Check if service radius is unlimited (-1)
  bool get isServiceRadiusUnlimited => serviceRadiusMiles == -1;

  /// Check if user can add more branches
  bool canAddBranch(int currentCount) =>
      isBranchesUnlimited || currentCount < maxBranches;

  /// Check if user can upload more photos
  bool canUploadPhoto(int currentPhotoCount) =>
      isPhotoUploadsUnlimited || currentPhotoCount < maxPhotoUploads;

  /// Check if user can create more projects this month
  bool canCreateProject(int currentMonthlyProjects) =>
      isProjectsUnlimited || currentMonthlyProjects < maxProjectsPerMonth;

  /// Check if user can add more staff members
  bool canAddStaff(int currentStaffCount) =>
      isStaffMembersUnlimited || currentStaffCount < maxStaffMembers;

  /// Check if user can upload more videos
  bool canUploadVideo(int currentVideoCount) =>
      isVideoUploadsUnlimited || currentVideoCount < maxVideoUploads;

  /// Check if a job is within the service radius
  bool isJobWithinRadius(double distanceMiles) =>
      isServiceRadiusUnlimited || distanceMiles <= serviceRadiusMiles;

  /// Format limit display string
  String formatLimit(int limit) {
    if (limit == -1) return 'Unlimited';
    return limit.toString();
  }

  /// Format staff member limit for display (e.g., "2/5" or "2/∞")
  String formatStaffMemberLimit(int currentCount) {
    if (isStaffMembersUnlimited) return '$currentCount/∞';
    return '$currentCount/$maxStaffMembers';
  }

  BusinessLimitsModel copyWith({
    bool? apiAccess,
    int? maxBranches,
    int? maxPhotoUploads,
    int? maxProjectsPerMonth,
    int? maxStaffMembers,
    int? maxVideoUploads,
    bool? prioritySupport,
    int? serviceRadiusMiles,
  }) {
    return BusinessLimitsModel(
      apiAccess: apiAccess ?? this.apiAccess,
      maxBranches: maxBranches ?? this.maxBranches,
      maxPhotoUploads: maxPhotoUploads ?? this.maxPhotoUploads,
      maxProjectsPerMonth: maxProjectsPerMonth ?? this.maxProjectsPerMonth,
      maxStaffMembers: maxStaffMembers ?? this.maxStaffMembers,
      maxVideoUploads: maxVideoUploads ?? this.maxVideoUploads,
      prioritySupport: prioritySupport ?? this.prioritySupport,
      serviceRadiusMiles: serviceRadiusMiles ?? this.serviceRadiusMiles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiAccess': apiAccess,
      'maxBranches': maxBranches,
      'maxPhotoUploads': maxPhotoUploads,
      'maxProjectsPerMonth': maxProjectsPerMonth,
      'maxStaffMembers': maxStaffMembers,
      'maxVideoUploads': maxVideoUploads,
      'prioritySupport': prioritySupport,
      'serviceRadiusMiles': serviceRadiusMiles,
    };
  }

  factory BusinessLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BusinessLimitsModel();
    return BusinessLimitsModel(
      apiAccess: json['apiAccess'] ?? false,
      maxBranches: json['maxBranches'] ?? 1,
      maxPhotoUploads: json['maxPhotoUploads'] ?? 10,
      maxProjectsPerMonth: json['maxProjectsPerMonth'] ?? 10,
      maxStaffMembers: json['maxStaffMembers'] ?? 5,
      maxVideoUploads: json['maxVideoUploads'] ?? 5,
      prioritySupport: json['prioritySupport'] ?? false,
      serviceRadiusMiles: json['serviceRadiusMiles'] ?? 50,
    );
  }

  @override
  List<Object?> get props => [
    apiAccess,
    maxBranches,
    maxPhotoUploads,
    maxProjectsPerMonth,
    maxStaffMembers,
    maxVideoUploads,
    prioritySupport,
    serviceRadiusMiles,
  ];
}
