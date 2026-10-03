import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/usage/base_usage_repository.dart';
import '../../repositories/usage/usage_repository.dart';
import 'usage_event.dart';
import 'usage_state.dart';

class UsageBloc extends Bloc<UsageEvent, UsageState> {
  final UsageRepository _usageRepository;
  StreamSubscription? _usageSubscription;

  UsageBloc({required UsageRepository usageRepository})
    : _usageRepository = usageRepository,
      super(UsageState.initial) {
    on<UsageLoadRequested>(_onUsageLoadRequested);
    on<UsageRefreshRequested>(_onUsageRefreshRequested);
    on<UsageUpdated>(_onUsageUpdated);
    on<UsageClearCacheRequested>(_onUsageClearCacheRequested);
    on<UsageCheckRequested>(_onUsageCheckRequested);
    on<UsageIncrementRequested>(_onUsageIncrementRequested);
    on<UsageDecrementRequested>(_onUsageDecrementRequested);
    on<UsageSaveRequested>(_onUsageSaveRequested);
    on<UsageStartWatching>(_onUsageStartWatching);
    on<UsageStopWatching>(_onUsageStopWatching);

    // Load cached data immediately
    _loadCachedData();
  }

  void _onUsageStartWatching(
    UsageStartWatching event,
    Emitter<UsageState> emit,
  ) {
    _usageSubscription?.cancel();
    _usageSubscription = _usageRepository.watchUsageStats().listen(
      (usage) {
        add(UsageUpdated(usage));
      },
      onError: (error) {
        debugPrint('Error watching usage stats: $error');
      },
    );
  }

  void _onUsageStopWatching(UsageStopWatching event, Emitter<UsageState> emit) {
    _usageSubscription?.cancel();
    _usageSubscription = null;
  }

  void _loadCachedData() {
    final cachedUsage = _usageRepository.getCachedUsageStats();
    if (cachedUsage != null) {
      // ignore: invalid_use_of_visible_for_testing_member
      emit(state.copyWith(status: UsageStateStatus.loaded, usage: cachedUsage));
    }
  }

  Future<void> _onUsageLoadRequested(
    UsageLoadRequested event,
    Emitter<UsageState> emit,
  ) async {
    try {
      // Only show loading if we don't have cached data
      if (state.status == UsageStateStatus.initial) {
        emit(state.copyWith(status: UsageStateStatus.loading));
      }

      final usage = await _usageRepository.getUserUsageStats();

      emit(
        state.copyWith(
          status: UsageStateStatus.loaded,
          usage: usage,
          lastUpdated: DateTime.now(),
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error loading usage stats: $e');
      emit(
        state.copyWith(
          status: UsageStateStatus.error,
          errorMessage: 'Failed to load usage stats',
        ),
      );
    }
  }

  Future<void> _onUsageRefreshRequested(
    UsageRefreshRequested event,
    Emitter<UsageState> emit,
  ) async {
    try {
      final usage = await _usageRepository.getUserUsageStats();

      emit(
        state.copyWith(
          status: UsageStateStatus.loaded,
          usage: usage,
          lastUpdated: DateTime.now(),
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error refreshing usage stats: $e');
      // Keep existing data on refresh error
    }
  }

  Future<void> _onUsageUpdated(
    UsageUpdated event,
    Emitter<UsageState> emit,
  ) async {
    // Update state with new usage from stream
    emit(
      state.copyWith(
        status: UsageStateStatus.loaded,
        usage: event.usage,
        lastUpdated: DateTime.now(),
        clearError: true,
      ),
    );
  }

  Future<void> _onUsageClearCacheRequested(
    UsageClearCacheRequested event,
    Emitter<UsageState> emit,
  ) async {
    await _usageRepository.clearCache();
    emit(UsageState.initial);
  }

  Future<void> _onUsageCheckRequested(
    UsageCheckRequested event,
    Emitter<UsageState> emit,
  ) async {
    // Refresh usage before checking
    await _usageRepository.getUserUsageStats();
    add(const UsageRefreshRequested());
  }

  /// Convert UsageCheckType to UsageCountType
  UsageCountType _toCountType(UsageCheckType checkType) {
    switch (checkType) {
      case UsageCheckType.address:
        return UsageCountType.address;
      case UsageCheckType.job:
        return UsageCountType.job;
      case UsageCheckType.invoice:
        return UsageCountType.invoice;
      case UsageCheckType.quotation:
        return UsageCountType.quotation;
      case UsageCheckType.template:
        return UsageCountType.template;
      case UsageCheckType.service:
        return UsageCountType.service;
      case UsageCheckType.customer:
        return UsageCountType.customer;
    }
  }

  Future<void> _onUsageIncrementRequested(
    UsageIncrementRequested event,
    Emitter<UsageState> emit,
  ) async {
    try {
      final countType = _toCountType(event.countType);
      await _usageRepository.incrementUsageCount(countType);
      // Refresh usage stats after increment
      add(const UsageRefreshRequested());
    } catch (e) {
      debugPrint('Error incrementing usage: $e');
    }
  }

  Future<void> _onUsageDecrementRequested(
    UsageDecrementRequested event,
    Emitter<UsageState> emit,
  ) async {
    try {
      final countType = _toCountType(event.countType);
      await _usageRepository.decrementUsageCount(countType);
      // Refresh usage stats after decrement
      add(const UsageRefreshRequested());
    } catch (e) {
      debugPrint('Error decrementing usage: $e');
    }
  }

  Future<void> _onUsageSaveRequested(
    UsageSaveRequested event,
    Emitter<UsageState> emit,
  ) async {
    try {
      await _usageRepository.saveUsageStats(event.usage);
      // Update state with saved usage
      emit(
        state.copyWith(
          status: UsageStateStatus.loaded,
          usage: event.usage,
          lastUpdated: DateTime.now(),
          clearError: true,
        ),
      );
    } catch (e) {
      debugPrint('Error saving usage stats: $e');
      emit(
        state.copyWith(
          status: UsageStateStatus.error,
          errorMessage: 'Failed to save usage stats',
        ),
      );
    }
  }

  /// Check if user can add more addresses
  bool canAddAddress() => state.canAddAddress;

  /// Check if user can create more jobs
  bool canCreateJob() => state.canCreateJob;

  /// Check if user can create more invoices
  bool canCreateInvoice() => state.canCreateInvoice;

  /// Check if user can create more quotations
  bool canCreateQuotation() => state.canCreateQuotation;

  /// Check if user can create more templates
  bool canCreateTemplate() => state.canCreateTemplate;

  /// Check if user can create more services
  bool canCreateService() => state.canCreateService;

  /// Check if user can add more customers
  bool canAddCustomer() => state.canAddCustomer;

  /// Get the limit message for a specific feature
  String getLimitMessage(UsageCheckType type) {
    switch (type) {
      case UsageCheckType.address:
        return state.addressLimitMessage;
      case UsageCheckType.job:
        return state.jobLimitMessage;
      case UsageCheckType.invoice:
        return state.invoiceLimitMessage;
      case UsageCheckType.quotation:
        return state.quotationLimitMessage;
      case UsageCheckType.template:
        return state.templateLimitMessage;
      case UsageCheckType.service:
        return state.serviceLimitMessage;
      case UsageCheckType.customer:
        return state.customerLimitMessage;
    }
  }

  /// Cancel stream subscriptions without closing the BLoC
  /// Used during logout to prevent permission-denied errors
  void cancelSubscriptions() {
    _usageSubscription?.cancel();
    _usageSubscription = null;
  }

  @override
  Future<void> close() {
    cancelSubscriptions();
    return super.close();
  }
}
