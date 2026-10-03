import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/pricing/pricing_bloc.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/pricing_item.dart';
import '../../models/quote_line_draft.dart';
import 'pricing_picker_screen.dart';

export '../../models/quote_line_draft.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Result of the line edit screen — either a saved line or a delete
/// request. `null` on cancel.
sealed class QuoteLineEditResult {
  const QuoteLineEditResult();
}

class QuoteLineSaved extends QuoteLineEditResult {
  const QuoteLineSaved(this.draft);
  final QuoteLineDraft draft;
}

class QuoteLineDeleted extends QuoteLineEditResult {
  const QuoteLineDeleted(this.id);
  final String id;
}

class QuoteLineEditScreen extends StatefulWidget {
  const QuoteLineEditScreen({super.key, this.existing});

  /// When non-null, the screen opens in edit mode: all fields are
  /// pre-filled and a Delete button appears at the bottom.
  final QuoteLineDraft? existing;

  @override
  State<QuoteLineEditScreen> createState() => _QuoteLineEditScreenState();
}

class _QuoteLineEditScreenState extends State<QuoteLineEditScreen> {
  late final ShadTabsController<String> _tabsCtrl;
  PricingKind _kind = PricingKind.service;
  PricingItem? _item;

  final _rateCtrl = TextEditingController();
  final _markupCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  int _quantity = 1;

  final _rateFocus = FocusNode();
  final _markupFocus = FocusNode();
  final _discountFocus = FocusNode();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _kind = existing.kind;
      _item = existing.item;
      _rateCtrl.text = existing.rate > 0 ? _fmt(existing.rate) : '';
      _markupCtrl.text =
          existing.unitMarkup > 0 ? _fmt(existing.unitMarkup) : '';
      _discountCtrl.text = _fmt(existing.discount);
      _quantity = existing.quantity;
    }
    _tabsCtrl = ShadTabsController<String>(
      value: _kind == PricingKind.service ? 'service' : 'material',
    );
    _tabsCtrl.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabsCtrl.removeListener(_onTabChanged);
    _tabsCtrl.dispose();
    _rateCtrl.dispose();
    _markupCtrl.dispose();
    _discountCtrl.dispose();
    _rateFocus.dispose();
    _markupFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final next = _tabsCtrl.selected == 'service'
        ? PricingKind.service
        : PricingKind.material;
    if (next == _kind) return;
    // Switching kind wipes the current item + line fields, since a
    // service's rate doesn't carry over to a material.
    setState(() {
      _kind = next;
      _item = null;
      _rateCtrl.clear();
      _markupCtrl.clear();
      _discountCtrl.text = '0';
      _quantity = 1;
    });
  }

  double _parseAmount(String raw) {
    final t = raw.replaceAll('£', '').trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  String _fmt(double v) {
    // Format to at most 2 decimals, then strip any trailing zeros so 160.0
    // reads as "160" and 160.50 reads as "160.5". Tolerates FP noise.
    final s = v.toStringAsFixed(2);
    if (!s.contains('.')) return s;
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  double _parsePercent(String raw) {
    final t = raw.replaceAll('%', '').trim();
    if (t.isEmpty) return 0;
    final v = double.tryParse(t) ?? 0;
    return v.clamp(0, 100).toDouble();
  }

  double get _total {
    final r = _parseAmount(_rateCtrl.text);
    // Unit markup applies to materials only — services are charged at rate.
    final m = _kind == PricingKind.material
        ? _parseAmount(_markupCtrl.text)
        : 0.0;
    final d = _parsePercent(_discountCtrl.text);
    final base = (r + m) * _quantity;
    final after = base * (1 - (d / 100));
    return after < 0 ? 0 : after;
  }

  Future<void> _pickItem() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<PricingItem>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PricingBloc>(),
          child: PricingPickerScreen(kind: _kind),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _item = picked;
      _rateCtrl.text = picked.unitCost > 0 ? _fmt(picked.unitCost) : '';
      _markupCtrl.text =
          (_kind == PricingKind.material && picked.unitMarkup > 0)
              ? _fmt(picked.unitMarkup)
              : '';
      _discountCtrl.text = '0';
      _quantity = 1;
    });
  }

  void _done() {
    if (_item == null) {
      CommonToasts.error(context, 'Select an item');
      return;
    }
    final draft = QuoteLineDraft(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      kind: _kind,
      item: _item!,
      rate: _parseAmount(_rateCtrl.text),
      unitMarkup: _kind == PricingKind.material
          ? _parseAmount(_markupCtrl.text)
          : 0,
      discount: _parsePercent(_discountCtrl.text),
      quantity: _quantity,
    );
    Navigator.of(context).pop(QuoteLineSaved(draft));
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Remove this item?',
      message: 'This line will be removed from the quote.',
      icon: LucideIcons.trash2,
      yesText: 'Remove',
      noText: 'Cancel',
      onConfirm: () {
        Navigator.of(context).pop(QuoteLineDeleted(existing.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _kind == PricingKind.service
        ? 'Select a service'
        : 'Select a material';
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
        title: Text(_isEditing ? 'Edit item' : 'Add item'),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text(
              'Done',
              style: TextStyle(
                color: _brand,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
        bottom: _isEditing
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: ShadTabs<String>(
                    controller: _tabsCtrl,
                    tabs: const [
                      ShadTab(
                        value: 'service',
                        content: SizedBox.shrink(),
                        child: Text('Service'),
                      ),
                      ShadTab(
                        value: 'material',
                        content: SizedBox.shrink(),
                        child: Text('Material'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _TotalCard(total: _total),

            _Group(
              children: [
                _PickerRow(
                  label: _kind == PricingKind.service
                      ? 'Service'
                      : 'Material',
                  value: _item?.name,
                  placeholder: placeholder,
                  onTap: _pickItem,
                ),
              ],
            ),

            if (_item != null)
              _Group(
                children: [
                  _MoneyRow(
                    label: 'Rate',
                    controller: _rateCtrl,
                    focusNode: _rateFocus,
                    onChanged: () => setState(() {}),
                  ),
                  // Unit markup is a materials-only concept — services are
                  // charged at their rate with no hidden markup.
                  if (_kind == PricingKind.material) ...[
                    const _HairlineDivider(),
                    _MoneyRow(
                      label: 'Unit markup',
                      controller: _markupCtrl,
                      focusNode: _markupFocus,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  const _HairlineDivider(),
                  _PercentRow(
                    label: 'Discount %',
                    controller: _discountCtrl,
                    focusNode: _discountFocus,
                    onChanged: () => setState(() {}),
                  ),
                  const _HairlineDivider(),
                  _QuantityRow(
                    value: _quantity,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                ],
              ),

            if (_isEditing) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(
                    'Delete item',
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});
  final double total;

  String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text(
            'Total',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            _fmtMoney(total),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                hasValue ? value! : (placeholder ?? ''),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? _brand : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatefulWidget {
  const _MoneyRow({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  State<_MoneyRow> createState() => _MoneyRowState();
}

class _MoneyRowState extends State<_MoneyRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_emitChange);
    // Prefix the existing value with £ so the field reads "£50" on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = widget.controller;
      final plain = ctrl.text.replaceAll('£', '').trim();
      if (plain.isNotEmpty && !ctrl.text.contains('£')) {
        ctrl.text = '£$plain';
      }
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_emitChange);
    super.dispose();
  }

  void _emitChange() => widget.onChanged();

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
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_MoneyInputFormatter()],
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentRow extends StatefulWidget {
  const _PercentRow({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  State<_PercentRow> createState() => _PercentRowState();
}

class _PercentRowState extends State<_PercentRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_emitChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = widget.controller;
      final plain = ctrl.text.replaceAll('%', '').trim();
      if (plain.isNotEmpty && !ctrl.text.contains('%')) {
        ctrl.text = '$plain%';
      }
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_emitChange);
    super.dispose();
  }

  void _emitChange() => widget.onChanged();

  void _onFocusChange() {
    final ctrl = widget.controller;
    if (widget.focusNode.hasFocus) {
      if (ctrl.text.contains('%')) {
        final plain = ctrl.text.replaceAll('%', '').trim();
        ctrl.value = TextEditingValue(
          text: plain,
          selection: TextSelection.collapsed(offset: plain.length),
        );
      }
    } else {
      final plain = ctrl.text.replaceAll('%', '').trim();
      if (plain.isEmpty) {
        if (ctrl.text.isNotEmpty) ctrl.text = '';
      } else {
        ctrl.text = '$plain%';
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
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_PercentInputFormatter()],
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d{0,3}(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (!_pattern.hasMatch(newValue.text)) return oldValue;
    final v = double.tryParse(newValue.text);
    if (v != null && v > 100) return oldValue;
    return newValue;
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Quantity',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          _StepperButton(
            icon: LucideIcons.minus,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _brand,
              ),
            ),
          ),
          _StepperButton(
            icon: LucideIcons.plus,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? _brand.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _brand : Colors.grey.shade400,
        ),
      ),
    );
  }
}

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
