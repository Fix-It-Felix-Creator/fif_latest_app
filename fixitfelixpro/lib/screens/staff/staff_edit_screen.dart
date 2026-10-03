import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/staff.dart';
import '../../repositories/staff/staff_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class StaffEditArgs {
  const StaffEditArgs({this.existing});
  final Staff? existing;
}

class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen({super.key, this.args});
  final StaffEditArgs? args;

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _weekendCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _sociableCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _weekendFocus = FocusNode();
  final _emergencyFocus = FocusNode();
  final _sociableFocus = FocusNode();

  StaffPayType _payType = StaffPayType.day;
  bool _saving = false;

  bool get _isEditing => widget.args?.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.args?.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emailCtrl.text = e.email;
      _phoneCtrl.text = e.phone;
      _rateCtrl.text = _formatAmount(e.rate);
      _weekendCtrl.text = _formatAmount(e.weekendRate);
      _emergencyCtrl.text = _formatAmount(e.emergencyRate);
      _sociableCtrl.text = _formatAmount(e.sociableRate);
      _payType = e.defaultPayType;
    }

    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _rateCtrl.dispose();
    _weekendCtrl.dispose();
    _emergencyCtrl.dispose();
    _sociableCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _rateFocus.dispose();
    _weekendFocus.dispose();
    _emergencyFocus.dispose();
    _sociableFocus.dispose();
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
      CommonToasts.error(context, 'Add a staff name');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<StaffRepository>();

    final existing = widget.args?.existing;
    final now = DateTime.now();

    final staff = Staff(
      id: existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      defaultPayType: _payType,
      rate: _parseAmount(_rateCtrl.text),
      weekendRate: _parseAmount(_weekendCtrl.text),
      emergencyRate: _parseAmount(_emergencyCtrl.text),
      sociableRate: _parseAmount(_sociableCtrl.text),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Staff? saved;
    if (existing == null) {
      final newId = await repo.create(staff);
      if (newId != null) {
        saved = staff.copyWith(id: newId);
      }
    } else {
      final ok = await repo.update(staff);
      if (ok) saved = staff;
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
    final existing = widget.args?.existing;
    if (existing == null) return;

    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete this staff member?',
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
    final ok = await context.read<StaffRepository>().delete(id);
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
    final name = _nameCtrl.text.trim();
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_isEditing ? 'Edit staff' : 'New staff'),
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
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: name.isEmpty
                      ? Colors.grey.shade300
                      : avatarColorFor(name),
                  child: Text(
                    name.isEmpty ? '?' : initialsFromName(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            _Group(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
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
              child: TextField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _emailFocus.requestFocus(),
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Phone',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            _Group(
              child: TextField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _rateFocus.requestFocus(),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Email',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            _SectionHeader('Pay'),

            _Group(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Default pay type',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                    _PayTypeToggle(
                      value: _payType,
                      onChanged: (v) => setState(() => _payType = v),
                    ),
                  ],
                ),
              ),
            ),

            _Group(
              child: _MoneyRow(
                label: 'Standard rate',
                controller: _rateCtrl,
                focusNode: _rateFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _weekendFocus.requestFocus(),
              ),
            ),

            _SectionHeader('Premium rates'),

            _Group(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MoneyRow(
                    label: 'Weekend rate',
                    controller: _weekendCtrl,
                    focusNode: _weekendFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _emergencyFocus.requestFocus(),
                  ),
                  const _HairlineDivider(),
                  _MoneyRow(
                    label: 'Emergency rate',
                    controller: _emergencyCtrl,
                    focusNode: _emergencyFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _sociableFocus.requestFocus(),
                  ),
                  const _HairlineDivider(),
                  _MoneyRow(
                    label: 'Sociable rate',
                    controller: _sociableCtrl,
                    focusNode: _sociableFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                'Leave a premium rate blank to charge the standard rate '
                'for that type of work.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _confirmDelete,
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
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
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
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

class _PayTypeToggle extends StatelessWidget {
  const _PayTypeToggle({required this.value, required this.onChanged});
  final StaffPayType value;
  final ValueChanged<StaffPayType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(StaffPayType.day, 'Day'),
          _segment(StaffPayType.hour, 'Hour'),
        ],
      ),
    );
  }

  Widget _segment(StaffPayType type, String label) {
    final selected = value == type;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _brand : Colors.grey.shade700,
          ),
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
      // Entering the field — strip any £ so the user edits just the number.
      if (ctrl.text.contains('£')) {
        final plain = ctrl.text.replaceAll('£', '').trim();
        ctrl.value = TextEditingValue(
          text: plain,
          selection: TextSelection.collapsed(offset: plain.length),
        );
      }
    } else {
      // Leaving the field — prepend £ once there is a numeric value.
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.£]')),
                ],
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
