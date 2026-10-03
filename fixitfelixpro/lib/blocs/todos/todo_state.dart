import 'package:equatable/equatable.dart';

import '../../models/todo_item.dart';

enum TodoStatus { idle, loading, loaded, error }

class TodoState extends Equatable {
  const TodoState({
    required this.status,
    required this.items,
  });

  factory TodoState.initial() =>
      const TodoState(status: TodoStatus.idle, items: []);

  final TodoStatus status;
  final List<TodoItem> items;

  /// Pending tasks sorted by nearest due date first, then newest created.
  List<TodoItem> get pending {
    final list = items.where((t) => !t.completed).toList()
      ..sort((a, b) {
        final ad = a.dueAt;
        final bd = b.dueAt;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  /// Completed tasks sorted most-recently-completed first.
  List<TodoItem> get done {
    final list = items.where((t) => t.completed).toList()
      ..sort((a, b) {
        final ac = a.completedAt ?? a.updatedAt;
        final bc = b.completedAt ?? b.updatedAt;
        return bc.compareTo(ac);
      });
    return list;
  }

  TodoState copyWith({TodoStatus? status, List<TodoItem>? items}) {
    return TodoState(
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [status, items];
}
