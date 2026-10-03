import '../../core/services/cache_service.dart';
import '../../models/todo_item.dart';
import '../base/owned_collection_repository.dart';

/// Row mapping for todos. Kept private: [TodoRepository] exposes per-field
/// setters rather than whole-object saves, so it composes this store instead
/// of inheriting a `create(TodoItem)` it would have to hide.
class _TodoStore extends OwnedCollectionRepository<TodoItem> {
  @override
  String get table => 'todos';

  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  String idOf(TodoItem t) => t.id;

  /// The RTDB version applied no sort — the list screen orders them — so this
  /// preserves insertion order rather than inventing one.
  @override
  int compare(TodoItem a, TodoItem b) => 0;

  @override
  Map<String, dynamic> toRow(TodoItem t) => {
        if (t.id.isNotEmpty) 'id': t.id,
        'title': t.title,
        'notes': t.notes,
        'due_at': _iso(t.dueAt),
        'completed': t.completed,
        'completed_at': _iso(t.completedAt),
        'tag_color': t.tagColor,
      };

  @override
  TodoItem fromRow(Map<String, dynamic> row) => TodoItem(
        id: row['id']?.toString() ?? '',
        title: (row['title'] ?? '').toString(),
        notes: row['notes']?.toString(),
        dueAt: _millis(row['due_at']),
        completed: row['completed'] == true,
        completedAt: _millis(row['completed_at']),
        tagColor: (row['tag_color'] as num?)?.toInt(),
        createdAt: _millis(row['created_at']) ?? 0,
        updatedAt: _millis(row['updated_at']) ?? 0,
      );

  /// TodoItem carries epoch millis; Postgres carries timestamptz.
  static String? _iso(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis).toUtc().toIso8601String();

  static int? _millis(Object? v) =>
      OwnedCollectionRepository.parseTs(v)?.millisecondsSinceEpoch;
}

/// CRUD + live stream for todos.
///
/// Was `/todos/{uid}/{id}` in Realtime Database; now the `todos` table.
/// The named-parameter API is preserved exactly so no caller changes.
class TodoRepository {
  final _TodoStore _store = _TodoStore();

  Stream<List<TodoItem>> watchAll() => _store.watchAll();

  Future<String?> create({
    required String title,
    String? notes,
    DateTime? dueDate,
    int? tagColor,
  }) async {
    final id = OwnedCollectionRepository.newId();
    return _store.create(TodoItem(
      id: id,
      title: title,
      notes: (notes == null || notes.isEmpty) ? null : notes,
      dueAt: dueDate?.millisecondsSinceEpoch,
      completed: false,
      tagColor: tagColor,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<bool> update({
    required String id,
    required String title,
    String? notes,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? tagColor,
    bool clearTagColor = false,
  }) async {
    // Built as a patch, not a whole-row write: the clear* flags mean "set this
    // column to null", which a full save cannot express without also nulling
    // every field the caller did not mention.
    final payload = <String, dynamic>{
      'title': title,
      'notes': (notes == null || notes.isEmpty) ? null : notes,
    };
    if (clearDueDate) {
      payload['due_at'] = null;
    } else if (dueDate != null) {
      payload['due_at'] = dueDate.toUtc().toIso8601String();
    }
    if (clearTagColor) {
      payload['tag_color'] = null;
    } else if (tagColor != null) {
      payload['tag_color'] = tagColor;
    }
    return _store.patch(id, payload);
  }

  Future<bool> setCompleted({
    required String id,
    required bool completed,
  }) async {
    return _store.patch(id, {
      'completed': completed,
      'completed_at':
          completed ? DateTime.now().toUtc().toIso8601String() : null,
    });
  }

  Future<bool> delete(String id) => _store.delete(id);
}
