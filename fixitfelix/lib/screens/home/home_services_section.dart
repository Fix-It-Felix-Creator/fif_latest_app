import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/services/service_catalog.dart';
import '../services/service_flow_screen.dart';
import '../services/service_selection_screen.dart';
import '../services/service_tile.dart';

/// Fewest services a category needs before it earns a section.
///
/// Below three it cannot fill a row, and a heading with one tile under it
/// reads as a mistake. Those services are still reachable — "See all" lists
/// every category, however small.
const _minForSection = 3;

/// A full second row is only drawn when there is enough to fill it.
const _fullRows = 6;

/// Services on the home screen, grouped by category.
///
/// Each category shows one row of three, or two rows of six when it has
/// enough. A category with four services shows three, not a ragged second row
/// of one — the leftovers are behind that category's own "See all".
class HomeServicesSection extends StatefulWidget {
  const HomeServicesSection({super.key});

  @override
  State<HomeServicesSection> createState() => _HomeServicesSectionState();
}

class _HomeServicesSectionState extends State<HomeServicesSection> {
  ServiceCatalog? _catalog;

  @override
  void initState() {
    super.initState();
    ServiceCatalog.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
  }

  void _open(ServiceSummary service) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceFlowScreen(service: service)),
    );
  }

  /// Opens the full catalogue, landing on [group] rather than at the top.
  void _seeAll([String? group]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceSelectionScreen(initialGroup: group),
      ),
    );
  }

  /// Opens the full catalogue with the keyboard already up.
  ///
  /// Searching happens there rather than here: the catalogue already filters
  /// across name, subtitle and description, and duplicating that on the home
  /// screen would mean two implementations drifting apart.
  void _search() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ServiceSelectionScreen(autofocusSearch: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    if (catalog == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (catalog.services.isEmpty) return const SizedBox.shrink();

    final sections = catalog.byGroup.entries
        .where((e) => e.value.length >= _minForSection)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: _SearchBar(onTap: _search),
        ),
        for (final (index, section) in sections.indexed) ...[
          // Between sections only, never before the first or after the last —
          // a rule under the final row would read as the page ending.
          if (index > 0)
            Padding(
              // The rule's own breathing room lives here rather than on the
              // sections, so the space above and below it is symmetrical
              // instead of the section's top padding stacking underneath.
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade300.withValues(alpha: 0.5),
              ),
            ),
          _CategorySection(
            title: section.key,
            // Six or three — never four or five, which would leave a row
            // half-empty and looking broken rather than deliberate.
            services: section.value
                .take(section.value.length >= _fullRows ? _fullRows : _minForSection)
                .toList(),
            onTapService: _open,
            onSeeAll: () => _seeAll(section.key),
          ),
        ],
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.services,
    required this.onTapService,
    required this.onSeeAll,
  });

  final String title;
  final List<ServiceSummary> services;
  final void Function(ServiceSummary) onTapService;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _SeeAllButton(onTap: onSeeAll),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 3,
              // Inside the home screen's ListView: size to content and leave
              // scrolling to the parent, or two scrollables fight over one
              // vertical gesture.
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // Both of these are load-bearing. A vertical ScrollView with no
              // controller is `primary: true` by default, and a primary one
              // with no padding adopts the ambient MediaQuery inset — the
              // status bar's ~60pt — as its own top padding. That was the
              // gap between every heading and its tiles.
              primary: false,
              padding: EdgeInsets.zero,
              crossAxisSpacing: 10,
              // Small, because the cell already carries slack: it is sized for
              // a two-line name, and most names are one line, so every row
              // ends with dead space under its label. Adding 12 on top of that
              // put a visible trench between the two rows of a 3x2.
              mainAxisSpacing: 0,
              // Square artwork plus two lines of name. At three columns on a
              // 390pt screen a cell is ~113 wide, so the image takes 113 and
              // this leaves ~38 for the 6pt gap and two 14.4pt lines. 0.82
              // left 20 and clipped any name that wrapped.
              childAspectRatio: 0.72,
              children: [
                for (final service in services)
                  ServiceGridTile(
                    service: service,
                    onTap: () => onTapService(service),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('See all'),
    );
  }
}

/// The home screen's way in to search.
///
/// Deliberately not a real [TextField]: it looks like one and behaves like a
/// button, handing the actual typing to the catalogue screen. A live field
/// here would need somewhere to put its results, and the catalogue is that
/// somewhere.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search for a service',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
