import 'package:equatable/equatable.dart';

/// Base limits model for common subscription limits
/// Used across all account types (customer, tradesman, business)
class BaseLimitsModel extends Equatable {
  /// Maximum number of addresses allowed (-1 = unlimited)
  final int maxAddresses;

  /// Maximum number of customers allowed (-1 = unlimited, 0 = not available)
  final int maxCustomers;

  /// Maximum number of invoices allowed (-1 = unlimited, 0 = not available)
  final int maxInvoices;

  /// Maximum number of jobs allowed (-1 = unlimited)
  final int maxJobs;

  /// Maximum number of quotations allowed (-1 = unlimited, 0 = not available)
  final int maxQuotations;

  /// Maximum number of services allowed (-1 = unlimited, 0 = not available)
  final int maxServices;

  /// Maximum number of templates allowed (-1 = unlimited, 0 = not available)
  final int maxTemplates;

  /// Maximum voice minutes per month (-1 = unlimited, 0 = not available)
  final int maxVoiceMinutesPerMonth;

  /// Maximum suggestion taps per month (-1 = unlimited, 0 = not available)
  final int maxSuggestionsPerMonth;

  const BaseLimitsModel({
    this.maxAddresses = 1,
    this.maxCustomers = 0,
    this.maxInvoices = 0,
    this.maxJobs = 2,
    this.maxQuotations = 0,
    this.maxServices = 0,
    this.maxTemplates = 0,
    this.maxVoiceMinutesPerMonth = 5,
    this.maxSuggestionsPerMonth = 20,
  });

  /// Check if addresses limit is unlimited (-1)
  bool get isAddressesUnlimited => maxAddresses == -1;

  /// Check if customers limit is unlimited (-1)
  bool get isCustomersUnlimited => maxCustomers == -1;

  /// Check if invoices limit is unlimited (-1)
  bool get isInvoicesUnlimited => maxInvoices == -1;

  /// Check if jobs limit is unlimited (-1)
  bool get isJobsUnlimited => maxJobs == -1;

  /// Check if quotations limit is unlimited (-1)
  bool get isQuotationsUnlimited => maxQuotations == -1;

  /// Check if services limit is unlimited (-1)
  bool get isServicesUnlimited => maxServices == -1;

  /// Check if templates limit is unlimited (-1)
  bool get isTemplatesUnlimited => maxTemplates == -1;

  /// Check if voice minutes limit is unlimited (-1)
  bool get isVoiceMinutesUnlimited => maxVoiceMinutesPerMonth == -1;

  /// Check if suggestions limit is unlimited (-1)
  bool get isSuggestionsUnlimited => maxSuggestionsPerMonth == -1;

  /// Check if user can use more voice minutes
  bool canUseVoice(int usedSecondsThisMonth) =>
      maxVoiceMinutesPerMonth != 0 &&
      (isVoiceMinutesUnlimited ||
          usedSecondsThisMonth < maxVoiceMinutesPerMonth * 60);

  /// Check if user can use more suggestions
  bool canUseSuggestion(int usedSuggestionsThisMonth) =>
      maxSuggestionsPerMonth != 0 &&
      (isSuggestionsUnlimited ||
          usedSuggestionsThisMonth < maxSuggestionsPerMonth);

  /// Get remaining voice seconds (-1 for unlimited)
  int getRemainingVoiceSeconds(int usedSecondsThisMonth) {
    if (isVoiceMinutesUnlimited) return -1;
    if (maxVoiceMinutesPerMonth == 0) return 0;
    return (maxVoiceMinutesPerMonth * 60) - usedSecondsThisMonth;
  }

  /// Check if user can add more addresses
  bool canAddAddress(int currentCount) =>
      isAddressesUnlimited || currentCount < maxAddresses;

  /// Check if user can add more customers
  bool canAddCustomer(int currentCount) =>
      maxCustomers != 0 &&
      (isCustomersUnlimited || currentCount < maxCustomers);

  /// Check if user can create more invoices
  bool canCreateInvoice(int currentCount) =>
      maxInvoices != 0 && (isInvoicesUnlimited || currentCount < maxInvoices);

  /// Check if user can create more jobs
  bool canCreateJob(int currentCount) =>
      isJobsUnlimited || currentCount < maxJobs;

  /// Check if user can create more quotations
  bool canCreateQuotation(int currentCount) =>
      maxQuotations != 0 &&
      (isQuotationsUnlimited || currentCount < maxQuotations);

  /// Check if user can create more services
  bool canCreateService(int currentCount) =>
      maxServices != 0 && (isServicesUnlimited || currentCount < maxServices);

  /// Check if user can create more templates
  bool canCreateTemplate(int currentCount) =>
      maxTemplates != 0 &&
      (isTemplatesUnlimited || currentCount < maxTemplates);

  /// Format limit display string
  String formatLimit(int limit) {
    if (limit == -1) return 'Unlimited';
    if (limit == 0) return 'Not available';
    return limit.toString();
  }

  BaseLimitsModel copyWith({
    int? maxAddresses,
    int? maxCustomers,
    int? maxInvoices,
    int? maxJobs,
    int? maxQuotations,
    int? maxServices,
    int? maxTemplates,
    int? maxVoiceMinutesPerMonth,
    int? maxSuggestionsPerMonth,
  }) {
    return BaseLimitsModel(
      maxAddresses: maxAddresses ?? this.maxAddresses,
      maxCustomers: maxCustomers ?? this.maxCustomers,
      maxInvoices: maxInvoices ?? this.maxInvoices,
      maxJobs: maxJobs ?? this.maxJobs,
      maxQuotations: maxQuotations ?? this.maxQuotations,
      maxServices: maxServices ?? this.maxServices,
      maxTemplates: maxTemplates ?? this.maxTemplates,
      maxVoiceMinutesPerMonth:
          maxVoiceMinutesPerMonth ?? this.maxVoiceMinutesPerMonth,
      maxSuggestionsPerMonth:
          maxSuggestionsPerMonth ?? this.maxSuggestionsPerMonth,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxAddresses': maxAddresses,
      'maxCustomers': maxCustomers,
      'maxInvoices': maxInvoices,
      'maxJobs': maxJobs,
      'maxQuotations': maxQuotations,
      'maxServices': maxServices,
      'maxTemplates': maxTemplates,
      'maxVoiceMinutesPerMonth': maxVoiceMinutesPerMonth,
      'maxSuggestionsPerMonth': maxSuggestionsPerMonth,
    };
  }

  factory BaseLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BaseLimitsModel();
    return BaseLimitsModel(
      maxAddresses: json['maxAddresses'] ?? 1,
      maxCustomers: json['maxCustomers'] ?? 0,
      maxInvoices: json['maxInvoices'] ?? 0,
      maxJobs: json['maxJobs'] ?? 2,
      maxQuotations: json['maxQuotations'] ?? 0,
      maxServices: json['maxServices'] ?? 0,
      maxTemplates: json['maxTemplates'] ?? 0,
      maxVoiceMinutesPerMonth: json['maxVoiceMinutesPerMonth'] ?? 5,
      maxSuggestionsPerMonth: json['maxSuggestionsPerMonth'] ?? 20,
    );
  }

  @override
  List<Object?> get props => [
    maxAddresses,
    maxCustomers,
    maxInvoices,
    maxJobs,
    maxQuotations,
    maxServices,
    maxTemplates,
    maxVoiceMinutesPerMonth,
    maxSuggestionsPerMonth,
  ];
}
