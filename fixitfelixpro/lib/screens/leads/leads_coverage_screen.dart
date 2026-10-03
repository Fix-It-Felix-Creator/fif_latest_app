import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../customers/address_search_screen.dart';
import 'leads_application.dart';
import 'leads_insurance_screen.dart';
import 'leads_ui.dart';

/// Where you work from, and when.
///
/// The radius is NOT asked for — it comes from the plan and is shown read-only,
/// because letting someone type a number their plan will then override is a
/// promise the product cannot keep. What is asked for is the centre of the
/// circle, which nothing else on the account reliably has.
class LeadsCoverageScreen extends StatefulWidget {
  const LeadsCoverageScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsCoverageScreen> createState() => _LeadsCoverageScreenState();
}

class _LeadsCoverageScreenState extends State<LeadsCoverageScreen> {
  LeadsApplicationDraft get draft => widget.draft;

  /// Picks the base location through the same search both apps use.
  ///
  /// A typed string was never enough. Distance matching runs on coordinates,
  /// and the only way a free-text box produces a pin is if something geocodes
  /// it afterwards — which is exactly what the search screen already does, and
  /// what its manual-entry form now does too.
  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(
          initialQuery: draft.postcodeGuess,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.formatted.trim().isEmpty) return;
    setState(() {
      draft.baseAddress = result.formatted.trim();
      draft.latitude = result.latitude;
      draft.longitude = result.longitude;
      draft.touch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LeadsStepScaffold(
      step: draft.stepCoverage,
      totalSteps: draft.totalSteps,
      title: 'Where do you work?',
      subtitle: 'Jobs are matched by how far they are from here, so put the '
          'place you actually set off from.',
      actionLabel: 'Continue',
      footnote: draft.coverageComplete
          ? null
          : (draft.baseAddress ?? '').trim().isEmpty
              ? 'Add the area you work from.'
              : 'Pick at least one working day.',
      onAction: draft.coverageComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsInsuranceScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          const LeadsCaption('Base location'),
          LeadsCard(
            children: [
              InkWell(
                onTap: _pickAddress,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 18,
                        color: draft.baseAddress == null
                            ? Colors.grey.shade600
                            : leadsBrand,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          draft.baseAddress ?? 'Search for your address',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.3,
                            fontWeight: draft.baseAddress == null
                                ? FontWeight.w500
                                : FontWeight.w600,
                            color: draft.baseAddress == null
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        draft.baseAddress == null ? 'Search' : 'Change',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: leadsBrand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // The one state that silently breaks everything downstream, so it is
          // said on the screen that causes it rather than discovered later by
          // a reviewer.
          if (draft.baseAddress != null && draft.latitude == null)
            const LeadsNotice(
              icon: LucideIcons.triangleAlert,
              tone: LeadsNoticeTone.warning,
              text: 'We could not place that address on the map. Your '
                  'application still goes through, but jobs are matched by '
                  'distance — without a pin, nothing can reach you. Searching '
                  'again usually fixes it.',
            )
          else
            const LeadsNotice(
              icon: LucideIcons.mapPin,
              text: 'Jobs are matched by how far they are from here. Customers '
                  'are never shown your exact address — only the rough area '
                  'you cover.',
            ),

          const LeadsCaption('How far you will be seen'),
          LeadsCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.radius, size: 18, color: leadsBrand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.plan.radiusLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set by your ${draft.plan.label} plan',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Driven by the plan the server handed back, not by a ladder
              // written here. A hardcoded "Pro — 100 miles" is a second
              // opinion about `subscription_plans`, and the day the table
              // changes it becomes a lie the app tells confidently.
              LeadsCheckLine(
                text: draft.plan.receivesLeads
                    ? 'Jobs from homeowners in range reach you'
                    : 'Not listed for live leads on this plan',
                included: draft.plan.receivesLeads,
              ),
              LeadsCheckLine(
                text: 'Jobs anywhere in the UK',
                included: draft.plan.isUnlimited,
              ),
              LeadsCheckLine(
                text: 'Apply as a business with multiple trades',
                included: draft.plan.allowsBusiness,
              ),
            ],
          ),

          const LeadsCaption('When you take work'),
          LeadsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seven equal columns filling the width, like the header
                    // of a calendar. The previous version wrapped a row of
                    // bordered pills onto a second line with two orphans,
                    // which is what made it look like controls dropped on a
                    // page rather than a week.
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _DayDot(
                              letter: _dayLetters[i],
                              weekend: i >= 5,
                              selected: draft.workingDays.contains(i + 1),
                              onTap: () => setState(() {
                                final d = i + 1;
                                if (!draft.workingDays.remove(d)) {
                                  draft.workingDays.add(d);
                                }
                                draft.touch();
                              }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _describe(draft.workingDays),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: draft.workingDays.isEmpty
                                  ? const Color(0xFFB91C1C)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        // Presets, because almost everybody wants one of two
                        // answers and tapping five circles to say "weekdays"
                        // is work the app can do for them.
                        _Preset(
                          label: 'Weekdays',
                          onTap: () => setState(() {
                            draft.workingDays
                              ..clear()
                              ..addAll([1, 2, 3, 4, 5]);
                            draft.touch();
                          }),
                        ),
                        const SizedBox(width: 12),
                        _Preset(
                          label: 'Every day',
                          onTap: () => setState(() {
                            draft.workingDays
                              ..clear()
                              ..addAll([1, 2, 3, 4, 5, 6, 7]);
                            draft.touch();
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const LeadsDivider(),
              // In the same card as the days, because it is the same question
              // — when will you go out — and two cards made it look like two.
              _EmergencyRow(
                value: draft.takesEmergencies,
                onChanged: (v) => setState(() {
                  draft.takesEmergencies = v;
                  draft.touch();
                }),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Plain English for a set of weekdays.
///
/// "Mon to Fri" rather than "5 days": the point of the summary is to let
/// somebody check what they tapped without counting circles.
String _describe(Set<int> days) {
  if (days.isEmpty) return 'No working days chosen';
  if (days.length == 7) return 'Every day';

  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final sorted = days.toList()..sort();

  // A single unbroken run reads as a range; anything else is listed.
  final contiguous = sorted.last - sorted.first == sorted.length - 1;
  if (contiguous && sorted.length > 2) {
    return '${names[sorted.first - 1]} to ${names[sorted.last - 1]}';
  }
  return sorted.map((d) => names[d - 1]).join(', ');
}

/// One day of the week.
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.weekend,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool weekend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Opaque so the whole column is the target, not just the circle. At
      // 38pt a circle is under the 44pt minimum on its own.
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: selected ? leadsBrand : Colors.transparent,
            shape: BoxShape.circle,
            border: selected
                ? null
                : Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  // Unselected weekends sit back a shade, so the common
                  // Mon-Fri shape is readable at a glance.
                  : weekend
                      ? Colors.grey.shade400
                      : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: leadsBrand,
        ),
      ),
    );
  }
}

/// Emergency call-outs, with the warning folded in rather than hung
/// underneath as a separate block.
class _EmergencyRow extends StatelessWidget {
  const _EmergencyRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (value ? const Color(0xFFDC2626) : Colors.grey.shade500)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  LucideIcons.siren,
                  size: 17,
                  color: value
                      ? const Color(0xFFDC2626)
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency call-outs',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Urgent jobs outside those days',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: leadsBrand,
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Urgent jobs can arrive at any hour, including overnight and '
                'at weekends.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
