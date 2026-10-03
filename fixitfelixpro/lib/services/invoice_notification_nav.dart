import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/invoices/invoices_bloc.dart';
import '../core/utils/common_toasts.dart';
import '../globals.dart';
import '../models/invoice_model.dart';
import '../repositories/invoices/invoices_repository.dart';
import '../screens/invoices/new_invoice_screen.dart';

/// Invoice-related notification types fanned out by the Cloud Functions
/// (see `viewSharedInvoice.ts` / `sendEmail.ts`).
const _invoiceNotificationTypes = {'invoice_opened', 'invoice_sent'};

bool isInvoiceNotificationType(String? type) =>
    type != null && _invoiceNotificationTypes.contains(type.toLowerCase());

/// Resolves the invoice referenced by a notification payload and opens
/// its details screen. If the invoice no longer exists, no navigation
/// happens — a brief toast tells the user instead.
Future<void> openInvoiceFromNotificationPayload(
  Map<String, dynamic>? payload,
) async {
  final invoiceId = payload?['invoiceId']?.toString();
  if (invoiceId == null || invoiceId.isEmpty) {
    _showMissingToast();
    return;
  }
  await openInvoiceById(invoiceId);
}

Future<void> openInvoiceById(String invoiceId) async {
  final navigator = globalNavigatorKey.currentState;
  if (navigator == null) return;

  // Prefer the bloc's live state — by the time a notification arrives,
  // the bloc has the fresh status/viewedAt we need. One-shot findById
  // is a cold-start fallback.
  Invoice? invoice = _findInBloc(invoiceId);
  if (invoice == null) {
    try {
      invoice = await InvoicesRepository().findById(invoiceId);
    } catch (e) {
      debugPrint('openInvoiceById: findById failed: $e');
    }
  }
  if (invoice == null) {
    _showMissingToast();
    return;
  }

  navigator.pushNamed('/invoices');
  navigator.pushNamed(
    '/invoices/new',
    arguments: NewInvoiceArgs(existing: invoice),
  );
}

Invoice? _findInBloc(String invoiceId) {
  final ctx = globalNavigatorKey.currentContext;
  if (ctx == null) return null;
  try {
    final state = BlocProvider.of<InvoicesBloc>(ctx, listen: false).state;
    for (final inv in state.items) {
      if (inv.id == invoiceId) return inv;
    }
  } catch (_) {
    // BlocProvider not in scope yet (cold start) — fall through.
  }
  return null;
}

void _showMissingToast() {
  final ctx = globalNavigatorKey.currentContext;
  if (ctx == null) return;
  CommonToasts.info(ctx, 'This invoice is no longer available');
}
