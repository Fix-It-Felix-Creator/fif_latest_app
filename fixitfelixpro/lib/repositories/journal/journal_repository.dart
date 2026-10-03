import '../../core/services/cache_service.dart';
import '../../models/journal_entry.dart';
import '../base/owned_collection_repository.dart';

/// Row mapping for journal entries. Private for the same reason as the todo
/// store: the public API is named-parameter, not whole-object.
class _JournalStore extends OwnedCollectionRepository<JournalEntry> {
  @override
  String get table => 'journal_entries';

  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  String idOf(JournalEntry e) => e.id;

  /// Chronological: by day, then by start time within the day. All-day events
  /// have no startAt and sort first, matching the RTDB behaviour where the
  /// missing value defaulted to 0.
  @override
  int compare(JournalEntry a, JournalEntry b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return (a.startAt ?? 0).compareTo(b.startAt ?? 0);
  }

  @override
  Map<String, dynamic> toRow(JournalEntry e) => {
        if (e.id.isNotEmpty) 'id': e.id,
        'title': e.title,
        // JournalEntry.date is already a 'YYYY-MM-DD' key, which is exactly
        // what a Postgres `date` column takes.
        'entry_date': e.date,
        'all_day': e.allDay,
        'start_at': _iso(e.startAt),
        'end_at': _iso(e.endAt),
        'customer_id': e.customerId,
        'customer_name': e.customerName,
        'location': e.location,
        'notes': e.notes,
      };

  @override
  JournalEntry fromRow(Map<String, dynamic> row) => JournalEntry(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        date: row['entry_date']?.toString() ?? '',
        allDay: row['all_day'] == true,
        startAt: _millis(row['start_at']),
        endAt: _millis(row['end_at']),
        customerId: row['customer_id']?.toString(),
        customerName: row['customer_name']?.toString(),
        location: row['location']?.toString(),
        notes: row['notes']?.toString(),
        createdAt: _millis(row['created_at']) ?? 0,
        updatedAt: _millis(row['updated_at']) ?? 0,
      );

  static String? _iso(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis).toUtc().toIso8601String();

  static int? _millis(Object? v) =>
      OwnedCollectionRepository.parseTs(v)?.millisecondsSinceEpoch;
}

/// CRUD + live stream for journal (diary) entries.
///
/// Was `/journalEvents/{uid}/{id}` in Realtime Database; now
/// `journal_entries`. The named-parameter API is preserved exactly.
class JournalRepository {
  final _JournalStore _store = _JournalStore();

  Stream<List<JournalEntry>> watchAll() => _store.watchAll();

  Future<String?> create({
    required String title,
    required DateTime date,
    required bool allDay,
    DateTime? startAt,
    DateTime? endAt,
    String? customerId,
    String? customerName,
    String? location,
    String? notes,
  }) async {
    return _store.create(JournalEntry(
      id: OwnedCollectionRepository.newId(),
      title: title,
      date: JournalEntry.dateKey(date),
      allDay: allDay,
      // An all-day event carries no times, matching the original.
      startAt: allDay ? null : startAt?.millisecondsSinceEpoch,
      endAt: allDay ? null : endAt?.millisecondsSinceEpoch,
      customerId: customerId,
      customerName: customerName,
      location: location,
      notes: notes,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<bool> update({
    required String id,
    required String title,
    required DateTime date,
    required bool allDay,
    DateTime? startAt,
    DateTime? endAt,
    String? customerId,
    String? customerName,
    String? location,
    String? notes,
  }) async {
    // patch(), so switching an event to all-day genuinely clears start/end
    // rather than leaving stale times behind.
    return _store.patch(id, {
      'title': title,
      'entry_date': JournalEntry.dateKey(date),
      'all_day': allDay,
      'start_at': allDay
          ? null
          : startAt?.toUtc().toIso8601String(),
      'end_at': allDay ? null : endAt?.toUtc().toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'location': location,
      'notes': notes,
    });
  }

  Future<bool> delete(String id) => _store.delete(id);
}
