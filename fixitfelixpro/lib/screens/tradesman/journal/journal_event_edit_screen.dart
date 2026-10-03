import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../models/customer.dart';
import '../../../models/journal_entry.dart';
import '../../../repositories/journal/journal_repository.dart';
import '../../customers/customers_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class JournalEditArgs {
  const JournalEditArgs({this.existing, this.initialDate});
  final JournalEntry? existing;
  final DateTime? initialDate;
}

class PickedCustomer {
  const PickedCustomer({
    required this.id,
    required this.name,
    this.address,
  });
  final String id;
  final String name;
  final String? address;
}

class JournalEventEditScreen extends StatefulWidget {
  const JournalEventEditScreen({super.key, this.args});

  final JournalEditArgs? args;

  @override
  State<JournalEventEditScreen> createState() => _JournalEventEditScreenState();
}

class _JournalEventEditScreenState extends State<JournalEventEditScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late DateTime _date;
  bool _allDay = false;
  late DateTime _startAt;
  late DateTime _endAt;

  PickedCustomer? _customer;
  bool _locationFromCustomer = false;
  bool _saving = false;

  bool get _isEditing => widget.args?.existing != null;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    final existing = args?.existing;
    final now = DateTime.now();

    if (existing != null) {
      _titleCtrl.text = existing.title;
      _locationCtrl.text = existing.location ?? '';
      _notesCtrl.text = existing.notes ?? '';
      _date = existing.dateObj;
      _allDay = existing.allDay;
      _startAt = existing.startAtObj ??
          DateTime(_date.year, _date.month, _date.day, 9);
      _endAt = existing.endAtObj ??
          DateTime(_date.year, _date.month, _date.day, 10);
      if (existing.customerId != null) {
        _customer = PickedCustomer(
          id: existing.customerId!,
          name: existing.customerName ?? 'Customer',
        );
      }
    } else {
      _date = args?.initialDate ?? DateTime(now.year, now.month, now.day);
      _startAt =
          DateTime(_date.year, _date.month, _date.day, now.hour, 0);
      _endAt = _startAt.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: _brand),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _startAt = DateTime(
          _date.year, _date.month, _date.day, _startAt.hour, _startAt.minute);
      _endAt = DateTime(
          _date.year, _date.month, _date.day, _endAt.hour, _endAt.minute);
    });
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start ? _startAt : _endAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: _brand),
        ),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      final d = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);
      if (start) {
        _startAt = d;
        if (!_endAt.isAfter(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = d;
      }
    });
  }

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => const CustomersScreen(pickMode: true),
      ),
    );
    if (picked == null) return;
    final address = (picked.formattedAddress?.isNotEmpty ?? false)
        ? picked.formattedAddress
        : (picked.address.isEmpty ? null : picked.address);
    setState(() {
      _customer = PickedCustomer(
        id: picked.id,
        name: picked.name,
        address: address,
      );
      if (address != null &&
          (_locationCtrl.text.isEmpty || _locationFromCustomer)) {
        _locationCtrl.text = address;
        _locationFromCustomer = true;
      }
    });
  }

  void _clearCustomer() {
    setState(() {
      _customer = null;
      if (_locationFromCustomer) {
        _locationCtrl.clear();
        _locationFromCustomer = false;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_titleCtrl.text.trim().isEmpty) {
      CommonToasts.error(context, 'Add an event name');
      return;
    }
    if (!_allDay && !_endAt.isAfter(_startAt)) {
      CommonToasts.error(context, 'End time must be after start time');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<JournalRepository>();
    final existing = widget.args?.existing;

    final ok = existing == null
        ? await repo.create(
              title: _titleCtrl.text.trim(),
              date: _date,
              allDay: _allDay,
              startAt: _allDay ? null : _startAt,
              endAt: _allDay ? null : _endAt,
              customerId: _customer?.id,
              customerName: _customer?.name,
              location: _locationCtrl.text.trim().isEmpty
                  ? null
                  : _locationCtrl.text.trim(),
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ) !=
            null
        : await repo.update(
            id: existing.id,
            title: _titleCtrl.text.trim(),
            date: _date,
            allDay: _allDay,
            startAt: _allDay ? null : _startAt,
            endAt: _allDay ? null : _endAt,
            customerId: _customer?.id,
            customerName: _customer?.name,
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      CommonToasts.error(context, 'Could not save, please try again');
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.args?.existing;
    if (existing == null) return;

    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete this entry?',
      message:
          'This will permanently remove "${existing.title}". This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => _performDelete(existing.id),
    );
  }

  Future<void> _performDelete(String id) async {
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await context.read<JournalRepository>().delete(id);
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
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
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
          // Title card — big, plain, no frills
          _Group(
            child: TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Event name',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Date + time card
          _Group(
            children: [
              _Row(
                label: 'Date',
                value: _formatDate(_date),
                onTap: _pickDate,
              ),
              const _HairlineDivider(),
              _SwitchRow(
                label: 'All day',
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              if (!_allDay) ...[
                const _HairlineDivider(),
                _Row(
                  label: 'Starts',
                  value: _formatTime(_startAt),
                  onTap: () => _pickTime(true),
                ),
                const _HairlineDivider(),
                _Row(
                  label: 'Ends',
                  value: _formatTime(_endAt),
                  onTap: () => _pickTime(false),
                ),
              ],
            ],
          ),

          // Customer
          _Group(
            children: [
              _Row(
                label: 'Customer',
                value: _customer?.name ?? 'None',
                placeholder: _customer == null,
                trailingClear: _customer != null ? _clearCustomer : null,
                onTap: _pickCustomer,
              ),
            ],
          ),

          // Location + Notes — the user's focus
          _Group(
            child: TextField(
              controller: _locationCtrl,
              onChanged: (_) => _locationFromCustomer = false,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Location',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          _Group(
            child: TextField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notes',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          if (_isEditing) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _saving ? null : _confirmDelete,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(
                  'Delete event',
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

  static String _formatDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  static String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Card container — groups related rows on a plain white background.
class _Group extends StatelessWidget {
  const _Group({this.child, this.children});
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child ??
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children ?? const []),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.onTap,
    this.placeholder = false,
    this.trailingClear,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool placeholder;
  final VoidCallback? trailingClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: placeholder ? Colors.grey.shade500 : _brand,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trailingClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: trailingClear,
                child: Icon(LucideIcons.x, size: 16, color: Colors.grey.shade500),
              ),
            ] else if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _brand,
          ),
        ],
      ),
    );
  }
}

