import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../models/job_request.dart';
import '../../repositories/job_requests/job_requests_repository.dart';

abstract class JobRequestsEvent extends Equatable {
  const JobRequestsEvent();
  @override
  List<Object?> get props => const [];
}

class JobRequestsStartWatching extends JobRequestsEvent {
  const JobRequestsStartWatching();
}

class JobRequestsStopWatching extends JobRequestsEvent {
  const JobRequestsStopWatching();
}

class JobRequestsUpdated extends JobRequestsEvent {
  const JobRequestsUpdated(this.items);
  final List<JobRequest> items;
  @override
  List<Object?> get props => [items];
}

class JobRequestsFailed extends JobRequestsEvent {
  const JobRequestsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class JobRequestCancelRequested extends JobRequestsEvent {
  const JobRequestCancelRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

enum JobRequestsStatus { initial, loading, loaded, error }

class JobRequestsState extends Equatable {
  const JobRequestsState({
    this.status = JobRequestsStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final JobRequestsStatus status;
  final List<JobRequest> items;
  final String? errorMessage;

  static const initial = JobRequestsState();

  /// What the Jobs tab badge shows: everything not finished with.
  ///
  /// Derived rather than stored. A separate count would be a second source of
  /// truth that can disagree with the list the user is looking at, and the
  /// list is already in memory.
  int get openCount => items.where((j) => j.status.isOpen).length;

  JobRequestsState copyWith({
    JobRequestsStatus? status,
    List<JobRequest>? items,
    String? errorMessage,
  }) =>
      JobRequestsState(
        status: status ?? this.status,
        items: items ?? this.items,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, items, errorMessage];
}

/// Watches the customer's posted jobs.
class JobRequestsBloc extends Bloc<JobRequestsEvent, JobRequestsState> {
  JobRequestsBloc({JobRequestsRepository? repository})
      : _repository = repository ?? JobRequestsRepository(),
        super(JobRequestsState.initial) {
    on<JobRequestsStartWatching>(_onStart);
    on<JobRequestsStopWatching>(_onStop);
    on<JobRequestsUpdated>(_onUpdated);
    on<JobRequestsFailed>(_onFailed);
    on<JobRequestCancelRequested>(_onCancel);
  }

  final JobRequestsRepository _repository;
  StreamSubscription<List<JobRequest>>? _sub;

  Future<void> _onStart(
    JobRequestsStartWatching event,
    Emitter<JobRequestsState> emit,
  ) async {
    // Cancel first rather than bail out if already watching. Bailing would be
    // enough for the IndexedStack firing this twice, but it would also mean a
    // sign-out and sign-in as someone else kept the previous account's
    // subscription — and so the previous account's jobs.
    await _sub?.cancel();
    emit(state.copyWith(status: JobRequestsStatus.loading));
    _sub = _repository.watchMine().listen(
          (items) => add(JobRequestsUpdated(items)),
          // An error here has to become state. addError() alone reports to
          // Bloc's observer and emits nothing, which is a spinner that never
          // stops.
          onError: (Object e) => add(JobRequestsFailed(e.toString())),
        );
  }

  Future<void> _onStop(
    JobRequestsStopWatching event,
    Emitter<JobRequestsState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onUpdated(JobRequestsUpdated event, Emitter<JobRequestsState> emit) {
    emit(state.copyWith(
      status: JobRequestsStatus.loaded,
      items: event.items,
    ));
  }

  void _onFailed(JobRequestsFailed event, Emitter<JobRequestsState> emit) {
    emit(state.copyWith(
      status: JobRequestsStatus.error,
      errorMessage: event.message,
    ));
  }

  Future<void> _onCancel(
    JobRequestCancelRequested event,
    Emitter<JobRequestsState> emit,
  ) async {
    final ok = await _repository.cancel(event.id);
    if (!ok) {
      emit(state.copyWith(
        status: JobRequestsStatus.error,
        errorMessage: 'That job could not be cancelled.',
      ));
    }
    // On success nothing is emitted: the realtime stream carries the new row
    // back. Writing the change locally as well would mean the list briefly
    // shows a state the database has not confirmed.
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
