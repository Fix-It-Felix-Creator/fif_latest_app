import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/customers/customers_event.dart';
import '../../blocs/customers/customers_state.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/customer.dart';
import 'customer_edit_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, this.pickMode = false});

  /// When true, tapping a customer pops the screen with the tapped
  /// [Customer] as the route result. When false (default), tapping
  /// opens the edit screen for that customer.
  final bool pickMode;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CustomersBloc>().add(const CustomersStartWatching());
    });
  }

  Future<void> _openAdd() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const CustomerEditScreen()),
    );
    if (!mounted) return;
    // Pick-mode shortcut: if a new customer was just created, auto-pop
    // the list with that customer so the caller doesn't have to tap it.
    if (widget.pickMode && result is Customer) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _onTileTap(Customer c) async {
    if (widget.pickMode) {
      Navigator.of(context).pop(c);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerEditScreen(
          args: CustomerEditArgs(existing: c),
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
        title: Text(widget.pickMode ? 'Select customer' : 'Customers'),
        actions: [
          IconButton(
            tooltip: 'Add customer',
            icon: const Icon(LucideIcons.plus),
            onPressed: _openAdd,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<CustomersBloc, CustomersState>(
        builder: (context, state) {
          if (state.status == CustomersStatus.loading && state.items.isEmpty) {
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
              final c = state.items[i];
              return _CustomerTile(
                customer: c,
                onTap: () => _onTileTap(c),
              );
            },
          );
        },
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = (customer.formattedAddress?.isNotEmpty ?? false)
        ? customer.formattedAddress!
        : customer.address;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: avatarColorFor(customer.name),
        child: Text(
          initialsFromName(customer.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        customer.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: address.isEmpty
          ? null
          : Text(
              address,
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
          Icon(LucideIcons.users, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No customers yet',
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
              'Add customer',
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
