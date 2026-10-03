import 'package:equatable/equatable.dart';

import '../../models/user_usage_model.dart';

enum UsageStateStatus { initial, loading, loaded, error }

class UsageState extends Equatable {
  final UsageStateStatus status;
  final UserUsageModel usage;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const UsageState({
    this.status = UsageStateStatus.initial,
    this.usage = UserUsageModel.empty,
    this.errorMessage,
    this.lastUpdated,
  });

  /// Initial state
  static const initial = UsageState();

  /// Check if user can add more addresses
  bool get canAddAddress => usage.canAddAddress;

  /// Check if user can create more jobs
  bool get canCreateJob => usage.canCreateJob;

  /// Check if user can create more invoices
  bool get canCreateInvoice => usage.canCreateInvoice;

  /// Check if user can create more quotations
  bool get canCreateQuotation => usage.canCreateQuotation;

  /// Check if user can create more templates
  bool get canCreateTemplate => usage.canCreateTemplate;

  /// Check if user can create more services
  bool get canCreateService => usage.canCreateService;

  /// Check if user can add more customers
  bool get canAddCustomer => usage.canAddCustomer;

  /// Check if user can apply to more jobs this month
  bool get canApplyToJob => usage.canApplyToJob;

  /// Check if user can upload more photos
  bool get canUploadPhoto => usage.canUploadPhoto;

  /// Check if user can upload more videos
  bool get canUploadVideo => usage.canUploadVideo;

  /// Check if user can add more staff members
  bool get canAddStaff => usage.canAddStaff;

  /// Check if user can hire more freelancers this month
  bool get canHireFreelancer => usage.canHireFreelancer;

  /// Check if user can use voice (has remaining minutes this month)
  bool get canUseVoice => usage.canUseVoice;

  /// Check if user can use suggestions (has remaining taps this month)
  bool get canUseSuggestion => usage.canUseSuggestion;

  /// Get limit reached message for addresses
  String get addressLimitMessage =>
      'Address limit reached. Your plan allows up to ${usage.limits.maxAddresses} address(es). Please upgrade your plan to add more.';

  /// Get limit reached message for jobs
  String get jobLimitMessage =>
      'Job limit reached. Your plan allows up to ${usage.limits.maxJobs} active job(s). Please complete or cancel existing jobs, or upgrade your plan.';

  /// Get limit reached message for invoices
  String get invoiceLimitMessage =>
      'Invoice limit reached. Your plan allows up to ${usage.limits.maxInvoices} invoice(s). Please upgrade your plan to create more.';

  /// Get limit reached message for quotations
  String get quotationLimitMessage =>
      'Quotation limit reached. Your plan allows up to ${usage.limits.maxQuotations} quotation(s). Please upgrade your plan to create more.';

  /// Get limit reached message for templates
  String get templateLimitMessage =>
      'Template limit reached. Your plan allows up to ${usage.limits.maxTemplates} template(s). Please upgrade your plan to create more.';

  /// Get limit reached message for services
  String get serviceLimitMessage =>
      'Service limit reached. Your plan allows up to ${usage.limits.maxServices} service(s). Please upgrade your plan to create more.';

  /// Get limit reached message for customers
  String get customerLimitMessage =>
      'Customer limit reached. Your plan allows up to ${usage.limits.maxCustomers} saved customer(s). Please upgrade your plan to add more.';

  /// Get limit reached message for job applications
  String get jobApplicationLimitMessage =>
      'Job application limit reached. Your plan allows up to ${usage.limits.maxJobApplicationsPerMonth} job application(s) per month. Please upgrade your plan to apply to more jobs.';

  /// Get limit reached message for photo uploads
  String get photoUploadLimitMessage =>
      'Photo upload limit reached. Your plan allows up to ${usage.limits.maxPhotoUploads} photo(s). Please upgrade your plan to upload more.';

  /// Get limit reached message for video uploads
  String get videoUploadLimitMessage =>
      'Video upload limit reached. Your plan allows up to ${usage.limits.maxVideoUploads} short video(s) (30s). Please upgrade your plan to upload more.';

  /// Get limit reached message for staff
  String get staffLimitMessage {
    if (!usage.limits.hasStaffManagement) {
      return 'Staff management is not available on your current plan. Please upgrade to Advance plan to manage staff.';
    }
    return 'Staff limit reached. Your plan allows up to ${usage.limits.maxStaffMembers} staff member(s). Please upgrade your plan to add more.';
  }

  /// Get limit reached message for freelance hires
  String get freelanceHireLimitMessage {
    if (!usage.limits.hasFreelanceHiring) {
      return 'Freelance hiring is not available on your current plan. Please upgrade to Advance plan to hire freelancers.';
    }
    return 'Freelance hire limit reached. Your plan allows up to ${usage.limits.maxFreelanceHiresPerMonth} freelance hire(s) per month. Please upgrade your plan to hire more.';
  }

  /// Get limit reached message for voice minutes
  String get voiceLimitMessage =>
      'Voice limit reached. Your plan allows ${usage.limits.maxVoiceMinutesPerMonth} minute(s) of voice per month. Please upgrade your plan for more voice time.';

  /// Get limit reached message for suggestions
  String get suggestionLimitMessage =>
      'Suggestion limit reached. Your plan allows ${usage.limits.maxSuggestionsPerMonth} suggestion(s) per month. Please upgrade your plan for more suggestions.';

  /// Get service radius display message
  String get serviceRadiusMessage {
    if (usage.limits.isServiceRadiusUnlimited) {
      return 'You have unlimited service radius.';
    }
    return 'Your service radius is ${usage.limits.serviceRadiusMiles} miles. Upgrade to see jobs farther away.';
  }

  UsageState copyWith({
    UsageStateStatus? status,
    UserUsageModel? usage,
    String? errorMessage,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return UsageState(
      status: status ?? this.status,
      usage: usage ?? this.usage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [status, usage, errorMessage, lastUpdated];
}
