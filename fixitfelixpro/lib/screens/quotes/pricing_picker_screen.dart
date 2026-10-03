import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/pricing/pricing_bloc.dart';
import '../../blocs/pricing/pricing_event.dart';
import '../../blocs/pricing/pricing_state.dart';
import '../../models/pricing_item.dart';
import '../pricing/pricing_edit_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Shows only pricing items of the requested [kind]. Tapping a tile pops
/// with the selected [PricingItem]. The `+` action lets the user create
/// a new item on the fly without leaving the quote flow.
class PricingPickerScreen extends StatefulWidget {
  const PricingPickerScreen({super.key, required this.kind});

  final PricingKind kind;

  @override
  State<PricingPickerScreen> createState() => _PricingPickerScreenState();
}

class _PricingPickerScreenState extends State<PricingPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PricingBloc>().add(const PricingStartWatching());
    });
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PricingEditScreen(
          args: PricingEditArgs(kind: widget.kind),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindLabel = widget.kind.label.toLowerCase();
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
        title: Text('Select $kindLabel'),
        actions: [
          IconButton(
            tooltip: 'Add $kindLabel',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _openAdd,
          ),
        ],
      ),
      body: BlocBuilder<PricingBloc, PricingState>(
        builder: (context, state) {
          final items = state.byKind(widget.kind);
          if (state.status == PricingStatus.loading && items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (items.isEmpty) {
            return _EmptyState(
              label: 'No ${kindLabel}s yet',
              hint: 'Tap + to add your first',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey.shade200,
              indent: 16,
            ),
            itemBuilder: (_, i) => _PricingTile(
              item: items[i],
              onTap: () => Navigator.of(context).pop(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PricingTile extends StatelessWidget {
  const _PricingTile({required this.item, required this.onTap});
  final PricingItem item;
  final VoidCallback onTap;

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String _subtitle() {
    final isMaterial = item.kind == PricingKind.material;
    final total = item.unitCost + (isMaterial ? item.unitMarkup : 0);
    final parts = <String>['£${_fmt(total)}'];
    if (isMaterial && item.unitMarkup > 0) {
      parts.add('inc £${_fmt(item.unitMarkup)} markup');
    }
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        item.name,
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
  const _EmptyState({required this.label, required this.hint});
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
