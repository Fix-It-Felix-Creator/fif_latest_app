import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/services/service_catalog.dart';
import '../../widgets/inset_group.dart';
import 'service_flow_screen.dart';
import 'service_tile.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Every service, grouped and searchable.
///
/// Reached from "See all" on the home carousels, and the place someone lands
/// when the four trending tiles are not what they came for.
class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({
    super.key,
    this.initialGroup,
    this.autofocusSearch = false,
  });

  /// Category heading to land on, rather than the top of the list.
  ///
  /// Set when arriving from a category's own "See all" — someone who tapped
  /// it beside "Heating & Gas" wants that section, not the first one.
  final String? initialGroup;

  /// Opens with the keyboard already up.
  ///
  /// Set when arriving from the home screen's search bar: tapping a search
  /// box and then having to tap the next one is a wasted step.
  final bool autofocusSearch;

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  final _searchCtrl = TextEditingController();

  /// One key per category heading, so the right one can be scrolled to.
  final _sectionKeys = <String, GlobalKey>{};

  ServiceCatalog? _catalog;
  String _query = '';

  @override
  void initState() {
    super.initState();
    ServiceCatalog.load().then((c) {
      if (!mounted) return;
      setState(() => _catalog = c);
      _scrollToInitialGroup();
    });
  }

  /// Jumps to the requested category once it has been laid out.
  ///
  /// After a frame, not immediately: the sections do not exist until the
  /// catalogue has been set and built, and ensureVisible needs a laid-out box
  /// to measure. Without a target this does nothing and the list opens at the
  /// top, which is what "See all" from the page heading should do.
  void _scrollToInitialGroup([int attempt = 0]) {
    final group = widget.initialGroup;
    if (group == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _sectionKeys[group]?.currentContext;
      if (target == null) {
        // The heading has not been laid out yet. One more frame usually does
        // it — the list grows its cache extent on the first build — but give
        // up rather than spin, because a group that genuinely is not in the
        // catalogue would retry forever.
        if (attempt < 4) _scrollToInitialGroup(attempt + 1);
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        // Pin the heading near the top rather than merely bringing it on
        // screen — landing with it at the bottom edge would look like nothing
        // happened.
        alignment: 0,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final q = _query.trim().toLowerCase();

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('All services'),
        // Search lives in the app bar, as it does on the pro app's Jobs
        // screen: white field, hairline border, no filled box on a filled
        // page.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(LucideIcons.search,
                      size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: widget.autofocusSearch,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search services',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Icon(LucideIcons.x,
                          size: 16, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : _list(catalog, q),
    );
  }

  Widget _list(ServiceCatalog catalog, String q) {
    // Searching flattens the groups: when someone types "boiler" the heading
    // it sits under is noise, and three one-item sections read worse than one
    // list of three.
    if (q.isNotEmpty) {
      final hits = catalog.services.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.subtitle ?? '').toLowerCase().contains(q) ||
            (s.description ?? '').toLowerCase().contains(q);
      }).toList();

      if (hits.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.searchX, size: 28, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  'Nothing matches "${_searchCtrl.text.trim()}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader('${hits.length} ${hits.length == 1 ? 'match' : 'matches'}'),
          InsetGroup(children: _rows(hits)),
        ],
      );
    }

    final groups = catalog.byGroup;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      // Load-bearing when arriving from a category's "See all". A ListView
      // only lays out what is near the viewport, so the GlobalKey on a
      // heading further down has no context and ensureVisible has nothing to
      // scroll to — which is why it silently did nothing. A cache extent
      // past the end of the list forces every heading to exist. Only paid
      // when there is somewhere to scroll to; the plain list stays lazy.
      scrollCacheExtent: widget.initialGroup == null
          ? null
          : const ScrollCacheExtent.pixels(10000),
      children: [
        for (final entry in groups.entries) ...[
          SectionHeader(
            entry.key,
            key: _sectionKeys.putIfAbsent(entry.key, GlobalKey.new),
          ),
          InsetGroup(children: _rows(entry.value)),
        ],
      ],
    );
  }

  /// Rows for one group, hairline-separated — never a trailing line under the
  /// last row, which would read as a row that failed to render.
  List<Widget> _rows(List<ServiceSummary> services) {
    final out = <Widget>[];
    for (var i = 0; i < services.length; i++) {
      if (i > 0) out.add(const HairlineDivider(indent: 76));
      out.add(_row(services[i]));
    }
    return out;
  }

  Widget _row(ServiceSummary service) {
    return ServiceRow(
      service: service,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ServiceFlowScreen(service: service)),
      ),
    );
  }
}
