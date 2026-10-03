import 'package:equatable/equatable.dart';

import '../../models/journal_entry.dart';

abstract class JournalEvent extends Equatable {
  const JournalEvent();

  @override
  List<Object?> get props => const [];
}

class JournalStartWatching extends JournalEvent {
  const JournalStartWatching();
}

class JournalStopWatching extends JournalEvent {
  const JournalStopWatching();
}

class JournalUpdated extends JournalEvent {
  const JournalUpdated(this.entries);
  final List<JournalEntry> entries;

  @override
  List<Object?> get props => [entries];
}

class JournalDeleteRequested extends JournalEvent {
  const JournalDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
