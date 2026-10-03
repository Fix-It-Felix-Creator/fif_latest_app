import 'package:equatable/equatable.dart';

/// A single note in the Notes tool. Stored at
/// `/userTools/{uid}/notes/{noteId}` in RTDB.
class ToolNote extends Equatable {
  const ToolNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  ToolNote copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
  }) {
    return ToolNote(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toRtdb() => {
    'title': title,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory ToolNote.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    return ToolNote(
      id: id,
      title: raw['title']?.toString() ?? '',
      body: raw['body']?.toString() ?? '',
      createdAt: _ts(raw['createdAt']),
      updatedAt: _ts(raw['updatedAt']),
    );
  }

  static DateTime _ts(Object? v) {
    final ms = (v as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  List<Object?> get props => [id, title, body, createdAt, updatedAt];
}
