import 'package:equatable/equatable.dart';

import 'config/base_limits_model.dart';
import 'config/business_limits_model.dart';
import 'config/customer_limits_model.dart';
import 'config/tradesman_limits_model.dart';

/// Combined feature limits model for subscription plans
/// Merges base limits with account-type specific limits
/// -1 means unlimited, 0 means not available
class FeatureLimitsModel extends Equatable {
  /// Base limits (common across all account types)
  final BaseLimitsModel baseLimits;

  /// Tradesman-specific limits (null for non-tradesman accounts)
  final TradesmanLimitsModel? tradesmanLimits;

  /// Business-specific limits (null for non-business accounts)
  final BusinessLimitsModel? businessLimits;

  /// Customer-specific limits (null for non-customer accounts)
  final CustomerLimitsModel? customerLimits;

  const FeatureLimitsModel({
    this.baseLimits = const BaseLimitsModel(),
    this.tradesmanLimits,
    this.businessLimits,
    this.customerLimits,
  });

  // ============ BASE LIMITS GETTERS ============

  int get maxAddresses => baseLimits.maxAddresses;
  int get maxCustomers => baseLimits.maxCustomers;
  int get maxInvoices => baseLimits.maxInvoices;
  int get maxJobs => baseLimits.maxJobs;
  int get maxQuotations => baseLimits.maxQuotations;
  int get maxServices => baseLimits.maxServices;
  int get maxTemplates => baseLimits.maxTemplates;
  int get maxVoiceMinutesPerMonth => baseLimits.maxVoiceMinutesPerMonth;
  int get maxSuggestionsPerMonth => baseLimits.maxSuggestionsPerMonth;

  bool get isAddressesUnlimited => baseLimits.isAddressesUnlimited;
  bool get isCustomersUnlimited => baseLimits.isCustomersUnlimited;
  bool get isInvoicesUnlimited => baseLimits.isInvoicesUnlimited;
  bool get isJobsUnlimited => baseLimits.isJobsUnlimited;
  bool get isQuotationsUnlimited => baseLimits.isQuotationsUnlimited;
  bool get isServicesUnlimited => baseLimits.isServicesUnlimited;
  bool get isTemplatesUnlimited => baseLimits.isTemplatesUnlimited;
  bool get isVoiceMinutesUnlimited => baseLimits.isVoiceMinutesUnlimited;
  bool get isSuggestionsUnlimited => baseLimits.isSuggestionsUnlimited;

  bool canAddAddress(int currentCount) =>
      baseLimits.canAddAddress(currentCount);
  bool canAddCustomer(int currentCount) =>
      baseLimits.canAddCustomer(currentCount);
  bool canCreateInvoice(int currentCount) =>
      baseLimits.canCreateInvoice(currentCount);
  bool canCreateJob(int currentCount) => baseLimits.canCreateJob(currentCount);
  bool canCreateQuotation(int currentCount) =>
      baseLimits.canCreateQuotation(currentCount);
  bool canCreateService(int currentCount) =>
      baseLimits.canCreateService(currentCount);
  bool canCreateTemplate(int currentCount) =>
      baseLimits.canCreateTemplate(currentCount);
  bool canUseVoice(int usedSecondsThisMonth) =>
      baseLimits.canUseVoice(usedSecondsThisMonth);
  bool canUseSuggestion(int usedSuggestionsThisMonth) =>
      baseLimits.canUseSuggestion(usedSuggestionsThisMonth);
  int getRemainingVoiceSeconds(int usedSecondsThisMonth) =>
      baseLimits.getRemainingVoiceSeconds(usedSecondsThisMonth);

  // ============ TRADESMAN LIMITS GETTERS ============

  int get maxFreelanceHiresPerMonth =>
      tradesmanLimits?.maxFreelanceHiresPerMonth ?? 0;
  int get maxJobApplicationsPerMonth =>
      tradesmanLimits?.maxJobApplicationsPerMonth ?? -1;
  int get maxPhotoUploads => tradesmanLimits?.maxPhotoUploads ?? 5;
  int get maxVideoUploads => tradesmanLimits?.maxVideoUploads ?? 2;
  int get serviceRadiusMiles {
    if (businessLimits != null) return businessLimits!.serviceRadiusMiles;
    if (tradesmanLimits != null) return tradesmanLimits!.serviceRadiusMiles;
    return 5;
  }

  bool get hasFreelanceHiring => tradesmanLimits?.hasFreelanceHiring ?? false;
  bool get isFreelanceHiresUnlimited =>
      tradesmanLimits?.isFreelanceHiresUnlimited ?? false;
  bool get isJobApplicationsUnlimited =>
      tradesmanLimits?.isJobApplicationsUnlimited ?? false;
  bool get isPhotoUploadsUnlimited =>
      tradesmanLimits?.isPhotoUploadsUnlimited ?? false;
  bool get isVideoUploadsUnlimited =>
      tradesmanLimits?.isVideoUploadsUnlimited ?? false;
  bool get isServiceRadiusUnlimited {
    if (businessLimits != null) return businessLimits!.isServiceRadiusUnlimited;
    if (tradesmanLimits != null)
      return tradesmanLimits!.isServiceRadiusUnlimited;
    return false;
  }

  bool canHireFreelancer(int currentMonthlyHires) =>
      tradesmanLimits?.canHireFreelancer(currentMonthlyHires) ?? false;
  bool canApplyToJob(int currentMonthlyApplications) =>
      tradesmanLimits?.canApplyToJob(currentMonthlyApplications) ?? true;
  bool canUploadPhoto(int currentPhotoCount) =>
      tradesmanLimits?.canUploadPhoto(currentPhotoCount) ?? true;
  bool canUploadVideo(int currentVideoCount) =>
      tradesmanLimits?.canUploadVideo(currentVideoCount) ?? true;
  bool isJobWithinRadius(double distanceMiles) =>
      tradesmanLimits?.isJobWithinRadius(distanceMiles) ?? true;

  // ============ STAFF MANAGEMENT (BOTH TRADESMAN & BUSINESS) ============

  /// Get max staff members based on account type
  int get maxStaffMembers {
    if (businessLimits != null) return businessLimits!.maxStaffMembers;
    if (tradesmanLimits != null) return tradesmanLimits!.maxStaffMembers;
    return 0;
  }

  /// Check if staff management is available
  bool get hasStaffManagement {
    if (businessLimits != null) return true; // Business always has staff mgmt
    return tradesmanLimits?.hasStaffManagement ?? false;
  }

  /// Check if staff members limit is unlimited (-1)
  bool get isStaffMembersUnlimited => maxStaffMembers == -1;

  /// Check if user can add more staff members
  bool canAddStaff(int currentStaffCount) {
    if (businessLimits != null) {
      return businessLimits!.canAddStaff(currentStaffCount);
    }
    return tradesmanLimits?.canAddStaff(currentStaffCount) ?? false;
  }

  /// Format staff limit for display (e.g., "2/5" or "2/∞")
  String formatStaffLimit(int currentCount) {
    if (!hasStaffManagement) return 'Not available';
    if (isStaffMembersUnlimited) return '$currentCount/∞';
    return '$currentCount/$maxStaffMembers';
  }

  // ============ BUSINESS LIMITS GETTERS ============

  bool get apiAccess => businessLimits?.apiAccess ?? false;
  int get maxBranches => businessLimits?.maxBranches ?? 0;
  int get maxProjectsPerMonth => businessLimits?.maxProjectsPerMonth ?? 0;
  bool get prioritySupport => businessLimits?.prioritySupport ?? false;

  bool get isBranchesUnlimited => businessLimits?.isBranchesUnlimited ?? false;
  bool get isProjectsUnlimited => businessLimits?.isProjectsUnlimited ?? false;

  bool canAddBranch(int currentCount) =>
      businessLimits?.canAddBranch(currentCount) ?? false;
  bool canCreateProject(int currentMonthlyProjects) =>
      businessLimits?.canCreateProject(currentMonthlyProjects) ?? false;

  // ============ CUSTOMER LIMITS GETTERS ============

  int get maxScheduledTradesmenPerJob =>
      customerLimits?.maxScheduledTradesmenPerJob ?? 3;
  int get maxConcurrentScheduledVisits =>
      customerLimits?.maxConcurrentScheduledVisits ?? 2;
  int get maxCustomerCancellationsPerMonth =>
      customerLimits?.maxCancellationsPerMonth ?? 2;

  bool canScheduleMoreTradesmen(int currentCount) =>
      customerLimits?.canScheduleMoreTradesmen(currentCount) ?? true;
  bool canScheduleMoreVisits(int currentCount) =>
      customerLimits?.canScheduleMoreVisits(currentCount) ?? true;
  bool canCustomerCancelMore(int currentCancellations) =>
      customerLimits?.canCancelMore(currentCancellations) ?? true;

  // ============ TRADESMAN CANCELLATION LIMITS ============

  int get maxTradesmanCancellationsPerMonth =>
      tradesmanLimits?.maxCancellationsPerMonth ?? 2;
  bool canTradesmanCancelMore(int currentCancellations) =>
      tradesmanLimits?.canCancelMore(currentCancellations) ?? true;

  int get maxVisibleLeadsPerMonth =>
      tradesmanLimits?.maxVisibleLeadsPerMonth ?? 10;

  // ============ UTILITY METHODS ============

  /// Format limit display string
  String formatLimit(int limit) {
    if (limit == -1) return 'Unlimited';
    if (limit == 0) return 'Not available';
    return limit.toString();
  }

  /// Get remaining count for a limit
  /// Returns -1 for unlimited (-1 limits)
  int getRemainingCount(int currentCount, int maxLimit) {
    if (maxLimit == -1) return -1; // Unlimited
    if (maxLimit == 0) return 0; // Not available
    return maxLimit - currentCount;
  }

  FeatureLimitsModel copyWith({
    BaseLimitsModel? baseLimits,
    TradesmanLimitsModel? tradesmanLimits,
    BusinessLimitsModel? businessLimits,
    CustomerLimitsModel? customerLimits,
  }) {
    return FeatureLimitsModel(
      baseLimits: baseLimits ?? this.baseLimits,
      tradesmanLimits: tradesmanLimits ?? this.tradesmanLimits,
      businessLimits: businessLimits ?? this.businessLimits,
      customerLimits: customerLimits ?? this.customerLimits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseLimits': baseLimits.toJson(),
      if (tradesmanLimits != null) 'tradesmanLimits': tradesmanLimits!.toJson(),
      if (businessLimits != null) 'businessLimits': businessLimits!.toJson(),
      if (customerLimits != null) 'customerLimits': customerLimits!.toJson(),
    };
  }

  factory FeatureLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureLimitsModel();
    return FeatureLimitsModel(
      baseLimits: BaseLimitsModel.fromJson(
        json['baseLimits'] ?? json['limits'],
      ),
      tradesmanLimits: json['tradesmanLimits'] != null
          ? TradesmanLimitsModel.fromJson(json['tradesmanLimits'])
          : null,
      businessLimits: json['businessLimits'] != null
          ? BusinessLimitsModel.fromJson(json['businessLimits'])
          : null,
      customerLimits: json['customerLimits'] != null
          ? CustomerLimitsModel.fromJson(json['customerLimits'])
          : null,
    );
  }

  /// Create from subscription plan config JSON (Firebase format)
  factory FeatureLimitsModel.fromPlanConfig(Map<String, dynamic> planConfig) {
    return FeatureLimitsModel(
      baseLimits: BaseLimitsModel.fromJson(planConfig['limits']),
      tradesmanLimits: planConfig['tradesmanLimits'] != null
          ? TradesmanLimitsModel.fromJson(planConfig['tradesmanLimits'])
          : null,
      businessLimits: planConfig['businessLimits'] != null
          ? BusinessLimitsModel.fromJson(planConfig['businessLimits'])
          : null,
      customerLimits: planConfig['customerLimits'] != null
          ? CustomerLimitsModel.fromJson(planConfig['customerLimits'])
          : null,
    );
  }

  @override
  List<Object?> get props => [baseLimits, tradesmanLimits, businessLimits, customerLimits];
}
