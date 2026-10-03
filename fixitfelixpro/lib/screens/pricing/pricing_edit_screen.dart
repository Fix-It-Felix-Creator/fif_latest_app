import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/pricing_item.dart';
import '../../repositories/pricing/pricing_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class PricingEditArgs {
  const PricingEditArgs({required this.kind, this.existing});
  final PricingKind kind;
  final PricingItem? existing;
}

class PricingEditScreen extends StatefulWidget {
  const PricingEditScreen({super.key, required this.args});
  final PricingEditArgs args;

  @override
  State<PricingEditScreen> createState() => _PricingEditScreenState();
}

class _PricingEditScreenState extends State<PricingEditScreen> {
  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _markupCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _costFocus = FocusNode();
  final _markupFocus = FocusNode();
  final _codeFocus = FocusNode();

  bool _saving = false;

  bool get _isEditing => widget.args.existing != null;
  PricingKind get _kind => widget.args.kind;

  @override
  void initState() {
    super.initState();
    final e = widget.args.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _costCtrl.text = _formatAmount(e.unitCost);
      _markupCtrl.text = _formatAmount(e.unitMarkup);
      _codeCtrl.text = e.itemCode;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _markupCtrl.dispose();
    _codeCtrl.dispose();
    _nameFocus.dispose();
    _costFocus.dispose();
    _markupFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String _formatAmount(double v) {
    if (v == 0) return '';
    final plain = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    return '£$plain';
  }

  double _parseAmount(String raw) {
    final t = raw.replaceAll('£', '').trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      CommonToasts.error(context, 'Add a name');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<PricingRepository>();

    final existing = widget.args.existing;
    final now = DateTime.now();

    final item = PricingItem(
      id: existing?.id ?? '',
      kind: _kind,
      name: _nameCtrl.text.trim(),
      unitCost: _parseAmount(_costCtrl.text),
      // Unit markup applies to materials only.
      unitMarkup: _kind == PricingKind.material
          ? _parseAmount(_markupCtrl.text)
          : 0,
      itemCode: _codeCtrl.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    PricingItem? saved;
    if (existing == null) {
      final newId = await repo.create(item);
      if (newId != null) {
        saved = item.copyWith(id: newId);
      }
    } else {
      final ok = await repo.update(item);
      if (ok) saved = item;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else {
      CommonToasts.error(context, 'Could not save');
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.args.existing;
    if (existing == null) return;

    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete this ${_kind.label.toLowerCase()}?',
      message:
          'This will remove ${existing.name}. This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => _performDelete(existing.id),
    );
  }

  Future<void> _performDelete(String id) async {
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await context.read<PricingRepository>().delete(id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      CommonToasts.error(context, 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel = _kind.label.toLowerCase();
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_isEditing ? 'Edit $kindLabel' : 'New $kindLabel'),
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
            const SizedBox(height: 4),
            _Group(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _costFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Name',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            _Group(
              child: _MoneyRow(
                label: 'Unit cost',
                controller: _costCtrl,
                focusNode: _costFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => (_kind == PricingKind.material
                        ? _markupFocus
                        : _codeFocus)
                    .requestFocus(),
              ),
            ),

            // Unit markup is a materials-only concept — services are
            // charged at their cost with no hidden markup.
            if (_kind == PricingKind.material)
              _Group(
                child: _MoneyRow(
                  label: 'Unit markup',
                  controller: _markupCtrl,
                  focusNode: _markupFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _codeFocus.requestFocus(),
                ),
              ),

            _Group(
              child: _CodeRow(
                label: 'Item code',
                controller: _codeCtrl,
                focusNode: _codeFocus,
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(
                    'Delete $kindLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
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
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _MoneyRow extends StatefulWidget {
  const _MoneyRow({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.textInputAction,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;

  @override
  State<_MoneyRow> createState() => _MoneyRowState();
}

class _MoneyRowState extends State<_MoneyRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final ctrl = widget.controller;
    if (widget.focusNode.hasFocus) {
      if (ctrl.text.contains('£')) {
        final plain = ctrl.text.replaceAll('£', '').trim();
        ctrl.value = TextEditingValue(
          text: plain,
          selection: TextSelection.collapsed(offset: plain.length),
        );
      }
    } else {
      final plain = ctrl.text.replaceAll('£', '').trim();
      if (plain.isEmpty) {
        if (ctrl.text.isNotEmpty) ctrl.text = '';
      } else {
        ctrl.text = '£$plain';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.focusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_MoneyInputFormatter()],
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '0',
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

class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.label,
    required this.controller,
    required this.focusNode,
  });

  final String label;
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
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                textAlign: TextAlign.right,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  _UpperCaseFormatter(),
                ],
                style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                decoration: const InputDecoration(
                  hintText: '—',
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

/// Forces all typed characters to uppercase while preserving the caret.
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

/// Allows digits and an optional single decimal point with up to 2 pence
/// digits. Rejects anything else so the numeric keypad stays the only
/// thing the user can successfully press.
class _MoneyInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d*(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
