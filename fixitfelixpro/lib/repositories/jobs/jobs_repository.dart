import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/enum.dart' hide JobStatus;
import '../../core/services/supabase_service.dart';
import '../../models/job_expense.dart';
import '../../models/job_model.dart';
import '../../models/job_time_entry.dart';
import '../../models/tools/tool_photo.dart';
import '../base/owned_collection_repository.dart';
import '../quotes/quote_document_mapper.dart';

/// CRUD + live stream for jobs.
///
/// RTDB stored a job as ONE node with nested `expenses`, `timeEntries`,
/// `attached*` and linked-document arrays. Postgres splits those across
/// `jobs`, `job_expenses`, `job_time_entries`, `job_attachments` and
/// `job_links`, so saves go through the `save_job` RPC to stay atomic.
///
/// Time entries are the one child the RPC does not touch: they accumulate via
/// [clockOut], and a document save must never wipe hours already logged.
class JobsRepository {
  static const String _documentSelect = '''
*,
job_expenses(*),
job_time_entries(*),
job_attachments(*),
job_links(*)
''';

  String? get _uid => SupabaseService().auth.currentUser?.id;

  Future<Job?> findById(String id) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await SupabaseService()
          .client
          .from('jobs')
          .select(_documentSelect)
          .eq('id', id)
          .eq('owner_id', uid)
          .maybeSingle();
      return row == null ? null : _fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('JobsRepository.findById failed: $e');
      return null;
    }
  }

  /// Live list of the user's jobs, newest first.
  ///
  /// The realtime `stream()` cannot embed child tables, so it acts purely as a
  /// change signal and each event triggers one embedded select — keeping jobs
  /// whole rather than emitting them with stale expenses or time entries.
  Stream<List<Job>> watchAll() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Job>[]);

    final controller = StreamController<List<Job>>();
    StreamSubscription? sub;
    var inFlight = false;
    var pending = false;

    Future<void> refresh() async {
      if (inFlight) {
        pending = true;
        return;
      }
      inFlight = true;
      try {
        final rows = await SupabaseService()
            .client
            .from('jobs')
            .select(_documentSelect)
            .eq('owner_id', uid)
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(
            List<Map<String, dynamic>>.from(rows).map(_fromRow).toList(),
          );
        }
      } catch (e) {
        debugPrint('JobsRepository.watchAll refresh failed: $e');
      } finally {
        inFlight = false;
        if (pending) {
          pending = false;
          unawaited(refresh());
        }
      }
    }

    controller.onListen = () {
      unawaited(refresh());
      sub = SupabaseService()
          .client
          .from('jobs')
          .stream(primaryKey: const ['id'])
          .eq('owner_id', uid)
          .listen(
            (_) => unawaited(refresh()),
            onError: (Object e) =>
                debugPrint('JobsRepository.watchAll stream error: $e'),
          );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<String?> create(Job job) => _save(job, id: null);

  Future<bool> update(Job job) async => await _save(job, id: job.id) != null;

  Future<String?> _save(Job j, {String? id}) async {
    if (_uid == null) return null;
    try {
      final payload = <String, dynamic>{
        if (id != null && id.isNotEmpty) 'id': id,
        'reference': j.reference,
        'title': j.title,
        'description': j.description,
        'status': j.status.wire,
        'start_date': _dateOnly(j.startDate),
        if (j.customer != null) ...{
          'customer_id': _fkOrNull(j.customer!.id),
          'customer_snapshot': QuoteDocumentMapper.customerToJson(j.customer!),
        },
        if (j.clockInAt != null)
          'clock_in_at': j.clockInAt!.toUtc().toIso8601String(),
        'expenses': j.expenses.map(_expenseToJson).toList(),
        'attachments': [
          ...j.attachedPhotos.map(QuoteDocumentMapper.photoToJson),
          ...j.attachedVideos.map(QuoteDocumentMapper.videoToJson),
          ...j.attachedFiles.map(QuoteDocumentMapper.fileToJson),
          ...j.attachedNotes.map(QuoteDocumentMapper.noteToJson),
        ],
        'links': [
          for (final q in j.linkedQuoteIds)
            if (_fkOrNull(q) != null) {'quote_id': q},
          for (final i in j.linkedInvoiceIds)
            if (_fkOrNull(i) != null) {'invoice_id': i},
        ],
      };

      final result =
          await SupabaseService().client.rpc('save_job', params: {'p': payload});
      return result?.toString();
    } catch (e) {
      debugPrint('JobsRepository._save failed: $e');
      return null;
    }
  }

  Future<bool> updateStatus(String id, JobStatus status) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService()
          .client
          .from('jobs')
          .update({'status': status.wire})
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('JobsRepository.updateStatus failed: $e');
      return false;
    }
  }

  Future<bool> clockIn(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService()
          .client
          .from('jobs')
          .update({
            'clock_in_at': DateTime.now().toUtc().toIso8601String(),
            'status': JobStatus.active.wire,
          })
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('JobsRepository.clockIn failed: $e');
      return false;
    }
  }

  /// End the running clock session: closes it into `job_time_entries` and
  /// clears `clock_in_at`. No-op if the job wasn't clocked in.
  ///
  /// RTDB rewrote the whole `timeEntries` array on every clock-out. Here the
  /// new session is a single INSERT, so two devices closing sessions
  /// concurrently can no longer overwrite each other's hours.
  Future<bool> clockOut(Job job) async {
    final uid = _uid;
    if (uid == null) return false;
    final start = job.clockInAt;
    if (start == null) return true;
    try {
      await SupabaseService().client.from('job_time_entries').insert({
        'job_id': job.id,
        'started_at': start.toUtc().toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      });
      await SupabaseService()
          .client
          .from('jobs')
          .update({'clock_in_at': null})
          .eq('id', job.id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('JobsRepository.clockOut failed: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // Child rows go with it via ON DELETE CASCADE.
      await SupabaseService()
          .client
          .from('jobs')
          .delete()
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('JobsRepository.delete failed: $e');
      return false;
    }
  }

  /// Highest sequence we've seen so the next created job can pick up at +1.
  Future<int> nextSequence() async {
    final uid = _uid;
    if (uid == null) return 1;
    try {
      final rows = await SupabaseService()
          .client
          .from('jobs')
          .select('reference')
          .eq('owner_id', uid);
      var max = 0;
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final m = RegExp(r'(\d+)$').firstMatch(r['reference']?.toString() ?? '');
        if (m != null) {
          final n = int.tryParse(m.group(1)!);
          if (n != null && n > max) max = n;
        }
      }
      return max + 1;
    } catch (e) {
      return 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _expenseToJson(JobExpense e) => {
        'id': _fkOrNull(e.id),
        'title': e.title,
        'amount': e.amount,
        'expense_date': _dateOnly(e.date),
        'description': e.description,
        if (e.receipt != null) ...{
          'receipt_tool_asset_id': _fkOrNull(e.receipt!.id),
          // Frozen at attach time so deleting the source photo doesn't strip
          // the receipt off a saved expense.
          'receipt_snapshot': QuoteDocumentMapper.photoToJson(e.receipt!),
        },
      };

  Job _fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';

    List<Map<String, dynamic>> children(String key) {
      final raw = row[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final attachments = children('job_attachments')
      ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
          .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
    List<Map<String, dynamic>> ofKind(String k) =>
        attachments.where((a) => a['kind'] == k).toList();

    final links = children('job_links');

    return Job(
      id: id,
      reference: row['reference']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      status: JobStatusX.fromWire(row['status']?.toString()),
      customer: QuoteDocumentMapper.customerFromSnapshot(
        row['customer_snapshot'],
        row['customer_id']?.toString() ?? id,
      ),
      startDate: OwnedCollectionRepository.parseTsOr(
          row['start_date'], DateTime.now()),
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
      updatedAt: OwnedCollectionRepository.parseTs(row['updated_at']),
      clockInAt: OwnedCollectionRepository.parseTs(row['clock_in_at']),
      timeEntries: (children('job_time_entries')
            ..sort((a, b) => (a['started_at']?.toString() ?? '')
                .compareTo(b['started_at']?.toString() ?? '')))
          .map((r) => JobTimeEntry(
                start: OwnedCollectionRepository.parseTsOr(
                    r['started_at'], DateTime.now()),
                end: OwnedCollectionRepository.parseTsOr(
                    r['ended_at'], DateTime.now()),
              ))
          .toList(),
      expenses: children('job_expenses').map(_expenseFromRow).toList(),
      attachedPhotos:
          ofKind('photo').map(QuoteDocumentMapper.photoFromRow).toList(),
      attachedVideos:
          ofKind('video').map(QuoteDocumentMapper.videoFromRow).toList(),
      attachedFiles:
          ofKind('file').map(QuoteDocumentMapper.fileFromRow).toList(),
      attachedNotes:
          ofKind('note').map(QuoteDocumentMapper.noteFromRow).toList(),
      linkedQuoteIds: links
          .map((l) => l['quote_id']?.toString())
          .whereType<String>()
          .toList(),
      linkedInvoiceIds: links
          .map((l) => l['invoice_id']?.toString())
          .whereType<String>()
          .toList(),
    );
  }

  JobExpense _expenseFromRow(Map<String, dynamic> r) {
    final snap = r['receipt_snapshot'];
    return JobExpense(
      id: r['id']?.toString() ?? '',
      title: r['title']?.toString() ?? '',
      amount: (r['amount'] as num?)?.toDouble() ?? 0,
      date: OwnedCollectionRepository.parseTsOr(
          r['expense_date'], DateTime.now()),
      description: r['description']?.toString() ?? '',
      receipt: snap is Map
          ? QuoteDocumentMapper.photoFromRow(Map<String, dynamic>.from(snap))
          : null,
    );
  }

  static String? _fkOrNull(String? id) {
    if (id == null || id.isEmpty) return null;
    final re = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return re.hasMatch(id) ? id : null;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
