import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/quote_settings/quote_settings_bloc.dart';
import '../../blocs/quote_settings/quote_settings_event.dart';
import '../../blocs/quote_settings/quote_settings_state.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/quote_settings_model.dart';
import '../../models/quote_term_model.dart';
import '../../repositories/quotes/quote_settings_repository.dart';
import 'quote_term_edit_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class QuoteSettingsScreen extends StatefulWidget {
  const QuoteSettingsScreen({super.key});

  @override
  State<QuoteSettingsScreen> createState() => _QuoteSettingsScreenState();
}

class _QuoteSettingsScreenState extends State<QuoteSettingsScreen> {
  final _prefixCtrl = TextEditingController();
  final _prefixFocus = FocusNode();

  bool _autoGenerate = true;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The bloc is app-scoped, so on a re-visit its state already holds the
    // latest settings. Hydrate synchronously from it; the listener below
    // covers the first-load case when the stream hasn't emitted yet.
    final bloc = context.read<QuoteSettingsBloc>();
    if (bloc.state.status == QuoteSettingsStatus.loaded) {
      _hydrateOnce(bloc.state.settings);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuoteSettingsBloc>().add(
        const QuoteSettingsStartWatching(),
      );
    });
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _prefixFocus.dispose();
    super.dispose();
  }

  void _hydrateOnce(QuoteSettings s) {
    if (_hydrated) return;
    _autoGenerate = s.autoGenerateNumber;
    _prefixCtrl.text = s.prefix;
    _hydrated = true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final next = QuoteSettings(
      autoGenerateNumber: _autoGenerate,
      prefix: _prefixCtrl.text.trim().toUpperCase(),
    );
    final ok = await context
        .read<QuoteSettingsRepository>()
        .updateSettings(next);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      CommonToasts.success(context, 'Settings saved');
      Navigator.of(context).pop();
    } else {
      CommonToasts.error(
        context,
        'Could not save — check your connection and try again',
      );
    }
  }

  Future<void> _openTermEdit({QuoteTerm? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<QuoteSettingsBloc>(),
          child: QuoteTermEditScreen(existing: existing),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTerm(QuoteTerm t) async {
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete "${t.name}"?',
      message: 'This template will no longer be available on new quotes.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () async {
        context.read<QuoteSettingsBloc>().add(
          QuoteSettingsTermDeleteRequested(t.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuoteSettingsBloc, QuoteSettingsState>(
      listenWhen: (p, c) => p.settings != c.settings && !_hydrated,
      listener: (_, state) {
        setState(() => _hydrateOnce(state.settings));
      },
      builder: (context, state) {
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
            title: const Text('Q&I Settings'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _saving ? Colors.grey : _brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const _SectionHeader('Numbering'),
                _Group(
                  child: Column(
                    children: [
                      _ToggleRow(
                        label: 'Auto-generate number',
                        subtitle:
                            'Assigns a sequential number to each new quote',
                        value: _autoGenerate,
                        onChanged: (v) => setState(() => _autoGenerate = v),
                      ),
                      if (_autoGenerate) ...[
                        const _RowDivider(),
                        _PrefixRow(
                          controller: _prefixCtrl,
                          focusNode: _prefixFocus,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const _SectionHeader('Terms & Conditions'),
                _TermsList(
                  terms: state.terms,
                  onTap: (t) => _openTermEdit(existing: t),
                  onDelete: _confirmDeleteTerm,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openTermEdit(),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add Terms & Conditions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: _brand),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey.shade200,
      indent: 16,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShadSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrefixRow extends StatelessWidget {
  const _PrefixRow({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => focusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            const Expanded(
              child: Text('Prefix', style: TextStyle(fontSize: 15)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textAlign: TextAlign.right,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  _UpperCaseFormatter(),
                ],
                style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                decoration: const InputDecoration(
                  hintText: 'QUO',
                  counterText: '',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsList extends StatelessWidget {
  const _TermsList({
    required this.terms,
    required this.onTap,
    required this.onDelete,
  });

  final List<QuoteTerm> terms;
  final ValueChanged<QuoteTerm> onTap;
  final ValueChanged<QuoteTerm> onDelete;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return _Group(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Text(
            'No saved terms yet. Add your first below.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return _Group(
      child: Column(
        children: [
          for (var i = 0; i < terms.length; i++) ...[
            if (i > 0) const _RowDivider(),
            _TermTile(
              term: terms[i],
              onTap: () => onTap(terms[i]),
              onDelete: () => onDelete(terms[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({
    required this.term,
    required this.onTap,
    required this.onDelete,
  });

  final QuoteTerm term;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = term.details.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        term.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: preview.isEmpty
          ? null
          : Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              LucideIcons.trash2,
              size: 18,
              color: Colors.grey.shade500,
            ),
            onPressed: onDelete,
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper);
  }
}
