import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/job_requests/job_requests_bloc.dart';
import '../../core/utils/avatar_helper.dart';
import '../../models/job_request.dart';
import '../../models/services/service_catalog.dart';
import '../services/service_tile.dart';
import 'job_requests_screen.dart';

const _pageBg = Color(0xFFF5F5F7);
const _brand = Color(0xFFF64C13);

/// One posted job, shaped like the pro app's job screen.
///
/// Same anatomy on purpose — a tabbed header over white cards, the
/// counterparty at the top, then the detail. A job is the same object from
/// both sides; the only thing that changes is who is across the table. A
/// tradesperson sees their customer, a homeowner sees their tradesperson.
///
/// Reads the job from the bloc by id rather than taking a snapshot: the row
/// that opened this may be seconds old, and a tradesperson accepting while
/// somebody is reading should change what they are reading.
class JobRequestDetailScreen extends StatefulWidget {
  const JobRequestDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<JobRequestDetailScreen> createState() =>
      _JobRequestDetailScreenState();
}

class _JobRequestDetailScreenState extends State<JobRequestDetailScreen> {
  late final ShadTabsController<String> _tabs =
      ShadTabsController<String>(value: 'details');

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel(JobRequest job) async {
    final bloc = context.read<JobRequestsBloc>();
    final navigator = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this job?'),
        content: Text(
          'Tradespeople will stop being offered your '
          '${job.serviceName.toLowerCase()} job. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    bloc.add(JobRequestCancelRequested(job.id));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JobRequestsBloc, JobRequestsState>(
      builder: (context, state) {
        JobRequest? job;
        for (final j in state.items) {
          if (j.id == widget.id) {
            job = j;
            break;
          }
        }

        if (job == null) {
          return Scaffold(
            backgroundColor: _pageBg,
            appBar: _appBar(context, null),
            body: const _Gone(),
          );
        }

        return Scaffold(
          backgroundColor: _pageBg,
          appBar: _appBar(context, job),
          body: ListenableBuilder(
            listenable: _tabs,
            builder: (context, _) => switch (_tabs.selected) {
              'quotes' => const _ComingSoon(
                  icon: LucideIcons.fileText,
                  title: 'No quotes yet',
                  body: 'When a tradesperson sends you a quote for this job, '
                      'it will appear here.',
                ),
              'invoices' => const _ComingSoon(
                  icon: LucideIcons.receipt,
                  title: 'No invoices yet',
                  body: 'Invoices for this job will appear here once the work '
                      'is done.',
                ),
              'expenses' => const _ComingSoon(
                  icon: LucideIcons.wallet,
                  title: 'No expenses yet',
                  body: 'Materials and costs your tradesperson logs against '
                      'this job will appear here.',
                ),
              'attachment' => const _ComingSoon(
                  icon: LucideIcons.paperclip,
                  title: 'No attachments yet',
                  body: 'Photos, files and documents added to this job will '
                      'appear here.',
                ),
              'notes' => const _ComingSoon(
                  icon: LucideIcons.notebookPen,
                  title: 'No notes yet',
                  body: 'Notes about this job will appear here.',
                ),
              _ => _DetailsTab(job: job!, onCancel: () => _confirmCancel(job!)),
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, JobRequest? job) {
    return AppBar(
      backgroundColor: _pageBg,
      foregroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(job?.summary ?? 'Job'),
      bottom: job == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: ShadTabs<String>(
                  controller: _tabs,
                  scrollable: true,
                  // The pro app's six, in its order. A job is the same object
                  // from both sides and the tabs are the same tabs — only who
                  // is across the table changes.
                  tabs: const [
                    ShadTab(
                      value: 'details',
                      content: SizedBox.shrink(),
                      child: Text('Details'),
                    ),
                    ShadTab(
                      value: 'quotes',
                      content: SizedBox.shrink(),
                      child: Text('Quotes'),
                    ),
                    ShadTab(
                      value: 'invoices',
                      content: SizedBox.shrink(),
                      child: Text('Invoices'),
                    ),
                    ShadTab(
                      value: 'expenses',
                      content: SizedBox.shrink(),
                      child: Text('Expenses'),
                    ),
                    ShadTab(
                      value: 'attachment',
                      content: SizedBox.shrink(),
                      child: Text('Attachments'),
                    ),
                    ShadTab(
                      value: 'notes',
                      content: SizedBox.shrink(),
                      child: Text('Notes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.job, required this.onCancel});

  final JobRequest job;
  final VoidCallback onCancel;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final tone = JobRequestsScreen.toneOf(job.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        _TradespersonCard(job: job),
        const SizedBox(height: 8),

        _Card(
          child: Column(
            children: [
              _LabeledField(
                label: 'Status',
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: tone, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job.status.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _LabeledField(
                label: 'Posted',
                child: Text(
                  job.createdAt == null
                      ? '—'
                      : _fmtDate(job.createdAt!.toLocal()),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Divider(height: 1),
              _LabeledField(
                label: 'How soon',
                child: Text(
                  job.urgency.detail,
                  style: const TextStyle(fontSize: 13.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(LucideIcons.wrench, size: 16, color: _brand),
                    const SizedBox(width: 8),
                    const Text(
                      'What you asked for',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              _ServiceRow(job: job),
              if (job.selections.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < job.selections.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            left: i * 14.0,
                            bottom: i == job.selections.length - 1 ? 0 : 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                i == job.selections.length - 1
                                    ? LucideIcons.circleCheck
                                    : LucideIcons.cornerDownRight,
                                size: 14,
                                color: i == job.selections.length - 1
                                    ? _brand
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job.selections[i].name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight:
                                        i == job.selections.length - 1
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (job.description.trim().isNotEmpty) ...[
                const Divider(height: 1),
                _LabeledField(
                  label: 'Your notes',
                  child: Text(
                    job.description.trim(),
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 16, color: _brand),
                    const SizedBox(width: 8),
                    const Text(
                      'Where',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  job.formattedAddress.isEmpty
                      ? 'No address given'
                      : job.formattedAddress,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: job.formattedAddress.isEmpty
                        ? Colors.grey.shade500
                        : Colors.black87,
                  ),
                ),
              ),
              // The one state that silently breaks everything downstream.
              if (job.status.isOpen && !job.hasCoordinates)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(11)),
                  ),
                  child: Text(
                    'We could not place this address on the map, so nearby '
                    'tradespeople are not being alerted about it.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (job.status.isOpen) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(LucideIcons.x, size: 16),
              label: const Text('Cancel this job'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        Center(
          child: Text(
            'Reference ${job.id.split('-').first}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Who the job is with. The pro app's customer card, the other way round.
class _TradespersonCard extends StatelessWidget {
  const _TradespersonCard({required this.job});

  final JobRequest job;

  @override
  Widget build(BuildContext context) {
    final assigned = job.acceptedBy != null;
    final name = assigned ? 'Your tradesperson' : 'Finding someone';

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  assigned ? avatarColorFor(name) : Colors.grey.shade300,
              child: assigned
                  ? Text(
                      initialsFromName(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(LucideIcons.search,
                      size: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    assigned
                        ? 'They will be in touch about this job.'
                        : 'We are looking for tradespeople near you.',
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
      ),
    );
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({required this.job});

  final JobRequest job;

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  ServiceSummary? _service;

  @override
  void initState() {
    super.initState();
    final id = widget.job.serviceId;
    if (id == null) return;
    // Looked up by id rather than stored on the job: the row keeps the
    // service NAME so history reads correctly, but the picture is
    // presentation and should come from whatever the catalogue says today.
    ServiceCatalog.load().then((catalog) {
      if (!mounted) return;
      for (final s in catalog.services) {
        if (s.id == id) {
          setState(() => _service = s);
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: service == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.wrench,
                        size: 20, color: _brand),
                  )
                : ServiceArtwork(service: service, radius: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.job.serviceName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pro app's card shell, so both sides of a job look like one product.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A tab that has nothing in it yet, said plainly.
///
/// An empty list would read as "there are none", which is true now but will
/// stay on screen unchanged once quotes exist and simply are not wired — and
/// that is the version somebody believes.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileQuestion,
                size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'This job is no longer in your list',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'It may have been removed from another device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
