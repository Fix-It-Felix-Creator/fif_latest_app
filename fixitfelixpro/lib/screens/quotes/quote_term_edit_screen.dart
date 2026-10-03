import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/quote_term_model.dart';
import '../../repositories/quotes/quote_settings_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class QuoteTermEditScreen extends StatefulWidget {
  const QuoteTermEditScreen({super.key, this.existing});
  final QuoteTerm? existing;

  @override
  State<QuoteTermEditScreen> createState() => _QuoteTermEditScreenState();
}

class _QuoteTermEditScreenState extends State<QuoteTermEditScreen> {
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _detailsFocus = FocusNode();

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _detailsCtrl.text = e.details;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _nameFocus.dispose();
    _detailsFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final details = _detailsCtrl.text.trim();
    if (name.isEmpty) {
      CommonToasts.error(context, 'Add a name');
      return;
    }
    if (details.isEmpty) {
      CommonToasts.error(context, 'Add the terms & conditions details');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<QuoteSettingsRepository>();
    final now = DateTime.now();

    bool ok;
    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        name: name,
        details: details,
        updatedAt: now,
      );
      ok = await repo.updateTerm(updated);
    } else {
      final created = QuoteTerm(
        id: '',
        name: name,
        details: details,
        createdAt: now,
        updatedAt: now,
      );
      final newId = await repo.createTerm(created);
      ok = newId != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      CommonToasts.error(context, 'Could not save');
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete "${existing.name}"?',
      message: 'This template will no longer be available on new quotes.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: _performDelete,
    );
  }

  Future<void> _performDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    final ok = await context
        .read<QuoteSettingsRepository>()
        .deleteTerm(existing.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      CommonToasts.error(context, 'Could not delete');
    }
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
        title: Text(_isEditing ? 'Edit terms' : 'New terms'),
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _Group(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _detailsFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Name (e.g. Payment terms)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const _SectionHeader('Details'),
            _Group(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _detailsCtrl,
                  focusNode: _detailsFocus,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                  decoration: const InputDecoration(
                    hintText:
                        'Write the full terms & conditions that should '
                        'appear on quotes using this template…',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(
                    'Delete terms',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
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
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
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
