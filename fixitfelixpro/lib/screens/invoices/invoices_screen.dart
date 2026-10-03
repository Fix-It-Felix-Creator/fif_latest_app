import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/invoices/invoices_event.dart';
import '../../blocs/invoices/invoices_state.dart';
import '../../core/enum.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/invoice_model.dart';
import 'new_invoice_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    this.pickMode = false,
    this.excludeIds = const <String>[],
  });

  /// When true the screen acts as a multi-select picker. Tapping a row
  /// toggles its check, the "+" action still pushes the regular
  /// new-invoice form (after creating you come back to the list to
  /// keep picking), and a bottom "Add (n)" bar pops with the chosen
  /// invoices.
  final bool pickMode;

  /// In pickMode, invoice ids in this list are filtered out of the
  /// visible list so the caller can hide already-linked invoices when
  /// re-opening the picker to add more.
  final List<String> excludeIds;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InvoicesBloc>().add(const InvoicesStartWatching());
    });
  }

  void _toggle(Invoice inv) {
    setState(() {
      if (_selected.contains(inv.id)) {
        _selected.remove(inv.id);
      } else {
        _selected.add(inv.id);
      }
    });
  }

  void _confirmPick(List<Invoice> all) {
    final picked =
        all.where((inv) => _selected.contains(inv.id)).toList();
    Navigator.of(context).pop<List<Invoice>>(picked);
  }

  /// Largest trailing digit-run across saved references, plus one.
  int _nextSequence(List<Invoice> invoices) {
    int max = 0;
    final tail = RegExp(r'(\d+)$');
    for (final inv in invoices) {
      final m = tail.firstMatch(inv.reference);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  Future<void> _addInvoice() async {
    final invoices = context.read<InvoicesBloc>().state.items;
    await Navigator.of(context).pushNamed(
      '/invoices/new',
      arguments: NewInvoiceArgs(nextSequence: _nextSequence(invoices)),
    );
  }

  Future<void> _editInvoice(Invoice inv) async {
    await Navigator.of(context).pushNamed(
      '/invoices/new',
      arguments: NewInvoiceArgs(existing: inv),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.pickMode ? 'Add invoices' : 'Invoices'),
        actions: [
          if (!widget.pickMode)
            IconButton(
              tooltip: 'Quote & invoice settings',
              icon: const Icon(LucideIcons.settings),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/quotes/settings'),
            ),
          IconButton(
            tooltip: 'Add invoice',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _addInvoice,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<InvoicesBloc, InvoicesState>(
        builder: (context, state) {
          if (state.status == InvoicesStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          // In pickMode, hide invoices the caller has already linked
          // so the user can't double-add the same invoice on a second
          // trip.
          final excluded = widget.excludeIds.toSet();
          final visible = widget.pickMode && excluded.isNotEmpty
              ? state.items.where((inv) => !excluded.contains(inv.id)).toList()
              : state.items;
          if (visible.isEmpty) {
            return const _EmptyState();
          }
          if (!widget.pickMode) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: visible.length,
              itemBuilder: (_, i) => _InvoiceCard(
                invoice: visible[i],
                onTap: () => _editInvoice(visible[i]),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 92),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final inv = visible[i];
                    return _InvoiceCard(
                      invoice: inv,
                      pickMode: true,
                      selected: _selected.contains(inv.id),
                      onTap: () => _toggle(inv),
                    );
                  },
                ),
              ),
              _ConfirmBar(
                count: _selected.length,
                onTap: () => _confirmPick(visible),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileText, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No invoices yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to create your first',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    this.pickMode = false,
    this.selected = false,
  });
  final Invoice invoice;
  final VoidCallback onTap;
  final bool pickMode;
  final bool selected;

  String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final customer = invoice.customer;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: pickMode && selected
            ? Border.all(color: _brand, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pickMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: _CheckBadge(selected: selected),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invoice.reference,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: invoice.status),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.title.isEmpty
                          ? (invoice.lines.isNotEmpty
                              ? invoice.lines.first.item.name
                              : invoice.reference)
                          : invoice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (customer != null) ...[
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: avatarColorFor(customer.name),
                            child: Text(
                              initialsFromName(customer.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ] else
                          Expanded(
                            child: Text(
                              'No customer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        Text(
                          _fmtMoney(invoice.total),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _brand : Colors.transparent,
        border: Border.all(
          color: selected ? _brand : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              count == 0 ? 'Done' : 'Add ($count)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final InvoiceStatus status;

  ({Color bg, Color fg, String label}) _palette() {
    switch (status) {
      case InvoiceStatus.draft:
        return (
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade800,
          label: 'Draft',
        );
      case InvoiceStatus.sent:
        return (
          bg: const Color(0xFFE0E7FF),
          fg: const Color(0xFF4338CA),
          label: 'Sent',
        );
      case InvoiceStatus.paid:
        return (
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
          label: 'Paid',
        );
      case InvoiceStatus.overdue:
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          label: 'Overdue',
        );
      case InvoiceStatus.cancelled:
        return (
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade600,
          label: 'Cancelled',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        p.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: p.fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
