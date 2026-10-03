import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/quotes/quotes_bloc.dart';
import '../../blocs/quotes/quotes_event.dart';
import '../../blocs/quotes/quotes_state.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/quote_model.dart';
import 'new_quote_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({
    super.key,
    this.pickMode = false,
    this.excludeIds = const <String>[],
  });

  /// When true the screen acts as a multi-select picker. Tapping a row
  /// toggles its check, the "+ New" action still pushes the regular
  /// new-quote form (after creating you come back to the list to keep
  /// picking), and a bottom "Add (n)" bar pops with the chosen quotes.
  final bool pickMode;

  /// In pickMode, quote ids in this list are filtered out of the
  /// visible list so the caller can hide already-linked quotes when
  /// re-opening the picker to add more.
  final List<String> excludeIds;

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuotesBloc>().add(const QuotesStartWatching());
    });
  }

  void _toggle(Quote q) {
    setState(() {
      if (_selected.contains(q.id)) {
        _selected.remove(q.id);
      } else {
        _selected.add(q.id);
      }
    });
  }

  void _confirmPick(List<Quote> all) {
    final picked = all.where((q) => _selected.contains(q.id)).toList();
    Navigator.of(context).pop<List<Quote>>(picked);
  }

  /// Largest trailing digit-run across saved references, plus one.
  int _nextSequence(List<Quote> quotes) {
    int max = 0;
    final tail = RegExp(r'(\d+)$');
    for (final q in quotes) {
      final m = tail.firstMatch(q.reference);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  Future<void> _addQuote() async {
    final quotes = context.read<QuotesBloc>().state.items;
    await Navigator.of(context).pushNamed(
      '/quotes/new',
      arguments: NewQuoteArgs(nextSequence: _nextSequence(quotes)),
    );
  }

  Future<void> _editQuote(Quote q) async {
    await Navigator.of(context).pushNamed(
      '/quotes/new',
      arguments: NewQuoteArgs(existing: q),
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
        title: Text(widget.pickMode ? 'Add quotes' : 'Quotes'),
        actions: [
          if (!widget.pickMode)
            IconButton(
              tooltip: 'Quote & invoice settings',
              icon: const Icon(LucideIcons.settings),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/quotes/settings'),
            ),
          IconButton(
            tooltip: 'Add quote',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _addQuote,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<QuotesBloc, QuotesState>(
        builder: (context, state) {
          if (state.status == QuotesStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          // In pickMode, hide quotes the caller has already linked so
          // the user can't double-add the same quote on a second trip.
          final excluded = widget.excludeIds.toSet();
          final visible = widget.pickMode && excluded.isNotEmpty
              ? state.items.where((q) => !excluded.contains(q.id)).toList()
              : state.items;
          if (visible.isEmpty) {
            return const _EmptyState();
          }
          if (!widget.pickMode) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: visible.length,
              itemBuilder: (_, i) => _QuoteCard(
                quote: visible[i],
                onTap: () => _editQuote(visible[i]),
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
                    final q = visible[i];
                    return _QuoteCard(
                      quote: q,
                      pickMode: true,
                      selected: _selected.contains(q.id),
                      onTap: () => _toggle(q),
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
            'No quotes yet',
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

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.onTap,
    this.pickMode = false,
    this.selected = false,
  });
  final Quote quote;
  final VoidCallback onTap;
  final bool pickMode;
  final bool selected;

  String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final customer = quote.customer;
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
                          quote.reference,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: quote.status),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quote.title,
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
                          _fmtMoney(quote.total),
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
  final QuoteStatus status;

  ({Color bg, Color fg}) _palette() {
    switch (status) {
      case QuoteStatus.draft:
        return (bg: Colors.grey.shade200, fg: Colors.grey.shade800);
      case QuoteStatus.sent:
        return (
          bg: const Color(0xFFE0E7FF),
          fg: const Color(0xFF4338CA),
        );
      case QuoteStatus.accepted:
        return (
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
        );
      case QuoteStatus.rejected:
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
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
        status.label,
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
