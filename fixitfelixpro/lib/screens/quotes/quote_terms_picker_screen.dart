import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/quote_settings/quote_settings_bloc.dart';
import '../../blocs/quote_settings/quote_settings_event.dart';
import '../../blocs/quote_settings/quote_settings_state.dart';
import '../../models/quote_term_model.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Pick which terms from the tradesman's library to attach to a quote.
/// Returns the picked subset of [QuoteTerm]s when popped via "Done".
class QuoteTermsPickerScreen extends StatefulWidget {
  const QuoteTermsPickerScreen({
    super.key,
    required this.alreadySelectedIds,
  });

  final Set<String> alreadySelectedIds;

  @override
  State<QuoteTermsPickerScreen> createState() =>
      _QuoteTermsPickerScreenState();
}

class _QuoteTermsPickerScreenState extends State<QuoteTermsPickerScreen> {
  late Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = Set<String>.from(widget.alreadySelectedIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<QuoteSettingsBloc>()
          .add(const QuoteSettingsStartWatching());
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else {
        _picked.add(id);
      }
    });
  }

  void _toggleAll(List<QuoteTerm> all) {
    setState(() {
      final allIds = all.map((t) => t.id).toSet();
      final allPicked = allIds.every(_picked.contains);
      if (allPicked) {
        _picked.removeAll(allIds);
      } else {
        _picked.addAll(allIds);
      }
    });
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
        title: const Text('Select terms'),
        actions: [
          BlocBuilder<QuoteSettingsBloc, QuoteSettingsState>(
            builder: (context, state) {
              return TextButton(
                onPressed: () {
                  final byId = {for (final t in state.terms) t.id: t};
                  final selected = _picked
                      .map((id) => byId[id])
                      .whereType<QuoteTerm>()
                      .toList();
                  Navigator.of(context).pop<List<QuoteTerm>>(selected);
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<QuoteSettingsBloc, QuoteSettingsState>(
        builder: (context, state) {
          final terms = state.terms;
          if (state.status == QuoteSettingsStatus.loading && terms.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (terms.isEmpty) {
            return const _EmptyState();
          }
          final allIds = terms.map((t) => t.id).toSet();
          final allPicked = allIds.every(_picked.contains);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
            itemCount: terms.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _SelectAllRow(
                  selected: allPicked,
                  count: terms.length,
                  onTap: () => _toggleAll(terms),
                );
              }
              final term = terms[i - 1];
              return _TermRow(
                term: term,
                selected: _picked.contains(term.id),
                onTap: () => _toggle(term.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({
    required this.selected,
    required this.count,
    required this.onTap,
  });
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _Checkbox(selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected ? 'Deselect all' : 'Select all',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '$count term${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.term,
    required this.selected,
    required this.onTap,
  });
  final QuoteTerm term;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _Checkbox(selected: selected),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      term.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (term.details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        term.details,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
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

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? _brand : Colors.white,
        border: Border.all(
          color: selected ? _brand : Colors.grey.shade400,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: selected
          ? const Icon(LucideIcons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No terms saved yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add reusable terms in Quote settings, then attach them here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
