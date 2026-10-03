import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/cache_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/in_app_notification.dart';
import '../base/owned_collection_repository.dart';

/// Streams and mutates the caller's in-app notifications.
///
/// Was an RTDB stream plus four `/notifications/*` Cloud Function endpoints.
/// Both halves are now direct Postgres operations: the
/// `notifications_only_read_flag` trigger already stops a client rewriting a
/// notification's contents, so marking read needs no server hop, and the
/// owner-scoped delete policy covers clearing.
class NotificationsRepository extends OwnedCollectionRepository<InAppNotification> {
  @override
  String get table => 'notifications';

  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  String idOf(InAppNotification n) => n.id;

  /// Newest first.
  @override
  int compare(InAppNotification a, InAppNotification b) =>
      b.createdAt.compareTo(a.createdAt);

  @override
  Map<String, dynamic> toRow(InAppNotification n) => {
        if (n.id.isNotEmpty) 'id': n.id,
        'type': n.type,
        'title': n.title,
        'body': n.body,
        'read': n.read,
        'read_at': n.readAt?.toUtc().toIso8601String(),
        'payload': n.payload,
      };

  @override
  InAppNotification fromRow(Map<String, dynamic> row) => InAppNotification(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        body: row['body']?.toString() ?? '',
        type: row['type']?.toString() ?? 'general',
        read: row['read'] == true,
        readAt: OwnedCollectionRepository.parseTs(row['read_at']),
        createdAt: OwnedCollectionRepository.parseTsOr(
            row['created_at'], DateTime.now()),
        payload: row['payload'] is Map
            ? Map<String, dynamic>.from(row['payload'] as Map)
            : null,
      );

  Future<bool> markRead(String notificationId) => patch(notificationId, {
        'read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<bool> markAllRead() async {
    final owner = uid;
    if (owner == null) return false;
    try {
      await SupabaseService()
          .client
          .from(table)
          .update({
            'read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('owner_id', owner)
          // Only touch unread rows: rewriting an already-read notification
          // would move its read_at, changing what the UI shows.
          .eq('read', false);
      return true;
    } catch (e) {
      debugPrint('NotificationsRepository.markAllRead failed: $e');
      return false;
    }
  }

  Future<bool> clear(String notificationId) => delete(notificationId);

  Future<bool> clearAll() async {
    final owner = uid;
    if (owner == null) return false;
    try {
      await SupabaseService().client.from(table).delete().eq('owner_id', owner);
      return true;
    } catch (e) {
      debugPrint('NotificationsRepository.clearAll failed: $e');
      return false;
    }
  }
}
