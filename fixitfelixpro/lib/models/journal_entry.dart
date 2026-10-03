import 'package:equatable/equatable.dart';

/// A journal / calendar entry owned by a single user.
/// Persisted under `/journalEvents/{uid}/{id}`.
class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.date,
    required this.allDay,
    this.startAt,
    this.endAt,
    this.customerId,
    this.customerName,
    this.location,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;

  /// Local date of the entry — "YYYY-MM-DD". Kept as a string because
  /// RTDB doesn't have a dedicated date type and this is trivial to
  /// range-query on lexicographically.
  final String date;

  final bool allDay;

  /// ms-since-epoch. Null when [allDay] is true.
  final int? startAt;
  final int? endAt;

  final String? customerId;
  final String? customerName;
  final String? location;
  final String? notes;

  final int createdAt;
  final int updatedAt;

  DateTime get dateObj {
    final parts = date.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime? get startAtObj =>
      startAt != null ? DateTime.fromMillisecondsSinceEpoch(startAt!) : null;
  DateTime? get endAtObj =>
      endAt != null ? DateTime.fromMillisecondsSinceEpoch(endAt!) : null;

  /// True when the entry's end-time (or end-of-day, for all-day) is
  /// before the current wall clock.
  bool get isPast {
    final now = DateTime.now();
    if (allDay) {
      final d = dateObj;
      final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
      return endOfDay.isBefore(now);
    }
    final end = endAtObj ?? startAtObj;
    if (end == null) return false;
    return end.isBefore(now);
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'date': date,
    'allDay': allDay,
    'startAt': startAt,
    'endAt': endAt,
    'customerId': customerId,
    'customerName': customerName,
    'location': location,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory JournalEntry.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    return JournalEntry(
      id: id,
      title: raw['title']?.toString() ?? '',
      date: raw['date']?.toString() ?? '',
      allDay: raw['allDay'] == true,
      startAt: (raw['startAt'] as num?)?.toInt(),
      endAt: (raw['endAt'] as num?)?.toInt(),
      customerId: raw['customerId']?.toString(),
      customerName: raw['customerName']?.toString(),
      location: raw['location']?.toString(),
      notes: raw['notes']?.toString(),
      createdAt: (raw['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (raw['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  static String dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  List<Object?> get props => [
    id,
    title,
    date,
    allDay,
    startAt,
    endAt,
    customerId,
    customerName,
    location,
    notes,
    createdAt,
    updatedAt,
  ];
}
