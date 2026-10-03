import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../models/lead_application.dart';
import '../../repositories/leads/lead_applications_repository.dart';
import '../../screens/leads/leads_application.dart';

abstract class LeadApplicationEvent extends Equatable {
  const LeadApplicationEvent();
  @override
  List<Object?> get props => const [];
}

class LeadApplicationStartWatching extends LeadApplicationEvent {
  const LeadApplicationStartWatching();
}

class LeadApplicationUpdated extends LeadApplicationEvent {
  const LeadApplicationUpdated(this.snapshot);
  final LeadsSnapshot snapshot;
  @override
  List<Object?> get props => [snapshot.application, snapshot.plan];
}

class LeadApplicationFailed extends LeadApplicationEvent {
  const LeadApplicationFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class LeadApplicationWithdrawRequested extends LeadApplicationEvent {
  const LeadApplicationWithdrawRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

enum LeadApplicationStateStatus { initial, loading, loaded, error }

class LeadApplicationState extends Equatable {
  const LeadApplicationState({
    this.status = LeadApplicationStateStatus.initial,
    this.application,
    this.plan = const LeadsPlan.standard(),
    this.errorMessage,
  });

  final LeadApplicationStateStatus status;

  /// The newest application, live or historical. Null means never applied.
  final LeadApplication? application;

  /// The tier this account is actually on. Standard until told otherwise —
  /// the direction that withholds an entitlement rather than inventing one.
  final LeadsPlan plan;

  final String? errorMessage;

  static const initial = LeadApplicationState();

  /// Whether the banner and the leads screen should offer to start one.
  bool get canApply {
    final app = application;
    return app == null || app.status.allowsReapply;
  }

  bool get isApproved =>
      application?.status == LeadApplicationStatus.approved;

  bool get isPending =>
      application?.status == LeadApplicationStatus.submitted;

  LeadApplicationState copyWith({
    LeadApplicationStateStatus? status,
    LeadApplication? application,
    LeadsPlan? plan,
    bool clearApplication = false,
    String? errorMessage,
  }) =>
      LeadApplicationState(
        status: status ?? this.status,
        application:
            clearApplication ? null : (application ?? this.application),
        plan: plan ?? this.plan,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, application, plan, errorMessage];
}

/// Watches this tradesperson's leads application.
class LeadApplicationBloc
    extends Bloc<LeadApplicationEvent, LeadApplicationState> {
  LeadApplicationBloc({LeadApplicationsRepository? repository})
      : _repository = repository ?? LeadApplicationsRepository(),
        super(LeadApplicationState.initial) {
    on<LeadApplicationStartWatching>(_onStart);
    on<LeadApplicationUpdated>(_onUpdated);
    on<LeadApplicationFailed>(_onFailed);
    on<LeadApplicationWithdrawRequested>(_onWithdraw);
  }

  final LeadApplicationsRepository _repository;
  StreamSubscription<LeadsSnapshot>? _sub;

  Future<void> _onStart(
    LeadApplicationStartWatching event,
    Emitter<LeadApplicationState> emit,
  ) async {
    // Cancel first rather than bail if already watching: a sign-out and
    // sign-in as somebody else must not keep the previous account's
    // subscription, and therefore the previous account's application.
    await _sub?.cancel();
    emit(state.copyWith(status: LeadApplicationStateStatus.loading));
    _sub = _repository.watch().listen(
          (snapshot) => add(LeadApplicationUpdated(snapshot)),
          // Has to become state. addError() reports to Bloc's observer and
          // emits nothing, which is a spinner that never stops.
          onError: (Object e) => add(LeadApplicationFailed(e.toString())),
        );
  }

  void _onUpdated(
    LeadApplicationUpdated event,
    Emitter<LeadApplicationState> emit,
  ) {
    emit(LeadApplicationState(
      status: LeadApplicationStateStatus.loaded,
      application: event.snapshot.application,
      plan: event.snapshot.plan,
    ));
  }

  void _onFailed(
    LeadApplicationFailed event,
    Emitter<LeadApplicationState> emit,
  ) {
    emit(state.copyWith(
      status: LeadApplicationStateStatus.error,
      errorMessage: event.message,
    ));
  }

  Future<void> _onWithdraw(
    LeadApplicationWithdrawRequested event,
    Emitter<LeadApplicationState> emit,
  ) async {
    final ok = await _repository.withdraw(event.id);
    if (!ok) {
      emit(state.copyWith(
        status: LeadApplicationStateStatus.error,
        errorMessage: 'That application could not be withdrawn.',
      ));
    }
    // Nothing emitted on success: the realtime stream carries the new row
    // back. Writing it locally too would briefly show a state the database has
    // not confirmed.
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
