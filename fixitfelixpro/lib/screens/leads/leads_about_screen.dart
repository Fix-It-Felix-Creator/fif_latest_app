import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'leads_application.dart';
import 'leads_review_screen.dart';
import 'leads_ui.dart';

/// What the customer reads before choosing you.
///
/// The only part of the application that is public. Everything else — ID,
/// insurance, National Insurance — is for the review team; this is the bit
/// that competes against the other three tradespeople who got the same lead.
class LeadsAboutScreen extends StatefulWidget {
  const LeadsAboutScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsAboutScreen> createState() => _LeadsAboutScreenState();
}

class _LeadsAboutScreenState extends State<LeadsAboutScreen> {
  late final _headline = TextEditingController(text: widget.draft.headline);
  late final _about = TextEditingController(text: widget.draft.about);

  LeadsApplicationDraft get draft => widget.draft;

  static const _minAbout = 40;

  @override
  void dispose() {
    _headline.dispose();
    _about.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = draft.about.trim().length;

    return LeadsStepScaffold(
      step: draft.stepAbout,
      totalSteps: draft.totalSteps,
      title: 'How should we introduce you?',
      subtitle: 'This is what a homeowner sees next to your name when your '
          'quote lands.',
      actionLabel: 'Review application',
      footnote: draft.aboutComplete
          ? null
          : draft.headline.trim().isEmpty
              ? 'Add a one-line summary.'
              : 'A few more words — ${_minAbout - len} to go.',
      onAction: draft.aboutComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsReviewScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          const LeadsCaption('Headline'),
          LeadsCard(
            children: [
              LeadsField(
                label: 'One line about you',
                hint: 'e.g. Gas Safe engineer, 12 years on boilers',
                suffix: '${draft.headline.trim().length}/70',
                controller: _headline,
                onChanged: (v) => setState(() {
                  draft.headline = v;
                  draft.touch();
                }),
              ),
            ],
          ),

          const LeadsCaption('About your work'),
          LeadsCard(
            children: [
              LeadsField(
                label: 'What you do, and how you work',
                hint: 'What you specialise in, the kind of jobs you enjoy, and '
                    'what a customer can expect from you.',
                controller: _about,
                maxLines: 5,
                suffix: len < _minAbout ? '$len/$_minAbout' : '$len',
                onChanged: (v) => setState(() {
                  draft.about = v;
                  draft.touch();
                }),
              ),
            ],
          ),

          const LeadsCaption('Experience'),
          LeadsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The answer, stated back. A row of chips gives no
                    // feedback beyond one of them being darker; this says what
                    // was chosen and — more usefully — how it will read to the
                    // customer, which is the only reason the question is
                    // asked.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _bandFor(draft.yearsExperience)?.number ?? '—',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: draft.yearsExperience == null
                                ? Colors.grey.shade300
                                : leadsBrand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _bandFor(draft.yearsExperience)?.unit ??
                                'Years in the trade',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.yearsExperience == null
                          ? 'Optional, but it is the first thing customers '
                              'look at.'
                          : 'Shown on your profile as '
                              '“${_bandFor(draft.yearsExperience)!.badge}”.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // A segmented control, not chips: five ordered buckets
                    // filling one row is the same shape as the pro app's own
                    // toggles, and nothing wraps.
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFF3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          for (final band in _bands)
                            Expanded(
                              child: _BandSegment(
                                label: band.short,
                                selected: draft.yearsExperience == band.value,
                                onTap: () => setState(() {
                                  // Tapping the current one clears it — the
                                  // field is optional, and without this there
                                  // is no way back to "prefer not to say".
                                  draft.yearsExperience =
                                      draft.yearsExperience == band.value
                                          ? null
                                          : band.value;
                                  draft.touch();
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Shown rather than described. Copy meant for a customer reads
          // differently in a form field than it does on the card they will
          // actually see, and the difference is usually unflattering.
          if (draft.headline.trim().isNotEmpty) ...[
            const LeadsCaption('How it will look'),
            LeadsCard(
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: leadsBrand.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.userRound,
                          size: 20, color: leadsBrand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your name',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            draft.headline.trim(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (draft.yearsExperience != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _bandFor(draft.yearsExperience)!.badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                  ],
                ),
                if (draft.about.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    draft.about.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The five buckets, and how each one reads in three different places.
typedef _Band = ({String short, String number, String unit, String badge, int value});

const _bands = <_Band>[
  (short: '<2', number: '1', unit: 'year or so', badge: 'Getting started', value: 1),
  (short: '2–5', number: '2+', unit: 'years', badge: '2+ years', value: 2),
  (short: '5–10', number: '5+', unit: 'years', badge: '5+ years', value: 5),
  (short: '10–20', number: '10+', unit: 'years', badge: '10+ years', value: 10),
  (short: '20+', number: '20+', unit: 'years', badge: '20+ years', value: 20),
];

_Band? _bandFor(int? value) {
  if (value == null) return null;
  for (final b in _bands) {
    if (b.value == value) return b;
  }
  return null;
}

/// One bucket of the experience control.
class _BandSegment extends StatelessWidget {
  const _BandSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Opaque so the whole segment is the target, not just the glyphs in it.
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? leadsBrand : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
