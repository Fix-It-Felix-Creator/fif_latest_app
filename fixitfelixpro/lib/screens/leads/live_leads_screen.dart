import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../core/maps/static_jobs_map.dart';
import '../../models/nearby_job.dart';
import '../../repositories/leads/nearby_jobs_repository.dart';
import 'lead_detail_screen.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/enum.dart';
import '../subscription/choose_plan_screen.dart';
import '../../core/data/tradesman_services.dart';
import '../../models/lead_application.dart';
import 'leads_application.dart';
import 'leads_ui.dart';

/// Live leads, for somebody who is already through verification.
///
/// Where the home card goes once approved. Deliberately says nothing about
/// verification or applications — that is finished business, and somebody
/// opening this is looking for work, not for a recap of how they got here.
class LiveLeadsScreen extends StatefulWidget {
  const LiveLeadsScreen({super.key});

  @override
  State<LiveLeadsScreen> createState() => _LiveLeadsScreenState();
}

class _LiveLeadsScreenState extends State<LiveLeadsScreen> {
  final _repository = NearbyJobsRepository();

  List<NearbyJob>? _jobs;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _repository.nearby();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Surfaced rather than swallowed: an empty board and a board that
        // could not be read look identical, and only one of them means
        // there is no work.
        _error = 'Jobs near you could not be loaded.';
      });
    }
  }

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
        title: const Text('Live Leads'),
      ),
      body: BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
        builder: (context, state) {
          final app = state.application;
          final plan = state.plan;
          if (app == null) {
            return const Center(
              child: CircularProgressIndicator(color: leadsBrand),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (plan.receivesLeads
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706))
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.radioTower,
                        size: 30,
                        color: plan.receivesLeads
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      plan.receivesLeads
                          ? 'You are live'
                          : 'Ready when you upgrade',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.receivesLeads
                          ? 'Matching jobs near you arrive here as homeowners '
                              'post them.'
                          : 'Your plan is Standard, so nothing is being sent '
                              'yet. Upgrading to Pro or Advance turns leads on '
                              'immediately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              if (plan.receivesLeads) ...[
                _BoardHeader(count: _jobs?.length ?? 0, onRefresh: _load),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: leadsBrand),
                    ),
                  )
                else if (_error != null)
                  _BoardMessage(
                    icon: LucideIcons.cloudOff,
                    title: 'Could not load jobs',
                    body: _error!,
                    onRetry: _load,
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: StaticJobsMap(
                      points: [
                        for (final j in _jobs ?? const <NearbyJob>[])
                          if (j.hasPin) (lat: j.latitude!, lng: j.longitude!),
                      ],
                      home: app.baseLatitude != null &&
                              app.baseLongitude != null
                          ? (lat: app.baseLatitude!, lng: app.baseLongitude!)
                          : null,
                    ),
                  ),
                  if ((_jobs ?? const []).isEmpty)
                    _BoardMessage(
                      icon: LucideIcons.inbox,
                      title: 'No jobs near you right now',
                      body: 'We will notify you the moment one is posted '
                          'inside your area.',
                      onRetry: _load,
                    )
                  else
                    for (final job in _jobs!) _JobRow(job: job),
                ],
              ] else
                _BoardMessage(
                  icon: LucideIcons.lock,
                  title: 'Leads are off on your plan',
                  body: 'Upgrade to Pro or Advance and jobs near you start '
                      'appearing here.',
                ),

              const LeadsCaption('What you are matched on'),
              _Coverage(app: app, plan: plan),
            ],
          );
        },
      ),
      // Only when the plan is the thing standing in the way. On Pro or
      // Advance there is nothing to upgrade to that changes this screen, and
      // a permanent Upgrade button on a page somebody already paid for reads
      // as a shop rather than a tool.
      bottomNavigationBar:
          BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
        buildWhen: (a, b) => a.plan != b.plan,
        builder: (context, state) {
          if (state.plan.receivesLeads) return const SizedBox.shrink();
          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, auth) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openPlans(context, auth),
                    icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                    label: const Text('Upgrade to start receiving leads'),
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
                          ?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens the plan picker the settings screen already uses.
  ///
  /// `fromSettings: true` is what makes it the back-button variant rather than
  /// the sign-up gate — without it, closing the picker clears the stack and
  /// dumps somebody on home instead of returning them here.
  void _openPlans(BuildContext context, AuthState auth) {
    final route =
        auth.userDetails?.accountType == AccountCategoryType.business
            ? '/businessSubscription'
            : '/tradesmanSubscription';
    Navigator.of(context).pushNamed(
      route,
      arguments: const ChoosePlanArgs(fromSettings: true),
    );
  }
}

/// The trades and the area a job has to fall inside to reach them.
class _Coverage extends StatelessWidget {
  const _Coverage({required this.app, required this.plan});

  final LeadApplication app;
  final LeadsPlan plan;

  String _name(String key) {
    for (final s in tradesmanServices) {
      if (s.key == key) return s.name;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final trades = app.services.map(_name).toList()..sort();
    return LeadsCard(
      children: [
        _Line(
          label: trades.length == 1 ? 'Trade' : 'Trades',
          value: trades.join(', '),
        ),
        const LeadsDivider(),
        _Line(
          label: 'From',
          value: app.baseAddress.isEmpty ? '—' : app.baseAddress,
        ),
        const LeadsDivider(),
        _Line(label: 'Within', value: plan.radiusLabel),
        const LeadsDivider(),
        _Line(
          label: 'Emergencies',
          value: app.takesEmergencies ? 'Yes' : 'No',
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
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
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The heading above the board, with a way to look again.
class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.count, required this.onRefresh});

  final int count;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0
                  ? 'JOBS NEAR YOU'
                  : '$count ${count == 1 ? 'JOB' : 'JOBS'} NEAR YOU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.refreshCw,
                size: 16, color: Colors.grey.shade600),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// One job on the board.
///
/// Shows the area and the distance, never the address — that arrives with the
/// job, not before it.
class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});

  final NearbyJob job;

  Color get _urgencyTint => switch (job.urgency) {
        'urgent' => const Color(0xFFDC2626),
        'flexible' => const Color(0xFF64748B),
        _ => const Color(0xFF3B82F6),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LeadDetailScreen(job: job)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: job.mine ? leadsBrand : Colors.grey.shade200,
                width: job.mine ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (job.mine)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: leadsBrand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'YOURS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: leadsBrand,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _urgencyTint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          job.urgencyLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _urgencyTint,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  job.serviceName,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                if (job.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    job.description.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      // Area, not address.
                      [job.postcodeDistrict, job.distanceLabel]
                          .where((v) => (v ?? '').isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (job.offersSent > 1)
                      Text(
                        // Said plainly. Somebody deciding whether to quote
                        // deserves to know how many others were asked.
                        'Sent to ${job.offersSent}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
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

class _BoardMessage extends StatelessWidget {
  const _BoardMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: const Text('Look again'),
            ),
          ],
        ],
      ),
    );
  }
}
