import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/staff.dart';
import '../../repositories/staff/staff_repository.dart';
import 'staff_event.dart';
import 'staff_state.dart';

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  StaffBloc({required StaffRepository repository})
    : _repository = repository,
      super(StaffState.initial) {
    on<StaffStartWatching>(_onStart);
    on<StaffStopWatching>(_onStop);
    on<StaffUpdated>(_onUpdated);
    on<StaffDeleteRequested>(_onDelete);
  }

  final StaffRepository _repository;
  StreamSubscription<List<Staff>>? _sub;

  void _onStart(StaffStartWatching _, Emitter<StaffState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: StaffStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(StaffUpdated(items)),
      onError: (err) {
        debugPrint('StaffBloc stream error: $err');
      },
    );
  }

  void _onStop(StaffStopWatching _, Emitter<StaffState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(StaffState.initial);
  }

  void _onUpdated(StaffUpdated event, Emitter<StaffState> emit) {
    emit(state.copyWith(
      status: StaffStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    StaffDeleteRequested event,
    Emitter<StaffState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((s) => s.id != event.id).toList(),
    ));
    await _repository.delete(event.id);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
