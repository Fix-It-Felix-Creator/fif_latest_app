import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/staff/staff_bloc.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/quote_staff_draft.dart';
import '../../models/staff.dart';
import '../staff/staff_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Result of the staff line edit screen — saved draft, or a delete
/// request. `null` on cancel.
sealed class QuoteStaffEditResult {
  const QuoteStaffEditResult();
}

class QuoteStaffSaved extends QuoteStaffEditResult {
  const QuoteStaffSaved(this.draft);
  final QuoteStaffDraft draft;
}

class QuoteStaffDeleted extends QuoteStaffEditResult {
  const QuoteStaffDeleted(this.id);
  final String id;
}

class QuoteStaffEditScreen extends StatefulWidget {
  const QuoteStaffEditScreen({super.key, this.existing});

  /// When non-null the screen opens in edit mode, pre-fills every
  /// field, and shows a Delete button at the bottom.
  final QuoteStaffDraft? existing;

  @override
  State<QuoteStaffEditScreen> createState() => _QuoteStaffEditScreenState();
}

class _QuoteStaffEditScreenState extends State<QuoteStaffEditScreen> {
  Staff? _staff;
  StaffPayType _payType = StaffPayType.day;
  LabourRateType _rateType = LabourRateType.standard;

  final _rateCtrl = TextEditingController();
  int _quantity = 1;

  final _rateFocus = FocusNode();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _staff = existing.staff;
      _payType = existing.payType;
      _rateType = existing.rateType;
      _rateCtrl.text = existing.rate > 0 ? _fmt(existing.rate) : '';
      _quantity = existing.quantity;
    }
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  double _parseAmount(String raw) {
    final t = raw.replaceAll('£', '').trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    if (!s.contains('.')) return s;
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  double get _total {
    final r = _parseAmount(_rateCtrl.text);
    final base = r * _quantity;
    return base < 0 ? 0 : base;
  }

  /// Switch the labour rate method, refilling the rate field with the
  /// staff member's configured amount for that method.
  void _selectRateType(LabourRateType type) {
    final staff = _staff;
    if (staff == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final r = staff.rateFor(type);
    setState(() {
      _rateType = type;
      _rateCtrl.text = r > 0 ? _fmt(r) : '';
    });
  }

  Future<void> _pickStaff() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<Staff>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<StaffBloc>(),
          child: const StaffScreen(pickMode: true),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _staff = picked;
      _payType = picked.defaultPayType;
      _rateType = LabourRateType.standard;
      _rateCtrl.text = picked.rate > 0 ? _fmt(picked.rate) : '';
      _quantity = 1;
    });
  }

  void _done() {
    if (_staff == null) {
      CommonToasts.error(context, 'Select a staff member');
      return;
    }
    final draft = QuoteStaffDraft(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      staff: _staff!,
      payType: _payType,
      rateType: _rateType,
      rate: _parseAmount(_rateCtrl.text),
      quantity: _quantity,
    );
    Navigator.of(context).pop(QuoteStaffSaved(draft));
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Remove this staff line?',
      message: 'This staff member will be removed from the quote.',
      icon: LucideIcons.trash2,
      yesText: 'Remove',
      noText: 'Cancel',
      onConfirm: () {
        Navigator.of(context).pop(QuoteStaffDeleted(existing.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        _staff == null ? 'Select staff' : _staff!.name;
    final qtyLabel =
        _payType == StaffPayType.day ? 'Days' : 'Hours';
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
        title: Text(_isEditing ? 'Edit staff' : 'Add staff'),
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
                  label: 'Staff',
                  value: _staff?.name,
                  placeholder: placeholder,
                  onTap: _pickStaff,
                ),
              ],
            ),

            if (_staff != null)
              _Group(
                children: [
                  _RateMethodRow(
                    staff: _staff!,
                    selected: _rateType,
                    onSelected: _selectRateType,
                  ),
                  const _HairlineDivider(),
                  _MoneyRow(
                    label: '${_rateType.label} rate',
                    controller: _rateCtrl,
                    focusNode: _rateFocus,
                    onChanged: () => setState(() {}),
                  ),
                  const _HairlineDivider(),
                  _QuantityRow(
                    label: qtyLabel,
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
                    'Delete staff',
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

/// Dropdown selector for the labour rate method. Each option shows the
/// method name and the staff member's effective rate for it, so the
/// choice is transparent before it lands on the customer quote.
class _RateMethodRow extends StatelessWidget {
  const _RateMethodRow({
    required this.staff,
    required this.selected,
    required this.onSelected,
  });

  final Staff staff;
  final LabourRateType selected;
  final ValueChanged<LabourRateType> onSelected;

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rate method',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<LabourRateType>(
              value: selected,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              icon: const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: _brand,
                ),
              ),
              onChanged: (v) {
                if (v != null) onSelected(v);
              },
              selectedItemBuilder: (context) => [
                for (final t in LabourRateTypeX.all)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${t.label} rate',
                      style: const TextStyle(
                        fontSize: 15,
                        color: _brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              items: [
                for (final t in LabourRateTypeX.all)
                  DropdownMenuItem<LabourRateType>(
                    value: t,
                    child: Text(
                      '${t.label}  ·  £${_fmt(staff.rateFor(t))}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
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

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
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
