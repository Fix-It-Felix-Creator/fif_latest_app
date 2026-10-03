import 'package:equatable/equatable.dart';

import '../../models/todo_item.dart';

abstract class TodoEvent extends Equatable {
  const TodoEvent();
  @override
  List<Object?> get props => [];
}

class TodoStartWatching extends TodoEvent {
  const TodoStartWatching();
}

class TodoStopWatching extends TodoEvent {
  const TodoStopWatching();
}

class TodoUpdated extends TodoEvent {
  const TodoUpdated(this.items);
  final List<TodoItem> items;
  @override
  List<Object?> get props => [items];
}

class TodoToggleCompleted extends TodoEvent {
  const TodoToggleCompleted({required this.id, required this.completed});
  final String id;
  final bool completed;
  @override
  List<Object?> get props => [id, completed];
}

class TodoDeleteRequested extends TodoEvent {
  const TodoDeleteRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}
