import 'package:equatable/equatable.dart';

/// A to-do item owned by a single user.
/// Persisted under `/todos/{uid}/{id}`.
class TodoItem extends Equatable {
  const TodoItem({
    required this.id,
    required this.title,
    this.notes,
    this.dueAt,
    required this.completed,
    this.completedAt,
    this.tagColor,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? notes;

  /// Optional due date as ms-since-epoch.
  final int? dueAt;

  final bool completed;
  final int? completedAt;

  /// Optional tag colour, stored as a 32-bit ARGB int (Flutter `Color.value`).
  final int? tagColor;

  final int createdAt;
  final int updatedAt;

  DateTime? get dueDate =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);

  factory TodoItem.fromRtdb(String id, Map raw) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return TodoItem(
      id: id,
      title: (raw['title'] ?? '').toString(),
      notes: raw['notes']?.toString(),
      dueAt: asInt(raw['dueAt']),
      completed: raw['completed'] == true,
      completedAt: asInt(raw['completedAt']),
      tagColor: asInt(raw['tagColor']),
      createdAt: asInt(raw['createdAt']) ?? 0,
      updatedAt: asInt(raw['updatedAt']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    notes,
    dueAt,
    completed,
    completedAt,
    tagColor,
    createdAt,
    updatedAt,
  ];
}
