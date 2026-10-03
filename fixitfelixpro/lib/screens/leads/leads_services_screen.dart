import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/data/tradesman_services.dart';
import 'leads_application.dart';
import 'leads_coverage_screen.dart';
import 'leads_registrations_screen.dart';
import 'leads_ui.dart';

/// Which trades to be listed under.
///
/// Solo keeps one, a business may hold many — the same rule the app's own
/// signup already uses, so this is not a new idea for anyone who has been
/// through onboarding.
///
/// The part that is new: picking a gated trade asks for the registration
/// number immediately, inline, rather than collecting it at the end. Sending a
/// customer someone who cannot lawfully do the work is a different kind of
/// mistake to sending them someone mediocre, and the moment to say so is the
/// moment they tick the box.
class LeadsServicesScreen extends StatefulWidget {
  const LeadsServicesScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsServicesScreen> createState() => _LeadsServicesScreenState();
}

class _LeadsServicesScreenState extends State<LeadsServicesScreen> {
  final _search = TextEditingController();
  String _query = '';

  LeadsApplicationDraft get draft => widget.draft;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final all = tradesmanServices
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

    return LeadsStepScaffold(
      step: draft.stepServices,
      totalSteps: draft.totalSteps,
      title: draft.isSolo ? 'What is your trade?' : 'What do you cover?',
      subtitle: draft.isSolo
          ? 'Pick the one trade you want jobs for. Customers looking for it '
              'will be matched to you.'
          : 'Pick every trade your team covers. You will be matched to jobs in '
              'all of them.',
      actionLabel: 'Continue',
      footnote: draft.services.isEmpty
          ? (draft.isSolo ? 'Choose your trade.' : 'Choose at least one trade.')
          : draft.needsRegistrations
              ? 'We will ask for your registration number next.'
              : null,
      onAction: draft.servicesComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => draft.needsRegistrations
                      ? LeadsRegistrationsScreen(draft: draft)
                      : LeadsCoverageScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          if (draft.isSolo)
            const LeadsNotice(
              icon: LucideIcons.userRound,
              tone: LeadsNoticeTone.locked,
              text: 'As a solo tradesperson you are listed under one trade. '
                  'Picking another replaces it.',
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search trades',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(LucideIcons.x,
                          size: 16, color: Colors.grey.shade500),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // The amber dot on a tile means nothing on its own. One line here
          // beats a badge on every gated tile, which at 82pt wide there is no
          // room for anyway.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Needs a registration number by law',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!draft.isSolo && draft.services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Text(
                    '${draft.services.length} selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      draft.services.clear();
                      draft.registrations.clear();
                      draft.touch();
                    }),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: leadsBrand,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'No trade matches "${_search.text.trim()}".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // The cell height is measured, not guessed. childAspectRatio is
              // a ratio of the cell WIDTH, so it cannot know how tall two
              // lines of a label are — and at 4 columns plenty of these names
              // wrap ("Central Heating", "HVAC Technician"). Getting it wrong
              // by a few pixels is an overflow stripe across the grid, which
              // is exactly what a fixed ratio produced.
              //
              // Measuring also survives the accessibility text sizes, where a
              // hardcoded ratio breaks again and worse.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 4;
                  const spacing = 8.0;
                  const gap = 5.0;
                  const labelSize = 10.5;
                  const labelHeight = 1.2;

                  final tile =
                      (constraints.maxWidth - spacing * (columns - 1)) / columns;
                  // Two lines at the size this device will actually render
                  // them, plus a pixel of slack for rounding.
                  final label = MediaQuery.textScalerOf(context)
                              .scale(labelSize) *
                          labelHeight *
                          2 +
                      1;

                  return GridView.builder(
                    shrinkWrap: true,
                    // Inside the step scaffold's own ListView: size to content
                    // and leave scrolling to the parent, or two scrollables
                    // fight over one vertical gesture.
                    physics: const NeverScrollableScrollPhysics(),
                    // Both load-bearing. A vertical ScrollView with no
                    // controller is primary: true, and a primary one with no
                    // padding adopts the ambient MediaQuery inset as its own
                    // top padding.
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: all.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      // Absolute height rather than a ratio: square tile, gap,
                      // and exactly enough room for the label.
                      mainAxisExtent: tile + gap + label,
                    ),
                    itemBuilder: (context, i) {
                      final service = all[i];
                      return _ServiceGridTile(
                        name: service.name,
                        icon: service.icon,
                        labelHeight: label,
                        selected: draft.services.contains(service.key),
                        solo: draft.isSolo,
                        gated: leadsGatedServices.containsKey(service.key),
                        onTap: () =>
                            setState(() => draft.toggleService(service.key)),
                      );
                    },
                  );
                },
              ),
            ),

        ],
      ),
    );
  }
}

class _ServiceGridTile extends StatelessWidget {
  const _ServiceGridTile({
    required this.name,
    required this.icon,
    required this.labelHeight,
    required this.selected,
    required this.solo,
    required this.gated,
    required this.onTap,
  });

  final String name;
  final IconData icon;

  /// Exactly the room the grid reserved for the label, measured by the caller
  /// so the two agree. A SizedBox rather than an Expanded: Expanded hands the
  /// text a tight box and a paragraph that needs one more pixel paints outside
  /// it anyway, which is the overflow this replaced.
  final double labelHeight;

  final bool selected;
  final bool solo;
  final bool gated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                color: selected
                    ? leadsBrand.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? leadsBrand : Colors.grey.shade200,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      icon,
                      // The tile is ~83pt square on a 390pt screen, so 22 left
                      // it floating in a lot of white. 30 fills it without
                      // crowding the corner tick or the gated dot.
                      size: 30,
                      color: selected ? leadsBrand : Colors.grey.shade600,
                    ),
                  ),
                  // The tick is the only thing that says how many you may
                  // pick: a circle for solo, a square for a business. In a
                  // grid there is no room for a radio beside every label, so
                  // it lives in the corner and only appears once chosen.
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        solo ? LucideIcons.circleCheck : LucideIcons.squareCheck,
                        size: 14,
                        color: leadsBrand,
                      ),
                    ),
                  if (gated)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: labelHeight,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? leadsBrand : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
