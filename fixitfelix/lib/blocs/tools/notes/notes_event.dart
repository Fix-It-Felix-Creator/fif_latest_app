import 'package:equatable/equatable.dart';

import '../../../models/tools/tool_note.dart';

abstract class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => const [];
}

class NotesStartWatching extends NotesEvent {
  const NotesStartWatching();
}

class NotesStopWatching extends NotesEvent {
  const NotesStopWatching();
}

class NotesUpdated extends NotesEvent {
  const NotesUpdated(this.items);
  final List<ToolNote> items;

  @override
  List<Object?> get props => [items];
}

class NoteDeleteRequested extends NotesEvent {
  const NoteDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
