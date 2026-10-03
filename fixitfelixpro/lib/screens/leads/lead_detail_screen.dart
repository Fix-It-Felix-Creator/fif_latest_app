import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/maps/static_jobs_map.dart';
import '../../models/nearby_job.dart';
import 'leads_ui.dart';

/// One job on the board, in full — as far as it goes before it is theirs.
///
/// The address is deliberately absent. A tradesperson deciding whether to
/// quote needs the trade, the description, the urgency and how far it is; the
/// door is what accepting buys, and showing it before then would make the
/// board a directory of everybody's home address.
class LeadDetailScreen extends StatelessWidget {
  const LeadDetailScreen({super.key, required this.job});

  final NearbyJob job;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Color get _urgencyTint => switch (job.urgency) {
        'urgent' => const Color(0xFFDC2626),
        'flexible' => const Color(0xFF64748B),
        _ => const Color(0xFF3B82F6),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: leadsPageBg,
      appBar: AppBar(
        backgroundColor: leadsPageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(job.summary),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        children: [
          if (job.hasPin)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: StaticJobsMap(
                points: [(lat: job.latitude!, lng: job.longitude!)],
                height: 170,
              ),
            ),

          const LeadsCaption('The job'),
          LeadsCard(
            children: [
              _Row(label: 'Trade', value: job.serviceName),
              const LeadsDivider(),
              _Row(label: 'What they need', value: job.summary),
              const LeadsDivider(),
              _Row(
                label: 'How soon',
                value: job.urgencyLabel,
                valueColor: _urgencyTint,
              ),
              const LeadsDivider(),
              _Row(
                label: 'Posted',
                value: job.postedAt == null
                    ? '—'
                    : _fmtDate(job.postedAt!.toLocal()),
              ),
            ],
          ),

          if (job.description.trim().isNotEmpty) ...[
            const LeadsCaption('In their words'),
            LeadsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Text(
                    job.description.trim(),
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ],

          const LeadsCaption('Where'),
          LeadsCard(
            children: [
              _Row(
                label: 'Area',
                value: job.postcodeDistrict?.isNotEmpty == true
                    ? job.postcodeDistrict!
                    : 'Not given',
              ),
              const LeadsDivider(),
              _Row(label: 'Distance', value: job.distanceLabel),
            ],
          ),

          // Said out loud rather than left to be noticed. Somebody looking at
          // a map pin and no street name should be told why, not left to
          // wonder whether the data is missing.
          const LeadsNotice(
            icon: LucideIcons.lock,
            text: 'You see the area while the job is open. The full address '
                'arrives when it is yours.',
          ),

          if (job.offersSent > 1)
            LeadsNotice(
              icon: LucideIcons.users,
              tone: LeadsNoticeTone.locked,
              text: 'This job has been sent to ${job.offersSent} '
                  'tradespeople. First to be accepted by the customer gets it.',
            ),
        ],
      ),
      // No accept button yet: accepting is accept_job_offer(), which needs the
      // offer row the fan-out function writes, and that function is not built.
      // A button that cannot do anything is worse than no button.
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
