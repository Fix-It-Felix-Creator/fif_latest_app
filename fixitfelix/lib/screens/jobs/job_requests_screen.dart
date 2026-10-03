import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/job_requests/job_requests_bloc.dart';
import '../../models/job_request.dart';
import '../../core/utils/avatar_helper.dart';
import '../services/service_selection_screen.dart';
import 'job_request_detail_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// The jobs a homeowner has posted.
///
/// Deliberately not the ported `JobsScreen`, which lists `public.jobs` — a
/// tradesperson's own work records, keyed to their account. A customer has
/// none of those. What they have is requests, and this is the list of them.
class JobRequestsScreen extends StatelessWidget {
  const JobRequestsScreen({super.key});

  static Color toneOf(JobRequestStatus s) => switch (s) {
        JobRequestStatus.posted => const Color(0xFF3B82F6),
        JobRequestStatus.assigned => const Color(0xFF8B5CF6),
        JobRequestStatus.inProgress => const Color(0xFF10B981),
        JobRequestStatus.completed => const Color(0xFF64748B),
        JobRequestStatus.cancelled => const Color(0xFF94A3B8),
        // An unmapped status renders neutral rather than wrong.
        JobRequestStatus.unknown => const Color(0xFF94A3B8),
      };

  void _post(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Jobs'),
        actions: [
          IconButton(
            tooltip: 'New job',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: () => _post(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<JobRequestsBloc, JobRequestsState>(
        builder: (context, state) {
          if (state.status == JobRequestsStatus.loading &&
              state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          // Error before empty. Both draw a mostly blank page, and "you have
          // no jobs" is a lie when the truth is that the list could not be
          // read — which is exactly how a posted job looks like it vanished.
          if (state.status == JobRequestsStatus.error && state.items.isEmpty) {
            return _Failed(
              message: state.errorMessage,
              onRetry: () => context
                  .read<JobRequestsBloc>()
                  .add(const JobRequestsStartWatching()),
            );
          }
          if (state.items.isEmpty) {
            return _Empty(onPost: () => _post(context));
          }

          // Open first, each group under its own heading. Somebody opening
          // this tab is almost always checking on something live, not
          // reading history.
          final open = state.items.where((j) => j.status.isOpen).toList();
          final done = state.items.where((j) => !j.status.isOpen).toList();

          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            children: [
              if (open.isNotEmpty) ...[
                _Heading(
                  open.length == 1 ? 'Active' : '${open.length} active',
                ),
                for (final job in open) _JobCard(job: job),
              ],
              if (done.isNotEmpty) ...[
                const _Heading('Finished'),
                for (final job in done) _JobCard(job: job),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// One posted job, shaped like the pro app's job card.
///
/// Same anatomy deliberately: avatar, counterparty, reference, status badge,
/// title, description, date. The only thing that differs is WHO the
/// counterparty is — a tradesperson has a customer, a homeowner has a
/// tradesperson — and everything else about looking at a job is the same job
/// on both sides of it.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobRequest job;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// Who this job is with. Unassigned reads as the search itself rather than
  /// as a blank, because "Finding someone" is the true state and "No
  /// tradesperson" sounds like a failure.
  String get _counterparty =>
      job.acceptedBy == null ? 'Finding someone' : 'Your tradesperson';

  @override
  Widget build(BuildContext context) {
    final tone = JobRequestsScreen.toneOf(job.status);
    final assigned = job.acceptedBy != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => JobRequestDetailScreen(id: job.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: assigned
                          ? avatarColorFor(_counterparty)
                          : Colors.grey.shade300,
                      child: assigned
                          ? Text(
                              initialsFromName(_counterparty),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(LucideIcons.search,
                              size: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _counterparty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            // The pro app shows its own reference here. A
                            // homeowner has never seen one, so the service is
                            // the more useful second line.
                            job.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        job.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  job.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (job.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    job.description.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(LucideIcons.calendar,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      job.createdAt == null
                          ? '—'
                          : _fmtDate(job.createdAt!.toLocal()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(LucideIcons.mapPin,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        job.formattedAddress.isEmpty
                            ? 'No address'
                            : job.formattedAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                // The one state worth flagging on the card: posted, but with
                // no pin, so no distance search can ever return it.
                if (job.status.isOpen && !job.hasCoordinates) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert,
                          size: 13, color: Color(0xFFB45309)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'No map pin — nearby tradespeople are not being '
                          'alerted.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cloudOff, size: 30, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            const Text(
              'Your jobs could not be loaded',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Any job you posted is still there — this is the list failing to '
              'load, not the job failing to send.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.briefcase, size: 30, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No jobs yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Post a job and we will look for tradespeople near you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onPost,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Post a job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
