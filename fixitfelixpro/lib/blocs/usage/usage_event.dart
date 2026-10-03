import 'package:equatable/equatable.dart';

import '../../models/user_usage_model.dart';

abstract class UsageEvent extends Equatable {
  const UsageEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load user usage stats
class UsageLoadRequested extends UsageEvent {
  const UsageLoadRequested();
}

/// Event to refresh user usage stats
class UsageRefreshRequested extends UsageEvent {
  const UsageRefreshRequested();
}

/// Event when usage stats are updated (from stream)
class UsageUpdated extends UsageEvent {
  final UserUsageModel usage;

  const UsageUpdated(this.usage);

  @override
  List<Object?> get props => [usage];
}

/// Event to start watching usage stats in realtime
class UsageStartWatching extends UsageEvent {
  const UsageStartWatching();
}

/// Event to stop watching usage stats
class UsageStopWatching extends UsageEvent {
  const UsageStopWatching();
}

/// Event to clear usage cache
class UsageClearCacheRequested extends UsageEvent {
  const UsageClearCacheRequested();
}

/// Event to check if a specific action is allowed
class UsageCheckRequested extends UsageEvent {
  final UsageCheckType checkType;

  const UsageCheckRequested(this.checkType);

  @override
  List<Object?> get props => [checkType];
}

/// Types of usage checks
enum UsageCheckType {
  address,
  job,
  invoice,
  quotation,
  template,
  service,
  customer,
}

/// Event to increment a usage count
class UsageIncrementRequested extends UsageEvent {
  final UsageCheckType countType;

  const UsageIncrementRequested(this.countType);

  @override
  List<Object?> get props => [countType];
}

/// Event to decrement a usage count
class UsageDecrementRequested extends UsageEvent {
  final UsageCheckType countType;

  const UsageDecrementRequested(this.countType);

  @override
  List<Object?> get props => [countType];
}

/// Event to save usage stats to database
class UsageSaveRequested extends UsageEvent {
  final UserUsageModel usage;

  const UsageSaveRequested(this.usage);

  @override
  List<Object?> get props => [usage];
}
