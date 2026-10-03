import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/data/tradesman_services.dart';
import '../../repositories/leads/lead_applications_repository.dart';
import 'leads_application.dart';
import 'leads_status_screen.dart';
import 'leads_ui.dart';

/// The last look before it goes to the review team.
///
/// Every row jumps back to the screen that set it. An application someone
/// cannot correct without starting again is an application they abandon.
class LeadsReviewScreen extends StatefulWidget {
  const LeadsReviewScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsReviewScreen> createState() => _LeadsReviewScreenState();
}

class _LeadsReviewScreenState extends State<LeadsReviewScreen> {
  final _repository = LeadApplicationsRepository();
  bool _sending = false;
  String? _error;

  LeadsApplicationDraft get draft => widget.draft;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final app = await _repository.submit(draft);

    if (!mounted) return;
    if (app == null) {
      setState(() {
        _sending = false;
        _error = 'That could not be sent. Check your connection and try again.';
      });
      return;
    }
    // The whole flow goes, not just this screen. pushReplacement only
    // swapped the review page, leaving intro, account type, trades,
    // registrations, coverage, insurance and about still stacked underneath —
    // so Back walked an applicant through a form they had already sent, one
    // screen at a time, and let them send it again at the end.
    //
    // removeUntil isFirst puts them back on the home tab behind the status
    // screen, which is the only thing behind it that still makes sense.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LeadsStatusScreen()),
      (route) => route.isFirst,
    );
  }

  String _serviceName(String key) {
    for (final s in tradesmanServices) {
      if (s.key == key) return s.name;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final services = draft.services.map(_serviceName).toList()..sort();

    return Scaffold(
      backgroundColor: leadsPageBg,
      appBar: AppBar(
        backgroundColor: leadsPageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Check and send'),
        // No per-row edit buttons: every step writes to the same draft and the
        // stack is linear, so Back walks straight to any of them with
        // everything still filled in. A row-level "edit" would be a second way
        // to do what the back arrow already does, and a worse one.
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        children: [
          const LeadsCaption('You'),
          LeadsCard(
            children: [
              _Row(
                label: 'Applying as',
                value: draft.isSolo ? 'Solo tradesperson' : 'Business',
              ),
              const LeadsDivider(),
              _Row(
                label: draft.isSolo ? 'Trade' : 'Trades',
                value: services.join(', '),
              ),
              if (draft.registrations.isNotEmpty) ...[
                const LeadsDivider(),
                for (final e in draft.registrations.entries)
                  _Row(
                    label: '${_serviceName(e.key)} reg.',
                    value: e.value,
                  ),
              ],
            ],
          ),

          const LeadsCaption('Coverage'),
          LeadsCard(
            children: [
              _Row(label: 'Works from', value: draft.baseAddress ?? '—'),
              const LeadsDivider(),
              _Row(label: 'Seen within', value: draft.plan.radiusLabel),
              const LeadsDivider(),
              _Row(
                label: 'Working days',
                value: '${draft.workingDays.length} days a week',
              ),
              const LeadsDivider(),
              _Row(
                label: 'Emergencies',
                value: draft.takesEmergencies ? 'Yes' : 'No',
              ),
            ],
          ),

          const LeadsCaption('Insurance'),
          LeadsCard(
            children: [
              if (draft.hasNoInsurance)
                const _Row(
                  label: 'Cover',
                  value: 'Works under someone else’s policy',
                )
              else ...[
                _Row(label: 'Insurer', value: draft.insurer),
                const LeadsDivider(),
                _Row(label: 'Policy', value: draft.policyNumber),
                if (draft.coverAmount.trim().isNotEmpty) ...[
                  const LeadsDivider(),
                  _Row(label: 'Cover', value: '£${draft.coverAmount}'),
                ],
              ],
            ],
          ),

          const LeadsCaption('Public profile'),
          LeadsCard(
            children: [
              _Row(label: 'Headline', value: draft.headline),
              const LeadsDivider(),
              _Row(label: 'About', value: draft.about, multiline: true),
            ],
          ),

          // Said once more at the point of no return, because this is the
          // sentence people will quote back at support.
          if (!draft.plan.receivesLeads)
            const LeadsNotice(
              icon: LucideIcons.info,
              text: 'You are on Standard, so no leads will arrive yet. Your '
                  'application is still reviewed, and the moment you upgrade '
                  'you are live — no second application.',
            ),

          if (draft.missingAdvisoryRegistrations.isNotEmpty)
            LeadsNotice(
              icon: LucideIcons.info,
              tone: LeadsNoticeTone.locked,
              text: 'You have left '
                  '${draft.missingAdvisoryRegistrations.map(_serviceName).join(', ')} '
                  'without a scheme number. That will not stop your '
                  'application — it just gives the reviewer less to go on.',
            ),

          const LeadsNotice(
            icon: LucideIcons.fileCheck,
            tone: LeadsNoticeTone.locked,
            text: 'We will review this alongside the ID and qualifications '
                'already on your account. Nothing here is shown to customers '
                'except your headline and description.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: leadsBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send my application'),
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.trim().isEmpty ? '—' : value.trim(),
            maxLines: multiline ? 4 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
