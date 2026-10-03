import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/todo_item.dart';
import '../../repositories/todos/todo_repository.dart';
import 'todo_event.dart';
import 'todo_state.dart';

class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc({required TodoRepository repository})
    : _repository = repository,
      super(TodoState.initial()) {
    on<TodoStartWatching>(_onStart);
    on<TodoStopWatching>(_onStop);
    on<TodoUpdated>(_onUpdated);
    on<TodoToggleCompleted>(_onToggleCompleted);
    on<TodoDeleteRequested>(_onDelete);
  }

  final TodoRepository _repository;
  StreamSubscription<List<TodoItem>>? _sub;

  void _onStart(TodoStartWatching _, Emitter<TodoState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: TodoStatus.loading));
    _sub = _repository.watchAll().listen(
      (items) => add(TodoUpdated(items)),
      onError: (err) => debugPrint('TodoBloc stream error: $err'),
    );
  }

  void _onStop(TodoStopWatching _, Emitter<TodoState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(TodoState.initial());
  }

  void _onUpdated(TodoUpdated event, Emitter<TodoState> emit) {
    emit(state.copyWith(status: TodoStatus.loaded, items: event.items));
  }

  Future<void> _onToggleCompleted(
    TodoToggleCompleted event,
    Emitter<TodoState> emit,
  ) async {
    await _repository.setCompleted(
      id: event.id,
      completed: event.completed,
    );
  }

  Future<void> _onDelete(
    TodoDeleteRequested event,
    Emitter<TodoState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((t) => t.id != event.id).toList(),
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
