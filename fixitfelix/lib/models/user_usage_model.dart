import 'package:equatable/equatable.dart';

import 'feature_limits_model.dart';

/// User's current usage stats against their subscription limits
class UserUsageModel extends Equatable {
  /// Current number of addresses
  final int addressCount;

  /// Current number of active jobs
  final int jobCount;

  /// Current number of invoices
  final int invoiceCount;

  /// Current number of quotations
  final int quotationCount;

  /// Current number of templates
  final int templateCount;

  /// Current number of services
  final int serviceCount;

  /// Current number of saved customers
  final int customerCount;

  /// Current number of job applications this month (for tradesman)
  final int jobApplicationsThisMonth;

  /// Current number of photo uploads (for tradesman)
  final int photoUploadCount;

  /// Current number of video uploads (for tradesman)
  final int videoUploadCount;

  /// Current number of staff members (for tradesman advance plan)
  final int staffCount;

  /// Current number of freelance hires this month (for tradesman advance plan)
  final int freelanceHiresThisMonth;

  /// Voice seconds used this month (for AI chat agent voice feature)
  final int voiceSecondsUsedThisMonth;

  /// Suggestions used this month (for AI chat agent suggestion taps)
  final int suggestionsUsedThisMonth;

  /// Cancellations this month (for customer cancellation policy)
  final int cancellationsThisMonth;

  /// Scheduled visits count (active, for customer visit caps)
  final int scheduledVisitsCount;

  /// Tradesman cancellations this month (for tradesman cancellation policy)
  final int tradesmanCancellationsThisMonth;

  /// Leads viewed this month (for tradesman max visible leads)
  final int leadsViewedThisMonth;

  /// Booking locked until date (for tradesman 28-day booking lock)
  final DateTime? bookingLockedUntil;

  /// The subscription limits
  final FeatureLimitsModel limits;

  const UserUsageModel({
    this.addressCount = 0,
    this.jobCount = 0,
    this.invoiceCount = 0,
    this.quotationCount = 0,
    this.templateCount = 0,
    this.serviceCount = 0,
    this.customerCount = 0,
    this.jobApplicationsThisMonth = 0,
    this.photoUploadCount = 0,
    this.videoUploadCount = 0,
    this.staffCount = 0,
    this.freelanceHiresThisMonth = 0,
    this.voiceSecondsUsedThisMonth = 0,
    this.suggestionsUsedThisMonth = 0,
    this.cancellationsThisMonth = 0,
    this.scheduledVisitsCount = 0,
    this.tradesmanCancellationsThisMonth = 0,
    this.leadsViewedThisMonth = 0,
    this.bookingLockedUntil,
    this.limits = const FeatureLimitsModel(),
  });

  /// Default empty usage
  static const UserUsageModel empty = UserUsageModel();

  /// Check if user has tradesman-specific limits
  bool get hasTradesmanLimits => limits.tradesmanLimits != null;

  /// Check if user has business-specific limits
  bool get hasBusinessLimits => limits.businessLimits != null;

  /// Check if user can add more addresses
  bool get canAddAddress => limits.canAddAddress(addressCount);

  /// Check if user can create more jobs
  bool get canCreateJob => limits.canCreateJob(jobCount);

  /// Check if user can create more invoices
  bool get canCreateInvoice => limits.canCreateInvoice(invoiceCount);

  /// Check if user can create more quotations
  bool get canCreateQuotation => limits.canCreateQuotation(quotationCount);

  /// Check if user can create more templates
  bool get canCreateTemplate => limits.canCreateTemplate(templateCount);

  /// Check if user can create more services
  bool get canCreateService => limits.canCreateService(serviceCount);

  /// Check if user can add more customers
  bool get canAddCustomer => limits.canAddCustomer(customerCount);

  /// Check if user can apply to more jobs this month
  bool get canApplyToJob => limits.canApplyToJob(jobApplicationsThisMonth);

  /// Check if user can upload more photos
  bool get canUploadPhoto => limits.canUploadPhoto(photoUploadCount);

  /// Check if user can upload more videos
  bool get canUploadVideo => limits.canUploadVideo(videoUploadCount);

  /// Check if user can add more staff members
  bool get canAddStaff => limits.canAddStaff(staffCount);

  /// Check if user can hire more freelancers this month
  bool get canHireFreelancer =>
      limits.canHireFreelancer(freelanceHiresThisMonth);

  /// Check if user can use voice (has remaining minutes this month)
  bool get canUseVoice => limits.canUseVoice(voiceSecondsUsedThisMonth);

  /// Check if user can use suggestions (has remaining taps this month)
  bool get canUseSuggestion =>
      limits.canUseSuggestion(suggestionsUsedThisMonth);

  /// Check if customer can cancel more jobs this month
  bool get canCancelJob => limits.canCustomerCancelMore(cancellationsThisMonth);

  /// Check if customer can schedule more visits
  bool get canScheduleVisit =>
      limits.canScheduleMoreVisits(scheduledVisitsCount);

  /// Check if tradesman can cancel more jobs this month
  bool get canTradesmanCancel =>
      limits.canTradesmanCancelMore(tradesmanCancellationsThisMonth);

  /// Check if tradesman is in booking lock period
  bool get isBookingLocked =>
      bookingLockedUntil != null && DateTime.now().isBefore(bookingLockedUntil!);

  /// Get remaining voice seconds (-1 for unlimited)
  int get remainingVoiceSeconds =>
      limits.getRemainingVoiceSeconds(voiceSecondsUsedThisMonth);

  /// Get remaining suggestions (-1 for unlimited)
  int get remainingSuggestions =>
      limits.getRemainingCount(suggestionsUsedThisMonth, limits.maxSuggestionsPerMonth);

  /// Get remaining addresses
  int get remainingAddresses =>
      limits.getRemainingCount(addressCount, limits.maxAddresses);

  /// Get remaining jobs
  int get remainingJobs => limits.getRemainingCount(jobCount, limits.maxJobs);

  /// Get remaining invoices
  int get remainingInvoices =>
      limits.getRemainingCount(invoiceCount, limits.maxInvoices);

  /// Get remaining quotations
  int get remainingQuotations =>
      limits.getRemainingCount(quotationCount, limits.maxQuotations);

  /// Get remaining templates
  int get remainingTemplates =>
      limits.getRemainingCount(templateCount, limits.maxTemplates);

  /// Get remaining services
  int get remainingServices =>
      limits.getRemainingCount(serviceCount, limits.maxServices);

  /// Get remaining customers
  int get remainingCustomers =>
      limits.getRemainingCount(customerCount, limits.maxCustomers);

  /// Get remaining job applications this month
  int get remainingJobApplications => limits.getRemainingCount(
    jobApplicationsThisMonth,
    limits.maxJobApplicationsPerMonth,
  );

  /// Get remaining photo uploads
  int get remainingPhotoUploads =>
      limits.getRemainingCount(photoUploadCount, limits.maxPhotoUploads);

  /// Get remaining video uploads
  int get remainingVideoUploads =>
      limits.getRemainingCount(videoUploadCount, limits.maxVideoUploads);

  /// Get remaining staff slots
  int get remainingStaffSlots =>
      limits.getRemainingCount(staffCount, limits.maxStaffMembers);

  /// Get remaining freelance hires this month
  int get remainingFreelanceHires => limits.getRemainingCount(
    freelanceHiresThisMonth,
    limits.maxFreelanceHiresPerMonth,
  );

  /// Get usage percentage for addresses (0-100)
  double get addressUsagePercentage => limits.isAddressesUnlimited
      ? 0
      : (addressCount / limits.maxAddresses) * 100;

  /// Get usage percentage for jobs (0-100)
  double get jobUsagePercentage =>
      limits.isJobsUnlimited ? 0 : (jobCount / limits.maxJobs) * 100;

  /// Get usage percentage for invoices (0-100)
  double get invoiceUsagePercentage => limits.isInvoicesUnlimited
      ? 0
      : (invoiceCount / limits.maxInvoices) * 100;

  /// Get usage percentage for quotations (0-100)
  double get quotationUsagePercentage => limits.isQuotationsUnlimited
      ? 0
      : (quotationCount / limits.maxQuotations) * 100;

  /// Get usage percentage for templates (0-100)
  double get templateUsagePercentage => limits.isTemplatesUnlimited
      ? 0
      : (templateCount / limits.maxTemplates) * 100;

  /// Get usage percentage for services (0-100)
  double get serviceUsagePercentage => limits.isServicesUnlimited
      ? 0
      : (serviceCount / limits.maxServices) * 100;

  /// Get usage percentage for customers (0-100)
  double get customerUsagePercentage => limits.isCustomersUnlimited
      ? 0
      : (customerCount / limits.maxCustomers) * 100;

  /// Get usage percentage for job applications (0-100)
  double get jobApplicationUsagePercentage => limits.isJobApplicationsUnlimited
      ? 0
      : (jobApplicationsThisMonth / limits.maxJobApplicationsPerMonth) * 100;

  /// Get usage percentage for photo uploads (0-100)
  double get photoUploadUsagePercentage => limits.isPhotoUploadsUnlimited
      ? 0
      : (photoUploadCount / limits.maxPhotoUploads) * 100;

  /// Get usage percentage for video uploads (0-100)
  double get videoUploadUsagePercentage => limits.isVideoUploadsUnlimited
      ? 0
      : (videoUploadCount / limits.maxVideoUploads) * 100;

  /// Format usage string (e.g., "2/5" or "5/Unlimited")
  String formatUsage(int current, int max) {
    return max == -1 ? '$current/Unlimited' : '$current/$max';
  }

  /// Get address usage string
  String get addressUsageString =>
      formatUsage(addressCount, limits.maxAddresses);

  /// Get job usage string
  String get jobUsageString => formatUsage(jobCount, limits.maxJobs);

  /// Get invoice usage string
  String get invoiceUsageString =>
      formatUsage(invoiceCount, limits.maxInvoices);

  /// Get quotation usage string
  String get quotationUsageString =>
      formatUsage(quotationCount, limits.maxQuotations);

  /// Get template usage string
  String get templateUsageString =>
      formatUsage(templateCount, limits.maxTemplates);

  /// Get service usage string
  String get serviceUsageString =>
      formatUsage(serviceCount, limits.maxServices);

  /// Get customer usage string
  String get customerUsageString =>
      formatUsage(customerCount, limits.maxCustomers);

  /// Get job applications usage string
  String get jobApplicationUsageString =>
      formatUsage(jobApplicationsThisMonth, limits.maxJobApplicationsPerMonth);

  /// Get photo uploads usage string
  String get photoUploadUsageString =>
      formatUsage(photoUploadCount, limits.maxPhotoUploads);

  /// Get video uploads usage string
  String get videoUploadUsageString =>
      formatUsage(videoUploadCount, limits.maxVideoUploads);

  /// Get staff usage string
  String get staffUsageString =>
      formatUsage(staffCount, limits.maxStaffMembers);

  /// Get freelance hires usage string
  String get freelanceHiresUsageString =>
      formatUsage(freelanceHiresThisMonth, limits.maxFreelanceHiresPerMonth);

  /// Get voice usage percentage (0-100)
  double get voiceUsagePercentage => limits.isVoiceMinutesUnlimited
      ? 0
      : (voiceSecondsUsedThisMonth /
              (limits.maxVoiceMinutesPerMonth * 60)) *
          100;

  /// Get suggestion usage percentage (0-100)
  double get suggestionUsagePercentage => limits.isSuggestionsUnlimited
      ? 0
      : (suggestionsUsedThisMonth / limits.maxSuggestionsPerMonth) * 100;

  /// Get voice usage string (e.g., "2:30/5:00 min" or "2:30/Unlimited")
  String get voiceUsageString {
    final usedMin = voiceSecondsUsedThisMonth ~/ 60;
    final usedSec = voiceSecondsUsedThisMonth % 60;
    final used = '$usedMin:${usedSec.toString().padLeft(2, '0')}';
    if (limits.isVoiceMinutesUnlimited) return '$used/Unlimited';
    return '$used/${limits.maxVoiceMinutesPerMonth}:00 min';
  }

  /// Get suggestion usage string
  String get suggestionUsageString =>
      formatUsage(suggestionsUsedThisMonth, limits.maxSuggestionsPerMonth);

  /// Get service radius display string (e.g., "5 miles" or "Unlimited")
  String get serviceRadiusString => limits.isServiceRadiusUnlimited
      ? 'Unlimited'
      : '${limits.serviceRadiusMiles} miles';

  UserUsageModel copyWith({
    int? addressCount,
    int? jobCount,
    int? invoiceCount,
    int? quotationCount,
    int? templateCount,
    int? serviceCount,
    int? customerCount,
    int? jobApplicationsThisMonth,
    int? photoUploadCount,
    int? videoUploadCount,
    int? staffCount,
    int? freelanceHiresThisMonth,
    int? voiceSecondsUsedThisMonth,
    int? suggestionsUsedThisMonth,
    int? cancellationsThisMonth,
    int? scheduledVisitsCount,
    int? tradesmanCancellationsThisMonth,
    int? leadsViewedThisMonth,
    DateTime? bookingLockedUntil,
    FeatureLimitsModel? limits,
  }) {
    return UserUsageModel(
      addressCount: addressCount ?? this.addressCount,
      jobCount: jobCount ?? this.jobCount,
      invoiceCount: invoiceCount ?? this.invoiceCount,
      quotationCount: quotationCount ?? this.quotationCount,
      templateCount: templateCount ?? this.templateCount,
      serviceCount: serviceCount ?? this.serviceCount,
      customerCount: customerCount ?? this.customerCount,
      jobApplicationsThisMonth:
          jobApplicationsThisMonth ?? this.jobApplicationsThisMonth,
      photoUploadCount: photoUploadCount ?? this.photoUploadCount,
      videoUploadCount: videoUploadCount ?? this.videoUploadCount,
      staffCount: staffCount ?? this.staffCount,
      freelanceHiresThisMonth:
          freelanceHiresThisMonth ?? this.freelanceHiresThisMonth,
      voiceSecondsUsedThisMonth:
          voiceSecondsUsedThisMonth ?? this.voiceSecondsUsedThisMonth,
      suggestionsUsedThisMonth:
          suggestionsUsedThisMonth ?? this.suggestionsUsedThisMonth,
      cancellationsThisMonth:
          cancellationsThisMonth ?? this.cancellationsThisMonth,
      scheduledVisitsCount:
          scheduledVisitsCount ?? this.scheduledVisitsCount,
      tradesmanCancellationsThisMonth:
          tradesmanCancellationsThisMonth ?? this.tradesmanCancellationsThisMonth,
      leadsViewedThisMonth:
          leadsViewedThisMonth ?? this.leadsViewedThisMonth,
      bookingLockedUntil: bookingLockedUntil ?? this.bookingLockedUntil,
      limits: limits ?? this.limits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addressCount': addressCount,
      'jobCount': jobCount,
      'invoiceCount': invoiceCount,
      'quotationCount': quotationCount,
      'templateCount': templateCount,
      'serviceCount': serviceCount,
      'customerCount': customerCount,
      'jobApplicationsThisMonth': jobApplicationsThisMonth,
      'photoUploadCount': photoUploadCount,
      'videoUploadCount': videoUploadCount,
      'staffCount': staffCount,
      'freelanceHiresThisMonth': freelanceHiresThisMonth,
      'voiceSecondsUsedThisMonth': voiceSecondsUsedThisMonth,
      'suggestionsUsedThisMonth': suggestionsUsedThisMonth,
      'cancellationsThisMonth': cancellationsThisMonth,
      'scheduledVisitsCount': scheduledVisitsCount,
      'tradesmanCancellationsThisMonth': tradesmanCancellationsThisMonth,
      'leadsViewedThisMonth': leadsViewedThisMonth,
      'bookingLockedUntil': bookingLockedUntil?.toIso8601String(),
      'limits': limits.toJson(),
    };
  }

  factory UserUsageModel.fromJson(Map<String, dynamic> json) {
    return UserUsageModel(
      addressCount: json['addressCount'] ?? 0,
      jobCount: json['jobCount'] ?? 0,
      invoiceCount: json['invoiceCount'] ?? 0,
      quotationCount: json['quotationCount'] ?? 0,
      templateCount: json['templateCount'] ?? 0,
      serviceCount: json['serviceCount'] ?? 0,
      customerCount: json['customerCount'] ?? 0,
      jobApplicationsThisMonth: json['jobApplicationsThisMonth'] ?? 0,
      photoUploadCount: json['photoUploadCount'] ?? 0,
      videoUploadCount: json['videoUploadCount'] ?? 0,
      staffCount: json['staffCount'] ?? 0,
      freelanceHiresThisMonth: json['freelanceHiresThisMonth'] ?? 0,
      voiceSecondsUsedThisMonth: json['voiceSecondsUsedThisMonth'] ?? 0,
      suggestionsUsedThisMonth: json['suggestionsUsedThisMonth'] ?? 0,
      cancellationsThisMonth: json['cancellationsThisMonth'] ?? 0,
      scheduledVisitsCount: json['scheduledVisitsCount'] ?? 0,
      tradesmanCancellationsThisMonth: json['tradesmanCancellationsThisMonth'] ?? 0,
      leadsViewedThisMonth: json['leadsViewedThisMonth'] ?? 0,
      bookingLockedUntil: json['bookingLockedUntil'] != null
          ? DateTime.tryParse(json['bookingLockedUntil'])
          : null,
      limits: json['limits'] != null
          ? FeatureLimitsModel.fromJson(json['limits'])
          : const FeatureLimitsModel(),
    );
  }

  @override
  List<Object?> get props => [
    addressCount,
    jobCount,
    invoiceCount,
    quotationCount,
    templateCount,
    serviceCount,
    customerCount,
    jobApplicationsThisMonth,
    photoUploadCount,
    videoUploadCount,
    staffCount,
    freelanceHiresThisMonth,
    voiceSecondsUsedThisMonth,
    suggestionsUsedThisMonth,
    cancellationsThisMonth,
    scheduledVisitsCount,
    tradesmanCancellationsThisMonth,
    leadsViewedThisMonth,
    bookingLockedUntil,
    limits,
  ];
}
