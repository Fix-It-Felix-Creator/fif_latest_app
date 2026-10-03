import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fixitfelix/core/services/offline_sync_service.dart';
import 'package:fixitfelix/repositories/base/owned_collection_repository.dart';

/// The queue is persisted to Hive as JSON and must survive an app restart —
/// a mutation that cannot be read back is a silently lost write.
void main() {
  test('PendingMutation survives a JSON round-trip', () {
    final m = PendingMutation(
      id: 'q1',
      table: 'customers',
      op: SyncOp.insert,
      rowId: 'c1',
      payload: const {'name': 'Acme', 'latitude': 55.86, 'notes': null},
      queuedAt: DateTime.utc(2026, 8, 23, 12, 0, 0),
      attempts: 2,
    );

    final restored = PendingMutation.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );

    expect(restored.id, m.id);
    expect(restored.table, m.table);
    expect(restored.op, SyncOp.insert);
    expect(restored.rowId, m.rowId);
    expect(restored.payload['name'], 'Acme');
    expect(restored.payload['latitude'], 55.86);
    expect(restored.payload.containsKey('notes'), isTrue);
    expect(restored.payload['notes'], isNull);
    expect(restored.queuedAt, m.queuedAt);
    expect(restored.attempts, 2);
  });

  test('an unknown op decodes to update rather than throwing', () {
    // A queue written by a newer build must not brick an older one.
    final restored = PendingMutation.fromJson({
      'id': 'q2',
      'table': 'todos',
      'op': 'something_new',
      'rowId': 't1',
      'payload': <String, dynamic>{},
      'queuedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    expect(restored.op, SyncOp.update);
  });

  test('withAttempt increments without mutating the original', () {
    final m = PendingMutation(
      id: 'q3',
      table: 'todos',
      op: SyncOp.delete,
      rowId: 't2',
      payload: const {},
      queuedAt: DateTime.utc(2026, 1, 1),
    );
    final next = m.withAttempt();
    expect(m.attempts, 0);
    expect(next.attempts, 1);
    expect(next.rowId, m.rowId);
  });

  test('newId produces distinct RFC-4122 v4 UUIDs', () {
    // Offline inserts depend on the client picking the primary key, so a
    // collision would silently overwrite another record.
    final ids = List.generate(500, (_) => OwnedCollectionRepository.newId());
    expect(ids.toSet().length, 500);

    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (final id in ids) {
      expect(re.hasMatch(id), isTrue, reason: '$id is not a v4 UUID');
    }
  });
}
