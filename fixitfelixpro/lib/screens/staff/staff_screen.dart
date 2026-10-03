import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/staff/staff_bloc.dart';
import '../../blocs/staff/staff_event.dart';
import '../../blocs/staff/staff_state.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/staff.dart';
import 'staff_edit_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, this.pickMode = false});

  /// When true, tapping a staff member pops the screen with the tapped
  /// [Staff] as the route result. When false (default), tapping opens
  /// the edit screen for that staff member.
  final bool pickMode;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StaffBloc>().add(const StaffStartWatching());
    });
  }

  Future<void> _openAdd() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const StaffEditScreen()),
    );
    if (!mounted) return;
    if (widget.pickMode && result is Staff) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _onTileTap(Staff s) async {
    if (widget.pickMode) {
      Navigator.of(context).pop(s);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffEditScreen(
          args: StaffEditArgs(existing: s),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.pickMode ? 'Select staff' : 'Staff'),
        actions: [
          IconButton(
            tooltip: 'Add staff',
            icon: const Icon(LucideIcons.plus),
            onPressed: _openAdd,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<StaffBloc, StaffState>(
        builder: (context, state) {
          if (state.status == StaffStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF64C13)),
            );
          }
          if (state.items.isEmpty) {
            return _EmptyState(
              pickMode: widget.pickMode,
              onAdd: _openAdd,
            );
          }
          return ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey.shade200,
              indent: 76,
            ),
            itemBuilder: (_, i) {
              final s = state.items[i];
              return _StaffTile(
                staff: s,
                onTap: () => _onTileTap(s),
              );
            },
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.staff, required this.onTap});
  final Staff staff;
  final VoidCallback onTap;

  String _subtitle() {
    final unit = staff.defaultPayType.label.toLowerCase();
    final premium = [
      staff.weekendRate,
      staff.emergencyRate,
      staff.sociableRate,
    ].where((r) => r > 0).length;
    final base = '£${_fmt(staff.rate)}/$unit';
    if (premium == 0) return base;
    return '$base  ·  +$premium premium rate${premium == 1 ? '' : 's'}';
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: avatarColorFor(staff.name),
        child: Text(
          initialsFromName(staff.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        staff.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        _subtitle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: Colors.grey.shade400,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.pickMode, required this.onAdd});

  final bool pickMode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.hardHat, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No staff yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pickMode
                ? 'Add one, then tap to select it'
                : 'Tap + to add your first',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus, size: 16, color: Color(0xFFF64C13)),
            label: const Text(
              'Add staff',
              style: TextStyle(
                color: Color(0xFFF64C13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
