import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../models/job_model.dart';
import '../../repositories/jobs/jobs_repository.dart';

abstract class JobsEvent extends Equatable {
  const JobsEvent();
  @override
  List<Object?> get props => const [];
}

class JobsStartWatching extends JobsEvent {
  const JobsStartWatching();
}

class JobsStopWatching extends JobsEvent {
  const JobsStopWatching();
}

class JobsUpdated extends JobsEvent {
  const JobsUpdated(this.items);
  final List<Job> items;
  @override
  List<Object?> get props => [items];
}

class JobDeleteRequested extends JobsEvent {
  const JobDeleteRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class JobStatusUpdateRequested extends JobsEvent {
  const JobStatusUpdateRequested(this.id, this.status);
  final String id;
  final JobStatus status;
  @override
  List<Object?> get props => [id, status];
}

enum JobsStatus { initial, loading, loaded, error }

class JobsState extends Equatable {
  const JobsState({
    this.status = JobsStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final JobsStatus status;
  final List<Job> items;
  final String? errorMessage;

  static const initial = JobsState();

  JobsState copyWith({
    JobsStatus? status,
    List<Job>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JobsState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

class JobsBloc extends Bloc<JobsEvent, JobsState> {
  JobsBloc({required JobsRepository repository})
      : _repository = repository,
        super(JobsState.initial) {
    on<JobsStartWatching>(_onStart);
    on<JobsStopWatching>(_onStop);
    on<JobsUpdated>(_onUpdated);
    on<JobDeleteRequested>(_onDelete);
    on<JobStatusUpdateRequested>(_onStatus);
  }

  final JobsRepository _repository;
  StreamSubscription<List<Job>>? _sub;

  void _onStart(JobsStartWatching _, Emitter<JobsState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: JobsStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(JobsUpdated(items)),
      onError: (err) {
        debugPrint('JobsBloc stream error: $err');
        add(const JobsUpdated(<Job>[]));
      },
    );
  }

  void _onStop(JobsStopWatching _, Emitter<JobsState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(JobsState.initial);
  }

  void _onUpdated(JobsUpdated event, Emitter<JobsState> emit) {
    emit(state.copyWith(
      status: JobsStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    JobDeleteRequested event,
    Emitter<JobsState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((j) => j.id != event.id).toList(),
    ));
    await _repository.delete(event.id);
  }

  Future<void> _onStatus(
    JobStatusUpdateRequested event,
    Emitter<JobsState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items
          .map((j) => j.id == event.id ? j.copyWith(status: event.status) : j)
          .toList(),
    ));
    await _repository.updateStatus(event.id, event.status);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
