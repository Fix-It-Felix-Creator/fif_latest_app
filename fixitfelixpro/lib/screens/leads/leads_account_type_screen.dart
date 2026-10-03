import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'leads_application.dart';
import 'leads_services_screen.dart';
import 'leads_ui.dart';

/// Solo or business.
///
/// Business is an Advance feature. It is shown to everybody rather than hidden
/// from the plans that cannot use it: someone on Standard deciding whether to
/// upgrade needs to see what the upgrade buys, and a choice that silently is
/// not there teaches them nothing.
class LeadsAccountTypeScreen extends StatefulWidget {
  const LeadsAccountTypeScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsAccountTypeScreen> createState() => _LeadsAccountTypeScreenState();
}

class _LeadsAccountTypeScreenState extends State<LeadsAccountTypeScreen> {
  LeadsApplicationDraft get draft => widget.draft;

  void _pick(LeadsApplicantType type) {
    setState(() => draft.setApplicantType(type));
  }

  @override
  Widget build(BuildContext context) {
    // Registering as a business is open on every plan. What needs Advance is
    // the business FEATURES — being matched under several trades at once and
    // passing leads to staff. Same split as applying vs receiving: nobody is
    // stopped from setting themselves up correctly on the plan they are on.
    final featuresLocked = !draft.plan.allowsBusiness;
    final chosen = draft.applicantType;

    return LeadsStepScaffold(
      step: draft.stepAccountType,
      totalSteps: draft.totalSteps,
      title: 'How do you work?',
      subtitle: 'This decides how many trades you can be listed under, and how '
          'jobs are shared out.',
      actionLabel: 'Continue',
      footnote: chosen == null ? 'Choose one to continue.' : null,
      onAction: chosen == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsServicesScreen(draft: draft),
                ),
              ),
      child: Column(
        children: [
          _TypeCard(
            icon: LucideIcons.userRound,
            title: 'Solo tradesperson',
            body: 'You do the work yourself. You will be listed under one '
                'trade, and jobs come to you.',
            points: const [
              (true, 'One trade'),
              (true, 'Leads on Pro and Advance'),
              (true, 'Available on every plan'),
            ],
            selected: chosen == LeadsApplicantType.solo,
            locked: false,
            onTap: () => _pick(LeadsApplicantType.solo),
          ),
          _TypeCard(
            icon: LucideIcons.building2,
            title: 'Business',
            body: 'You have a team. You can be listed under several trades, '
                'and pass jobs to your staff.',
            points: [
              (draft.plan.allowsBusiness, 'Matched under every trade you cover'),
              (draft.plan.allowsBusiness, 'Assign leads to staff'),
              (true, 'Register on any plan'),
            ],
            selected: chosen == LeadsApplicantType.business,
            locked: featuresLocked,
            onTap: () => _pick(LeadsApplicantType.business),
          ),
          if (featuresLocked && chosen == LeadsApplicantType.business)
            const LeadsNotice(
              icon: LucideIcons.info,
              tone: LeadsNoticeTone.warning,
              text: 'Register as a business now and list every trade you '
                  'cover. Being matched under more than one of them, and '
                  'passing leads to your staff, switch on with Advance — you '
                  'will not have to apply again.',
            )
          else if (featuresLocked)
            const LeadsNotice(
              icon: LucideIcons.info,
              tone: LeadsNoticeTone.locked,
              text: 'You can register either way on any plan. Advance is what '
                  'turns on the multi-trade matching and staff assignment a '
                  'business uses.',
            ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<(bool, String)> points;
  final bool selected;

  /// Still tappable when locked. Tapping is how the explanation appears — a
  /// card that does nothing teaches nothing.
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? leadsBrand : Colors.grey.shade200,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (selected ? leadsBrand : Colors.grey.shade500)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 19,
                        color: selected ? leadsBrand : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADVANCE FEATURES',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(LucideIcons.circleCheck,
                          size: 19, color: leadsBrand),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final (ok, text) in points)
                  LeadsCheckLine(text: text, included: ok),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
