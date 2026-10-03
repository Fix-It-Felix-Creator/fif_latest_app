import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'leads_identity_screen.dart';
import 'leads_application.dart';
import 'leads_ui.dart';

/// Public liability insurance.
///
/// The one thing a leads marketplace genuinely needs that this app has never
/// collected. Signup already takes ID, a selfie, National Insurance and trade
/// qualifications — none of which say who pays if a pipe bursts through
/// somebody's ceiling. Every established UK trades marketplace asks for this
/// before it will put a stranger in someone's home.
///
/// "I do not have cover" is an answer, not a dead end. Some trades genuinely
/// work under a main contractor's policy, and forcing a made-up policy number
/// out of them would be worse than knowing.
class LeadsInsuranceScreen extends StatefulWidget {
  const LeadsInsuranceScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsInsuranceScreen> createState() => _LeadsInsuranceScreenState();
}

class _LeadsInsuranceScreenState extends State<LeadsInsuranceScreen> {
  late final _insurer = TextEditingController(text: widget.draft.insurer);
  late final _policy = TextEditingController(text: widget.draft.policyNumber);
  late final _cover = TextEditingController(text: widget.draft.coverAmount);

  LeadsApplicationDraft get draft => widget.draft;

  @override
  void dispose() {
    _insurer.dispose();
    _policy.dispose();
    _cover.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.policyExpiry ?? now.add(const Duration(days: 180)),
      // A policy that expired last year is not cover. The picker will not
      // offer a date in the past, so it cannot be entered by accident.
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      draft.policyExpiry = picked;
      draft.touch();
    });
  }

  String _formatted(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final none = draft.hasNoInsurance;

    return LeadsStepScaffold(
      step: draft.stepInsurance,
      totalSteps: draft.totalSteps,
      title: 'Who insures you?',
      subtitle: 'Customers are letting a stranger into their home. Public '
          'liability cover is what makes that reasonable.',
      actionLabel: 'Continue',
      footnote: draft.insuranceComplete
          ? null
          : 'Add your insurer, policy number and expiry date.',
      onAction: draft.insuranceComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsIdentityScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          LeadsCard(
            children: [
              _Toggle(
                title: 'I have public liability insurance',
                selected: !none,
                onTap: () => setState(() {
                  draft.hasNoInsurance = false;
                  draft.touch();
                }),
              ),
              const LeadsDivider(),
              _Toggle(
                title: 'I work under someone else’s cover',
                subtitle: 'A main contractor or agency insures the work',
                selected: none,
                onTap: () => setState(() {
                  draft.hasNoInsurance = true;
                  draft.touch();
                }),
              ),
            ],
          ),

          if (none)
            const LeadsNotice(
              icon: LucideIcons.triangleAlert,
              tone: LeadsNoticeTone.warning,
              text: 'We will still review your application, but jobs from '
                  'homeowners usually need your own cover. Our team may come '
                  'back to you about this.',
            )
          else ...[
            const LeadsCaption('Policy'),
            LeadsCard(
              children: [
                LeadsField(
                  label: 'Insurer',
                  hint: 'e.g. Simply Business, Hiscox',
                  controller: _insurer,
                  onChanged: (v) => setState(() {
                    draft.insurer = v;
                    draft.touch();
                  }),
                ),
                const LeadsDivider(),
                LeadsField(
                  label: 'Policy number',
                  hint: 'As printed on your certificate',
                  controller: _policy,
                  onChanged: (v) => setState(() {
                    draft.policyNumber = v;
                    draft.touch();
                  }),
                ),
                const LeadsDivider(),
                LeadsField(
                  label: 'Cover amount',
                  hint: 'e.g. 2,000,000',
                  suffix: 'Optional',
                  controller: _cover,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {
                    draft.coverAmount = v;
                    draft.touch();
                  }),
                ),
                const LeadsDivider(),
                InkWell(
                  onTap: _pickExpiry,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 17, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        const Text(
                          'Expires',
                          style: TextStyle(fontSize: 14.5),
                        ),
                        const Spacer(),
                        Text(
                          draft.policyExpiry == null
                              ? 'Choose a date'
                              : _formatted(draft.policyExpiry!),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: draft.policyExpiry == null
                                ? Colors.grey.shade500
                                : leadsBrand,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(LucideIcons.chevronRight,
                            size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const LeadsNotice(
              icon: LucideIcons.shieldCheck,
              text: 'We check the policy is live when we review you, and again '
                  'when it is due to expire. We will remind you before it '
                  'lapses rather than quietly stopping your leads.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleDot : LucideIcons.circle,
              size: 19,
              color: selected ? leadsBrand : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
