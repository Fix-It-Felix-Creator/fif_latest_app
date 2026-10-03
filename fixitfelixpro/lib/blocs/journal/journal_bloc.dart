import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../repositories/journal/journal_repository.dart';
import 'journal_event.dart';
import 'journal_state.dart';

class JournalBloc extends Bloc<JournalEvent, JournalState> {
  JournalBloc({required JournalRepository repository})
    : _repository = repository,
      super(JournalState.initial) {
    on<JournalStartWatching>(_onStart);
    on<JournalStopWatching>(_onStop);
    on<JournalUpdated>(_onUpdated);
    on<JournalDeleteRequested>(_onDelete);
  }

  final JournalRepository _repository;
  StreamSubscription<List<JournalEntry>>? _sub;

  void _onStart(JournalStartWatching _, Emitter<JournalState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: JournalStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (entries) => add(JournalUpdated(entries)),
      onError: (err) {
        debugPrint('JournalBloc stream error: $err');
      },
    );
  }

  void _onStop(JournalStopWatching _, Emitter<JournalState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(JournalState.initial);
  }

  void _onUpdated(JournalUpdated event, Emitter<JournalState> emit) {
    emit(
      state.copyWith(
        status: JournalStatus.loaded,
        entries: event.entries,
        clearError: true,
      ),
    );
  }

  Future<void> _onDelete(
    JournalDeleteRequested event,
    Emitter<JournalState> emit,
  ) async {
    // Optimistic — stream will reconcile.
    emit(state.copyWith(
      entries: state.entries.where((e) => e.id != event.id).toList(),
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
