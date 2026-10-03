import 'package:equatable/equatable.dart';

import '../../../models/tools/tool_note.dart';

enum NotesStatus { initial, loading, loaded, error }

class NotesState extends Equatable {
  const NotesState({
    this.status = NotesStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final NotesStatus status;
  final List<ToolNote> items;
  final String? errorMessage;

  static const initial = NotesState();

  NotesState copyWith({
    NotesStatus? status,
    List<ToolNote>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
