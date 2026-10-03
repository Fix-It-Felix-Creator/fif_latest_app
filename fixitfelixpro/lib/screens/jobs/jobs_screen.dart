import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/invoices/invoices_event.dart';
import '../../blocs/invoices/invoices_state.dart';
import '../../blocs/jobs/jobs_bloc.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/invoice_model.dart';
import '../../models/job_model.dart';
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
      // Cards on this list show an invoice-total chip computed off the
      // job's linkedInvoiceIds, so make sure the bloc is streaming.
      context.read<InvoicesBloc>().add(const InvoicesStartWatching());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Largest trailing digit-run across saved references, plus one.
  int _nextSequence(List<Job> jobs) {
    int max = 0;
    final tail = RegExp(r'(\d+)$');
    for (final j in jobs) {
      final m = tail.firstMatch(j.reference);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  Future<void> _addJob() async {
    final jobs = context.read<JobsBloc>().state.items;
    await Navigator.of(context).pushNamed(
      '/jobs/new',
      arguments: NewJobArgs(nextSequence: _nextSequence(jobs)),
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
            tooltip: 'Add job',
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
                      _InvoiceTotalChip(ids: job.linkedInvoiceIds),
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

/// Resolves the job's linked invoice ids against [InvoicesBloc] and
/// renders a receipt-icon + total chip. Hides itself if none of the
/// ids resolve (e.g. source invoices were deleted).
class _InvoiceTotalChip extends StatelessWidget {
  const _InvoiceTotalChip({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      builder: (context, state) {
        final byId = {for (final inv in state.items) inv.id: inv};
        final invoices = <Invoice>[
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        if (invoices.isEmpty) return const SizedBox.shrink();
        final total = invoices.fold<double>(0, (acc, inv) => acc + inv.total);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt,
                size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '£${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _brand,
              ),
            ),
          ],
        );
      },
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
