import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../models/tools/tool_note.dart';
import '../../../repositories/tools/notes_repository.dart';
import 'notes_event.dart';
import 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc({required NotesRepository repository})
    : _repository = repository,
      super(NotesState.initial) {
    on<NotesStartWatching>(_onStart);
    on<NotesStopWatching>(_onStop);
    on<NotesUpdated>(_onUpdated);
    on<NoteDeleteRequested>(_onDelete);
  }

  final NotesRepository _repository;
  StreamSubscription<List<ToolNote>>? _sub;

  void _onStart(NotesStartWatching _, Emitter<NotesState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: NotesStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(NotesUpdated(items)),
      onError: (err) {
        debugPrint('NotesBloc stream error: $err');
        add(const NotesUpdated(<ToolNote>[]));
      },
    );
  }

  void _onStop(NotesStopWatching _, Emitter<NotesState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(NotesState.initial);
  }

  void _onUpdated(NotesUpdated event, Emitter<NotesState> emit) {
    emit(state.copyWith(
      status: NotesStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    NoteDeleteRequested event,
    Emitter<NotesState> emit,
  ) async {
    // Optimistic remove so the list animates immediately.
    emit(state.copyWith(
      items: state.items.where((n) => n.id != event.id).toList(),
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
