import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/config_service.dart';
import '../../core/enum.dart';
import '../../core/services/supabase_service.dart';
import '../../models/bank_details_model.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_payment_method.dart';
import '../base/owned_collection_repository.dart';
import '../quotes/quote_document_mapper.dart';

/// CRUD + live stream for invoices.
///
/// RTDB stored an invoice as ONE node with nested `lines`, `staff`, `terms` and
/// `attached*` arrays. Postgres splits it across `invoices` plus four child
/// tables, so every save goes through the `save_invoice` RPC, which writes the
/// whole document in a single transaction — a partial write would leave a
/// invoice with only some of its line items and a total that no longer adds up.
///
/// Customer, staff and pricing details are still denormalised into the
/// document so a saved invoice survives the source records changing or being
/// deleted.
class InvoicesRepository {
  /// Every column needed to rebuild a whole document in one round trip.
  static const String _documentSelect = '''
*,
invoice_lines(*),
invoice_labour_lines(*),
invoice_terms(*),
invoice_attachments(*)
''';

  String? get _uid => SupabaseService().auth.currentUser?.id;

  String? get _accessToken =>
      SupabaseService().auth.currentSession?.accessToken;

  /// One-shot read of a single invoice owned by the current user. Used by the
  /// notification tap-to-open flow which can't easily wait on the live stream.
  Future<Invoice?> findById(String id) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('InvoicesRepository.findById: not signed in');
      return null;
    }
    try {
      final row = await SupabaseService()
          .client
          .from('invoices')
          .select(_documentSelect)
          .eq('id', id)
          .eq('owner_id', uid)
          .maybeSingle();
      if (row == null) {
        debugPrint('InvoicesRepository.findById: $id missing');
        return null;
      }
      return _fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('InvoicesRepository.findById failed: $e');
      return null;
    }
  }

  /// Live list of the user's invoices, newest first.
  ///
  /// Supabase's realtime `stream()` returns flat rows and cannot embed child
  /// tables, so the parent stream is used purely as a change signal and each
  /// emission triggers one embedded select. That keeps documents whole rather
  /// than emitting invoices whose line items lag behind.
  Stream<List<Invoice>> watchAll() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Invoice>[]);

    final controller = StreamController<List<Invoice>>();
    StreamSubscription? sub;
    var inFlight = false;
    var pending = false;

    Future<void> refresh() async {
      // Collapse bursts: a document save touches the parent and its children,
      // which would otherwise fan out into several identical refetches.
      if (inFlight) {
        pending = true;
        return;
      }
      inFlight = true;
      try {
        final rows = await SupabaseService()
            .client
            .from('invoices')
            .select(_documentSelect)
            .eq('owner_id', uid)
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(
            List<Map<String, dynamic>>.from(rows).map(_fromRow).toList(),
          );
        }
      } catch (e) {
        debugPrint('InvoicesRepository.watchAll refresh failed: $e');
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
          .from('invoices')
          .stream(primaryKey: const ['id'])
          .eq('owner_id', uid)
          .listen(
            (_) => unawaited(refresh()),
            onError: (Object e) =>
                debugPrint('InvoicesRepository.watchAll stream error: $e'),
          );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<String?> create(Invoice inv) => _save(inv, id: null);

  Future<bool> update(Invoice inv) async => await _save(inv, id: inv.id) != null;

  /// Writes the whole document atomically via `save_invoice`.
  Future<String?> _save(Invoice inv, {String? id}) async {
    if (_uid == null) return null;
    try {
      final payload = <String, dynamic>{
        if (id != null && id.isNotEmpty) 'id': id,
        'reference': inv.reference,
        'title': inv.title,
        'status': inv.status.wire,
        'invoice_date': _dateOnly(inv.date),
        'due_date': _dateOnly(inv.dueDate),
        'total': inv.total,
        'payment_method': inv.paymentMethod.wire,
        if (inv.bankSnapshot != null && inv.bankSnapshot!.isNotEmpty)
          'bank_snapshot': inv.bankSnapshot!.toJson(),
        if (inv.customer != null) ...{
          'customer_id': _customerFk(inv.customer!.id),
          'customer_snapshot': QuoteDocumentMapper.customerToJson(inv.customer!),
        },
        // Echoed back on every save so a round-trip through the form can't
        // wipe a server-minted token; save_invoice also coalesces defensively.
        if (inv.shareToken != null && inv.shareToken!.isNotEmpty)
          'share_token': inv.shareToken,
        if (inv.sentAt != null) 'sent_at': inv.sentAt!.toUtc().toIso8601String(),
        if (inv.viewedAt != null)
          'viewed_at': inv.viewedAt!.toUtc().toIso8601String(),
        if (inv.paidAt != null) 'paid_at': inv.paidAt!.toUtc().toIso8601String(),
        'lines': inv.lines.map(QuoteDocumentMapper.lineToJson).toList(),
        'staff': inv.staff.map(QuoteDocumentMapper.labourToJson).toList(),
        'terms': inv.terms.map(QuoteDocumentMapper.termToJson).toList(),
        'attachments': [
          ...inv.attachedPhotos.map(QuoteDocumentMapper.photoToJson),
          ...inv.attachedVideos.map(QuoteDocumentMapper.videoToJson),
          ...inv.attachedFiles.map(QuoteDocumentMapper.fileToJson),
          ...inv.attachedNotes.map(QuoteDocumentMapper.noteToJson),
        ],
      };

      final result = await SupabaseService()
          .client
          .rpc('save_invoice', params: {'p': payload});
      return result?.toString();
    } catch (e) {
      debugPrint('InvoicesRepository._save failed: $e');
      return null;
    }
  }

  Future<bool> updateStatus(String id, InvoiceStatus status) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService()
          .client
          .from('invoices')
          .update({'status': status.wire})
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('InvoicesRepository.updateStatus failed: $e');
      return false;
    }
  }

  /// Flip an invoice's status to `sent` (and stamp `sentAt`) the first time it's
  /// actually shared. Idempotent — once an invoice is sent, accepted, or rejected
  /// the call is a no-op so re-shares don't rewrite the original `sentAt` or
  /// downgrade a customer-locked status.
  Future<bool> markAsSent(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final row = await SupabaseService()
          .client
          .from('invoices')
          .select('status')
          .eq('id', id)
          .eq('owner_id', uid)
          .maybeSingle();
      if (row == null) return false;

      final current = row['status']?.toString();
      if (current == 'sent' || current == 'accepted' || current == 'rejected') {
        return true;
      }

      await SupabaseService()
          .client
          .from('invoices')
          .update({
            'status': InvoiceStatus.sent.wire,
            'sent_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('InvoicesRepository.markAsSent failed: $e');
      return false;
    }
  }

  Future<bool> markAsPaid(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService()
          .client
          .from('invoices')
          .update({
            'status': InvoiceStatus.paid.wire,
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('InvoicesRepository.markAsPaid failed: $e');
      return false;
    }
  }

  /// Delete via the backend rather than deleting the row directly, so the
  /// share index can be tombstoned in the same write — without that, public
  /// viewers would see "Invoice unavailable" instead of "the tradesperson
  /// withdrew this invoice".
  Future<bool> delete(String id) async {
    final res = await _post('/invoices/delete', {'invoiceId': id});
    return res.ok;
  }

  /// Send the invoice's public share link to its customer. The backend mints the
  /// share token, flips `status -> sent`, and relays through Resend.
  Future<({bool ok, String? error})> sendInvoiceEmail(
    String invoiceId, {
    String? message,
  }) async {
    final trimmed = (message ?? '').trim();
    final res = await _post('/invoices/send-email', {
      'invoiceId': invoiceId,
      if (trimmed.isNotEmpty) 'message': trimmed,
    }, generic: 'Could not send email');
    return (ok: res.ok, error: res.error);
  }

  /// Mints (or returns the existing) public share URL for an invoice owned by the
  /// current user. Returns null on failure.
  Future<String?> getShareLink(String invoiceId) async {
    final res = await _post('/invoices/share-link', {'invoiceId': invoiceId});
    if (!res.ok || res.body == null) return null;
    try {
      final data = jsonDecode(res.body!) as Map<String, dynamic>;
      return data['url']?.toString() ?? data['shareUrl']?.toString();
    } catch (e) {
      debugPrint('InvoicesRepository.getShareLink parse failed: $e');
      return null;
    }
  }

  /// Shared transport for the document endpoints.
  ///
  /// These still speak HTTP to the configured backend; only the bearer token
  /// changed from a Firebase ID token to the Supabase session token. The
  /// endpoints themselves move to Edge Functions in Phase 5.
  Future<({bool ok, String? error, String? body})> _post(
    String path,
    Map<String, dynamic> body, {
    String generic = 'Request failed',
  }) async {
    final fallback = generic;
    try {
      final token = _accessToken;
      if (token == null) return (ok: false, error: 'Not signed in', body: null);
      final base = ConfigService().stripeBackendUrl;
      if (base.isEmpty) {
        return (ok: false, error: 'Backend not configured', body: null);
      }
      final res = await http.post(
        Uri.parse('$base$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return (ok: true, error: null, body: res.body);
      }
      debugPrint('InvoicesRepository $path ${res.statusCode}: ${res.body}');
      String? msg;
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        msg = err['message']?.toString();
      } catch (_) {}
      return (ok: false, error: msg ?? fallback, body: null);
    } catch (e) {
      debugPrint('InvoicesRepository $path failed: $e');
      return (ok: false, error: fallback, body: null);
    }
  }

  // ---------------------------------------------------------------------------
  // Row -> model
  // ---------------------------------------------------------------------------

  Invoice _fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';

    List<Map<String, dynamic>> children(String key) {
      final raw = row[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        // PostgREST does not guarantee embedded-row order.
        ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
    }

    final attachments = children('invoice_attachments');
    List<Map<String, dynamic>> ofKind(String k) =>
        attachments.where((a) => a['kind'] == k).toList();

    return Invoice(
      id: id,
      reference: row['reference']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      status: InvoiceStatusX.fromWire(row['status']?.toString()),
      customer: QuoteDocumentMapper.customerFromSnapshot(
        row['customer_snapshot'],
        row['customer_id']?.toString() ?? id,
      ),
      date: OwnedCollectionRepository.parseTsOr(
          row['invoice_date'], DateTime.now()),
      dueDate: OwnedCollectionRepository.parseTsOr(
          row['due_date'], DateTime.now()),
      paymentMethod:
          InvoicePaymentMethodX.fromWire(row['payment_method']?.toString()),
      bankSnapshot: row['bank_snapshot'] is Map
          ? BankDetailsModel.fromJson(
              Map<String, dynamic>.from(row['bank_snapshot'] as Map))
          : null,
      staff: children('invoice_labour_lines')
          .map(QuoteDocumentMapper.labourFromRow)
          .toList(),
      lines:
          children('invoice_lines').map(QuoteDocumentMapper.lineFromRow).toList(),
      total: (row['total'] as num?)?.toDouble() ?? 0,
      createdAt: OwnedCollectionRepository.parseTsOr(
          row['created_at'], DateTime.now()),
      sentAt: OwnedCollectionRepository.parseTs(row['sent_at']),
      viewedAt: OwnedCollectionRepository.parseTs(row['viewed_at']),
      paidAt: OwnedCollectionRepository.parseTs(row['paid_at']),
      shareToken: row['share_token']?.toString(),
      terms:
          children('invoice_terms').map(QuoteDocumentMapper.termFromRow).toList(),
      attachedPhotos:
          ofKind('photo').map(QuoteDocumentMapper.photoFromRow).toList(),
      attachedVideos:
          ofKind('video').map(QuoteDocumentMapper.videoFromRow).toList(),
      attachedFiles:
          ofKind('file').map(QuoteDocumentMapper.fileFromRow).toList(),
      attachedNotes:
          ofKind('note').map(QuoteDocumentMapper.noteFromRow).toList(),
    );
  }

  /// `customer_id` is a real FK to `customers`; a draft customer typed inline
  /// has no row to point at, so only a UUID is sent.
  static String? _customerFk(String id) {
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
