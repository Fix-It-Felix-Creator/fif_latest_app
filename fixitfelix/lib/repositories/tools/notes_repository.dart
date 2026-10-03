import '../../models/tools/tool_note.dart';
import '../base/owned_collection_repository.dart';
import 'tool_asset_store.dart';

/// CRUD + live stream for the Notes tool.
///
/// Was `/userTools/{uid}/notes/{id}`; now `tool_assets` rows with
/// `kind = 'note'`. Public API unchanged.
class NotesRepository {
  final ToolAssetStore<ToolNote> _store = ToolAssetStore<ToolNote>(
    kind: 'note',
    idOfFn: (n) => n.id,
    // Newest-edited first.
    compareFn: (a, b) => b.updatedAt.compareTo(a.updatedAt),
    toRowFn: (n) => {
      if (n.id.isNotEmpty) 'id': n.id,
      'title': n.title,
      // A note's text is free-form and unbounded, so it uses the `body`
      // column rather than `description`, which the media kinds use for a
      // short caption.
      'body': n.body,
    },
    fromRowFn: (row) => ToolNote(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
      updatedAt: OwnedCollectionRepository.parseTsOr(
          row['updated_at'], DateTime.now()),
    ),
  );

  Stream<List<ToolNote>> watchAll() => _store.watchAll();

  Future<String?> create({
    required String title,
    required String body,
  }) {
    final now = DateTime.now();
    return _store.create(ToolNote(
      id: OwnedCollectionRepository.newId(),
      title: title,
      body: body,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<bool> update(ToolNote note) => _store.patch(note.id, {
        'title': note.title,
        'body': note.body,
      });

  Future<bool> delete(String id) => _store.delete(id);
}
