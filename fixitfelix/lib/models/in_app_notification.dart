import 'package:equatable/equatable.dart';

/// Lightweight in-app notification mirrored from RTDB
/// `/notifications/{uid}/{id}` — written by the backend.
class InAppNotification extends Equatable {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.read,
    this.readAt,
    this.payload,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool read;
  final DateTime? readAt;
  final Map<String, dynamic>? payload;

  factory InAppNotification.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    final createdMs = (raw['createdAt'] as num?)?.toInt() ?? 0;
    final readMs = (raw['readAt'] as num?)?.toInt();
    return InAppNotification(
      id: id,
      title: raw['title']?.toString() ?? '',
      body: raw['body']?.toString() ?? '',
      type: raw['type']?.toString() ?? 'system',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      read: raw['read'] == true,
      readAt: readMs != null
          ? DateTime.fromMillisecondsSinceEpoch(readMs)
          : null,
      payload: raw['payload'] is Map
          ? Map<String, dynamic>.from(raw['payload'] as Map)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, title, body, type, createdAt, read, readAt];
}
