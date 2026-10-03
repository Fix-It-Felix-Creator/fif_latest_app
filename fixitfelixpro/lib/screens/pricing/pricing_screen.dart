import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/pricing/pricing_bloc.dart';
import '../../blocs/pricing/pricing_event.dart';
import '../../blocs/pricing/pricing_state.dart';
import '../../models/pricing_item.dart';
import 'pricing_edit_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late final ShadTabsController<String> _tabsCtrl;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = ShadTabsController<String>(value: 'services');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PricingBloc>().add(const PricingStartWatching());
    });
  }

  @override
  void dispose() {
    _tabsCtrl.dispose();
    super.dispose();
  }

  PricingKind get _currentKind => _tabsCtrl.selected == 'services'
      ? PricingKind.service
      : PricingKind.material;

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PricingEditScreen(
          args: PricingEditArgs(kind: _currentKind),
        ),
      ),
    );
  }

  Future<void> _openEdit(PricingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PricingEditScreen(
          args: PricingEditArgs(kind: item.kind, existing: item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PricingBloc, PricingState>(
      builder: (context, state) {
        final services = state.byKind(PricingKind.service);
        final materials = state.byKind(PricingKind.material);

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
            title: const Text('Pricing'),
            actions: [
              IconButton(
                tooltip: 'Add',
                icon: const Icon(LucideIcons.plus, color: _brand),
                onPressed: _openAdd,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ShadTabs<String>(
                  controller: _tabsCtrl,
                  tabs: [
                    ShadTab(
                      value: 'services',
                      content: const SizedBox.shrink(),
                      child: Text('Services (${services.length})'),
                    ),
                    ShadTab(
                      value: 'materials',
                      content: const SizedBox.shrink(),
                      child: Text('Materials (${materials.length})'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: state.status == PricingStatus.loading && state.items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: _brand),
                )
              : ListenableBuilder(
                  listenable: _tabsCtrl,
                  builder: (context, _) {
                    final items = _currentKind == PricingKind.service
                        ? services
                        : materials;
                    if (items.isEmpty) {
                      final isServices = _currentKind == PricingKind.service;
                      return _EmptyState(
                        label:
                            isServices ? 'No services yet' : 'No materials yet',
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
                        onTap: () => _openEdit(items[i]),
                      ),
                    );
                  },
                ),
        );
      },
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
