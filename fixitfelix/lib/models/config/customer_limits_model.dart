import 'package:equatable/equatable.dart';

/// Customer-specific limits model
/// Contains limits that control customer behaviour on the platform
/// Uses the same convention: -1 = unlimited, 0 = not available, n = limit
class CustomerLimitsModel extends Equatable {
  /// Maximum tradesmen that can be scheduled for a single job (default 3)
  final int maxScheduledTradesmenPerJob;

  /// Maximum concurrent scheduled visits across all active jobs (default 2)
  final int maxConcurrentScheduledVisits;

  /// Maximum cancellations allowed per month (default 2)
  final int maxCancellationsPerMonth;

  const CustomerLimitsModel({
    this.maxScheduledTradesmenPerJob = 3,
    this.maxConcurrentScheduledVisits = 2,
    this.maxCancellationsPerMonth = 2,
  });

  /// Check if scheduling limit is unlimited
  bool get isScheduledTradesmenUnlimited => maxScheduledTradesmenPerJob == -1;

  /// Check if concurrent visits limit is unlimited
  bool get isConcurrentVisitsUnlimited => maxConcurrentScheduledVisits == -1;

  /// Check if cancellation limit is unlimited
  bool get isCancellationsUnlimited => maxCancellationsPerMonth == -1;

  /// Check if customer can schedule more tradesmen for a specific job
  bool canScheduleMoreTradesmen(int currentScheduledCount) =>
      isScheduledTradesmenUnlimited ||
      currentScheduledCount < maxScheduledTradesmenPerJob;

  /// Check if customer can schedule more concurrent visits
  bool canScheduleMoreVisits(int currentVisitCount) =>
      isConcurrentVisitsUnlimited ||
      currentVisitCount < maxConcurrentScheduledVisits;

  /// Check if customer can cancel more jobs this month
  bool canCancelMore(int currentCancellations) =>
      isCancellationsUnlimited ||
      currentCancellations < maxCancellationsPerMonth;

  CustomerLimitsModel copyWith({
    int? maxScheduledTradesmenPerJob,
    int? maxConcurrentScheduledVisits,
    int? maxCancellationsPerMonth,
  }) {
    return CustomerLimitsModel(
      maxScheduledTradesmenPerJob:
          maxScheduledTradesmenPerJob ?? this.maxScheduledTradesmenPerJob,
      maxConcurrentScheduledVisits:
          maxConcurrentScheduledVisits ?? this.maxConcurrentScheduledVisits,
      maxCancellationsPerMonth:
          maxCancellationsPerMonth ?? this.maxCancellationsPerMonth,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxScheduledTradesmenPerJob': maxScheduledTradesmenPerJob,
      'maxConcurrentScheduledVisits': maxConcurrentScheduledVisits,
      'maxCancellationsPerMonth': maxCancellationsPerMonth,
    };
  }

  factory CustomerLimitsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerLimitsModel();
    return CustomerLimitsModel(
      maxScheduledTradesmenPerJob: json['maxScheduledTradesmenPerJob'] ?? 3,
      maxConcurrentScheduledVisits: json['maxConcurrentScheduledVisits'] ?? 2,
      maxCancellationsPerMonth: json['maxCancellationsPerMonth'] ?? 2,
    );
  }

  @override
  List<Object?> get props => [
    maxScheduledTradesmenPerJob,
    maxConcurrentScheduledVisits,
    maxCancellationsPerMonth,
  ];
}
