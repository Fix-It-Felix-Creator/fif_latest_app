import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/jobs/jobs_bloc.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/job_model.dart';
import '../services/service_selection_screen.dart';
import 'new_job_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final next = _searchCtrl.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobsBloc>().add(const JobsStartWatching());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// New job starts at "which service?", not at a blank job form.
  ///
  /// The form behind `/jobs/new` is the tradesperson's — reference numbers,
  /// status, line items. A homeowner describes what they need and lets the
  /// flow build the job, so the + opens the catalogue.
  Future<void> _addJob() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
    );
  }

  Future<void> _editJob(Job j) async {
    await Navigator.of(context).pushNamed(
      '/jobs/new',
      arguments: NewJobArgs(existing: j),
    );
  }

  List<Job> _filter(List<Job> all) {
    if (_query.isEmpty) return all;
    return all
        .where((j) => j.title.toLowerCase().contains(_query))
        .toList(growable: false);
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
        title: const Text('Jobs'),
        actions: [
          IconButton(
            tooltip: 'New job',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _addJob,
          ),
          const SizedBox(width: 4),
        ],
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
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search by job name',
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
                      onPressed: () => _searchCtrl.clear(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<JobsBloc, JobsState>(
        builder: (context, state) {
          if (state.status == JobsStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (state.items.isEmpty) {
            return const _EmptyState();
          }
          final filtered = _filter(state.items);
          if (filtered.isEmpty) {
            return _NoMatchState(query: _query);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _JobCard(
              job: filtered[i],
              onTap: () => _editJob(filtered[i]),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.briefcase, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No jobs yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to create your first',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.searchX, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No jobs match "$query"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onTap,
  });
  final Job job;
  final VoidCallback onTap;

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final customer = job.customer;
    final customerName = customer?.name ?? 'No customer';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColorFor(customerName),
                      child: Text(
                        initialsFromName(customerName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (job.reference.isNotEmpty)
                            Text(
                              job.reference,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: job.status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  job.title.isEmpty ? 'Untitled job' : job.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (job.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    job.description.trim(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(LucideIcons.calendar,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDate(job.startDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (job.linkedInvoiceIds.isNotEmpty)
                    if (job.linkedInvoiceIds.isNotEmpty &&
                        job.expensesTotal > 0)
                      const SizedBox(width: 12),
                    if (job.expensesTotal > 0) ...[
                      Icon(LucideIcons.wallet,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '£${job.expensesTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final JobStatus status;

  ({Color bg, Color fg}) get _palette {
    switch (status) {
      case JobStatus.draft:
        return (bg: const Color(0xFFE5E7EB), fg: const Color(0xFF374151));
      case JobStatus.active:
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case JobStatus.completed:
        return (bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46));
      case JobStatus.cancelled:
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: p.fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
