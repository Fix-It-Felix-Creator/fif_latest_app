import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/invoices/invoices_event.dart';
import '../../core/enum.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/customer.dart';
import '../../models/invoice_model.dart';
import '../../repositories/invoices/invoices_repository.dart';
import '../../screens/customers/customer_edit_screen.dart';
import '../../services/invoice_pdf_service.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class InvoiceSendArgs {
  const InvoiceSendArgs({required this.invoice});
  final Invoice invoice;
}

class InvoiceSendScreen extends StatefulWidget {
  const InvoiceSendScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoiceSendScreen> createState() => _InvoiceSendScreenState();
}

class _InvoiceSendScreenState extends State<InvoiceSendScreen> {
  final _messageCtrl = TextEditingController();
  bool _copying = false;
  bool _emailing = false;
  bool _sharingPdf = false;
  bool _markingPaid = false;
  bool _patchingCustomer = false;
  String? _cachedShareUrl;

  /// Latest customer block — initialised from the saved invoice but
  /// updated locally if the user adds a missing email via the
  /// "Add email" CTA below. Persisted back onto the invoice doc so
  /// the cloud function reads the updated email when sending.
  Customer? _customerOverride;

  /// Resolves the customer to display / send to, preferring the *live*
  /// record from CustomersBloc over the snapshot baked into
  /// `widget.invoice.customer` at save time. Without this, edits the
  /// user makes to a customer's email/phone/address after the invoice
  /// was drafted would not be reflected — the cloud function reads from
  /// the invoice doc and would send to the stale address. The body of
  /// the screen is wrapped in a BlocBuilder so a customer-record change
  /// (e.g. user just returned from the customer-edit screen) repaints
  /// the customer card and Send button state without manual refresh.
  Customer get _customer {
    final id = (_customerOverride?.id ?? widget.invoice.customer?.id ?? '')
        .trim();
    if (id.isNotEmpty) {
      final items = context.read<CustomersBloc>().state.items;
      for (final c in items) {
        if (c.id == id) return c;
      }
    }
    return _customerOverride ??
        widget.invoice.customer ??
        Customer(id: '', name: '');
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<bool> _markSent() {
    return context.read<InvoicesRepository>().markAsSent(widget.invoice.id);
  }

  /// Push the customer edit screen with the current customer pre-filled.
  /// On return, look up the freshly-saved record from CustomersBloc and
  /// — if email was added — patch the invoice doc so the send-email
  /// cloud function (which reads from RTDB) can actually use it.
  Future<void> _addCustomerEmail() async {
    if (_patchingCustomer) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final current = _customer;
    if (current.id.isEmpty) {
      CommonToasts.error(
        context,
        'Open the invoice and pick a customer first',
      );
      return;
    }
    await Navigator.of(context).pushNamed(
      '/customerEdit',
      arguments: CustomerEditArgs(existing: current),
    );
    if (!mounted) return;

    Customer? updated;
    try {
      final state = context.read<CustomersBloc>().state;
      for (final c in state.items) {
        if (c.id == current.id) {
          updated = c;
          break;
        }
      }
    } catch (_) {}
    if (updated == null) return;
    if (updated.email.trim().isEmpty) return;

    setState(() {
      _customerOverride = updated;
      _patchingCustomer = true;
    });
    final patched = widget.invoice.copyWith(customer: updated);
    await context.read<InvoicesRepository>().update(patched);
    if (!mounted) return;
    setState(() => _patchingCustomer = false);
  }

  Future<void> _sendByEmail() async {
    if (_emailing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _emailing = true);
    try {
      // Push the latest customer snapshot onto the invoice doc before
      // the cloud function reads it — otherwise edits the user made to
      // the customer record (email, phone, address) after this draft
      // was last saved would be ignored, and the email would go to the
      // stale address.
      await _syncLiveCustomerToInvoice();
      if (!mounted) return;

      final result = await context
          .read<InvoicesRepository>()
          .sendInvoiceEmail(
            widget.invoice.id,
            message: _messageCtrl.text,
          );
      if (!mounted) return;
      if (result.ok) {
        CommonToasts.success(context, 'Email sent to $_firstName');
        Navigator.of(context).pop();
      } else {
        CommonToasts.error(
          context,
          result.error ?? 'Could not send email',
        );
      }
    } finally {
      if (mounted) setState(() => _emailing = false);
    }
  }

  Future<void> _sendAsPdf() async {
    if (_sharingPdf) return;
    setState(() => _sharingPdf = true);
    final user = context.read<AuthBloc>().state.userDetails;
    try {
      final marked = await _markSent();
      if (!mounted) return;
      if (!marked) {
        CommonToasts.error(context, "Couldn't update the invoice. Try again.");
        return;
      }
      final bytes = await InvoicePdfService().build(
        invoice: widget.invoice,
        user: user,
      );
      if (!mounted) return;
      final ref = widget.invoice.reference.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final filename =
          'invoice-${ref.isEmpty ? widget.invoice.id : ref}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not generate PDF');
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  Future<void> _copyShareLink() async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      final marked = await _markSent();
      if (!mounted) return;
      if (!marked) {
        CommonToasts.error(context, "Couldn't update the invoice. Try again.");
        return;
      }
      String? url = _cachedShareUrl;
      url ??= await context
          .read<InvoicesRepository>()
          .getShareLink(widget.invoice.id);
      if (!mounted) return;
      if (url == null) {
        CommonToasts.error(context, "Couldn't generate link. Try again.");
        return;
      }
      _cachedShareUrl = url;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      CommonToasts.success(context, 'Link copied to clipboard');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _markPaid() async {
    if (_markingPaid) return;
    bool confirmed = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Mark invoice as paid?',
      message:
          'This stamps the invoice as paid right now. You can\'t undo it '
          'from the app.',
      icon: LucideIcons.circleCheck,
      yesText: 'Mark as paid',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _markingPaid = true);
    try {
      context
          .read<InvoicesBloc>()
          .add(InvoiceMarkPaidRequested(widget.invoice.id));
      if (!mounted) return;
      CommonToasts.success(context, 'Invoice marked as paid');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  String get _firstName {
    final name = _customer.name.trim();
    if (name.isEmpty) return 'customer';
    final space = name.indexOf(' ');
    return space == -1 ? name : name.substring(0, space);
  }

  /// If the live customer record differs from the snapshot stored on
  /// the invoice doc, write the live record onto the doc. Best-effort —
  /// silent on failure so the user can still attempt to send (worst
  /// case: stale address, same behaviour as before this fix). Skipped
  /// when there's no customer id or the bloc doesn't know the record.
  Future<void> _syncLiveCustomerToInvoice() async {
    final live = _customer;
    if (live.id.isEmpty) return;
    final stored = widget.invoice.customer;
    if (stored != null && stored == live) return;
    try {
      final patched = widget.invoice.copyWith(customer: live);
      await context.read<InvoicesRepository>().update(patched);
    } catch (_) {
      // Non-fatal — fall through to send with whatever is on the doc.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to CustomersBloc so the customer card + Send button
    // repaint when the user returns from the customer-edit screen with
    // a fresh email / phone / address. The state value isn't used here
    // directly — `_customer` reads through context.read on each call.
    context.watch<CustomersBloc>();
    final customer = _customer;
    final hasEmail = customer.email.trim().isNotEmpty;
    final isPaid = widget.invoice.status == InvoiceStatus.paid;
    final isDraft = widget.invoice.status == InvoiceStatus.draft;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(onTap: () => Navigator.of(context).pop()),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const SizedBox(height: 4),
            const Text(
              'All set — let\'s\nget it to them',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pick how your customer should receive this invoice.\n'
              'We\'ll ping you the moment they open it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 28),

            const _SectionHeader('Email to customer'),
            const SizedBox(height: 8),
            _CustomerCard(customer: customer),
            const SizedBox(height: 18),

            const Text(
              'Personal note (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _MessageField(controller: _messageCtrl),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: !hasEmail || _emailing ? null : _sendByEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: _emailing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Send to $_firstName'),
              ),
            ),
            const SizedBox(height: 12),
            if (!hasEmail)
              _AddEmailBanner(
                customerName: customer.name,
                busy: _patchingCustomer,
                onTap: _addCustomerEmail,
              )
            else
              Text(
                'Sent on your behalf from our system, branded with your '
                'company details. Hook up your own reply-to address any '
                'time from Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(height: 22),

            const _OrDivider(),
            const SizedBox(height: 18),

            const _SectionHeader('Other ways to share'),
            const SizedBox(height: 8),
            _ShareTile(
              icon: LucideIcons.link2,
              label: _copying ? 'Generating link…' : 'Copy a shareable link',
              onTap: _copying ? null : _copyShareLink,
            ),
            const SizedBox(height: 10),
            _ShareTile(
              icon: LucideIcons.share,
              label: _sharingPdf ? 'Generating PDF…' : 'Send as PDF',
              onTap: _sharingPdf ? null : _sendAsPdf,
            ),

            if (!isDraft && !isPaid) ...[
              const SizedBox(height: 26),
              const _SectionHeader('Once paid'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _markingPaid ? null : _markPaid,
                  icon: const Icon(LucideIcons.circleCheck, size: 18),
                  label: Text(
                    _markingPaid ? 'Updating…' : 'Mark this invoice as paid',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF065F46),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],

            if (isPaid) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      LucideIcons.circleCheck,
                      size: 18,
                      color: Color(0xFF065F46),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This invoice is already marked as paid.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade300,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(LucideIcons.x, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final hasEmail = customer.email.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColorFor(customer.name),
            child: Text(
              initialsFromName(customer.name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customer.name.isEmpty ? 'Customer' : customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasEmail ? customer.email : 'Email needed to send',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasEmail
                        ? Colors.grey.shade700
                        : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText:
              "e.g. Hi! Here's the invoice for the work completed —\nthanks for your business.",
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            height: 1.4,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.5)),
      ],
    );
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _brand),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddEmailBanner extends StatelessWidget {
  const _AddEmailBanner({
    required this.customerName,
    required this.busy,
    required this.onTap,
  });

  final String customerName;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstName = customerName.split(' ').first;
    final ctaName = firstName.isEmpty ? 'this customer' : firstName;
    return Material(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                LucideIcons.mailWarning,
                size: 18,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add email to send',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      busy
                          ? 'Updating customer…'
                          : '$ctaName needs an email before we can email this invoice',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Color(0xFFB45309),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
