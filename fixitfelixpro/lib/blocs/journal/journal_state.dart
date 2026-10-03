import 'package:equatable/equatable.dart';

import '../../models/journal_entry.dart';

enum JournalStatus { initial, loading, loaded, error }

class JournalState extends Equatable {
  const JournalState({
    this.status = JournalStatus.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final JournalStatus status;
  final List<JournalEntry> entries;
  final String? errorMessage;

  static const initial = JournalState();

  /// All entries whose [JournalEntry.date] matches the given day.
  List<JournalEntry> entriesOn(DateTime day) {
    final key = JournalEntry.dateKey(day);
    return entries.where((e) => e.date == key).toList();
  }

  /// Fast lookup for calendar dots — the set of date strings that have
  /// at least one entry.
  Set<String> get datesWithEntries =>
      entries.map((e) => e.date).toSet();

  JournalState copyWith({
    JournalStatus? status,
    List<JournalEntry>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JournalState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, entries, errorMessage];
}
