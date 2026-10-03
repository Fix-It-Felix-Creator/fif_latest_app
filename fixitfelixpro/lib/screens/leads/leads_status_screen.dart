import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/data/tradesman_services.dart';
import '../../models/lead_application.dart';
import 'leads_application.dart';
import 'leads_intro_screen.dart';
import 'leads_journey.dart';
import 'leads_ui.dart';

/// Where an application has got to, live.
///
/// Reads the bloc rather than taking a snapshot, so an approval that lands
/// while somebody is looking at this screen changes it under them — which is
/// exactly what they are sitting there waiting for.
class LeadsStatusScreen extends StatelessWidget {
  const LeadsStatusScreen({super.key, this.titleOverride});

  /// Forces the app bar title.
  ///
  /// Set when somebody arrived from the Verification row in Settings. Tapping
  /// "Verify your account" and landing on a screen headed "Live leads" is
  /// wrong however verified the account happens to be — the title has to match
  /// the door, not the stage.
  final String? titleOverride;

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
        title: titleOverride != null
            ? Text(titleOverride!)
            : BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
                builder: (context, leads) => BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, auth) => Text(
                    LeadsJourney.title(
                      leads,
                      auth.userDetails?.verificationStatus,
                    ),
                  ),
                ),
              ),
      ),
      body: BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
        builder: (context, state) {
          if (state.status == LeadApplicationStateStatus.loading &&
              state.application == null) {
            return const Center(
              child: CircularProgressIndicator(color: leadsBrand),
            );
          }
          // Error before empty. "You have not applied" is a lie when the truth
          // is that we could not read whether you had.
          if (state.status == LeadApplicationStateStatus.error &&
              state.application == null) {
            return _Failed(
              message: state.errorMessage,
              onRetry: () => context
                  .read<LeadApplicationBloc>()
                  .add(const LeadApplicationStartWatching()),
            );
          }

          final app = state.application;
          if (app == null || app.status.allowsReapply) {
            return _Closed(previous: app, plan: state.plan);
          }
          return _Open(app: app, plan: state.plan);
        },
      ),
    );
  }
}

/// A live application — submitted and waiting, or approved.
class _Open extends StatelessWidget {
  const _Open({required this.app, required this.plan});

  final LeadApplication app;
  final LeadsPlan plan;

  /// Only ever reached while the application is still being reviewed.
  ///
  /// Pulling something out of a queue before anybody has looked at it costs
  /// nothing. Withdrawing an APPROVED one would cost the account its
  /// verification, which is not a button.
  Future<void> _confirmWithdraw(BuildContext context) async {
    final bloc = context.read<LeadApplicationBloc>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this?'),
        content: const Text(
          'Your application will be taken out of the queue before anybody '
          'reviews it. You can send a new one whenever you like.',
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
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (yes == true) bloc.add(LeadApplicationWithdrawRequested(app.id));
  }

  @override
  Widget build(BuildContext context) {
    final approved = app.status == LeadApplicationStatus.approved;
    final tint =
        approved ? const Color(0xFF059669) : const Color(0xFFD97706);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            children: [
              // Two different screens sharing one widget, because they are
              // two different moments. Waiting is about verification — what
              // was sent, and what happens next. Approved is about live leads
              // — verification is finished and does not need recapping every
              // time somebody opens it.
              if (!approved) ...[
                _Hero(
                  icon: LucideIcons.clock,
                  tint: tint,
                  title: 'We are reviewing your application',
                  body: 'Our team checks every application by hand, usually '
                      'within two working days. We will notify you either '
                      'way.',
                ),
                _Summary(app: app),
                const LeadsCard(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  children: [
                    LeadsCheckLine(
                        text: 'Your account carries on exactly as before',
                        included: true),
                    LeadsCheckLine(
                        text: 'Jobs, quotes and invoices are unaffected',
                        included: true),
                    LeadsCheckLine(
                        text: 'We will notify you when a decision is made',
                        included: true),
                  ],
                ),
              ] else ...[
                _Hero(
                  icon: LucideIcons.radioTower,
                  tint: plan.receivesLeads
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                  title: plan.receivesLeads
                      ? 'You are live'
                      : 'Ready when you upgrade',
                  body: plan.receivesLeads
                      ? 'Matching jobs near you arrive here as homeowners '
                          'post them.'
                      : 'Your plan is Standard, so nothing is being sent yet. '
                          'Upgrading to Pro or Advance turns leads on '
                          'immediately.',
                ),

                const LeadsCaption('Where you are matched'),
                _Coverage(app: app, plan: plan),
              ],
            ],
          ),
        ),
        // No withdraw button once approved.
        //
        // This application IS the verification. Withdrawing it would pull the
        // thing that grants sending quotes, sharing invoices and share links —
        // not just leads — and a full-width destructive button labelled "stop
        // receiving leads" is a wildly dishonest description of that.
        //
        // Somebody who wants to stop leads temporarily needs a pause, which is
        // a different control on a different screen. Somebody who wants to
        // leave entirely can ask support, which is the right amount of
        // friction for undoing an identity check.
        if (app.status == LeadApplicationStatus.submitted)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmWithdraw(context),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Withdraw application'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// No live application: never applied, or rejected, withdrawn or superseded.
class _Closed extends StatelessWidget {
  const _Closed({required this.previous, required this.plan});

  final LeadApplication? previous;
  final LeadsPlan plan;

  @override
  Widget build(BuildContext context) {
    final rejected =
        previous?.status == LeadApplicationStatus.rejected;
    final withdrawn =
        previous?.status == LeadApplicationStatus.withdrawn;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            children: [
              if (rejected)
                _Hero(
                  icon: LucideIcons.circleX,
                  tint: const Color(0xFFDC2626),
                  title: 'We could not approve this yet',
                  body: 'This is not final. Most applications go through once '
                      'the point below is sorted out.',
                )
              else if (withdrawn)
                _Hero(
                  icon: LucideIcons.undo2,
                  tint: const Color(0xFF6B7280),
                  title: 'You withdrew your application',
                  body: 'You can send a new one whenever you are ready. '
                      'Everything you filled in is still here.',
                )
              else
                _Hero(
                  icon: LucideIcons.radioTower,
                  tint: leadsBrand,
                  title: 'Get live leads',
                  body: 'Apply once and matching jobs near you come straight '
                      'to your phone.',
                ),

              // The whole point of storing a reason. A rejection that says
              // only "no" produces a support ticket; one that says what to fix
              // produces a better application.
              if (rejected)
                LeadsCard(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.messageSquareWarning,
                            size: 16, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 8),
                        const Text(
                          'What needs fixing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      previous?.rejectionReason ??
                          'Our team will be in touch with the details.',
                      style: const TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ],
                ),

              if (previous != null) _Summary(app: previous!),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LeadsIntroScreen(
                      plan: plan,
                      // Re-applying starts from what they sent last time.
                      previous: previous,
                    ),
                  ),
                ),
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
                child: Text(
                  previous == null ? 'Start my application' : 'Apply again',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: tint),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// What was sent, so they can check it without digging.
class _Summary extends StatelessWidget {
  const _Summary({required this.app});

  final LeadApplication app;

  String _name(String key) {
    for (final s in tradesmanServices) {
      if (s.key == key) return s.name;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final trades = app.services.map(_name).toList()..sort();
    return Column(
      children: [
        const LeadsCaption('What you sent'),
        LeadsCard(
          children: [
            _Line(
              label: 'Applying as',
              value: app.isSolo ? 'Solo tradesperson' : 'Business',
            ),
            const LeadsDivider(),
            _Line(
              label: trades.length == 1 ? 'Trade' : 'Trades',
              value: trades.join(', '),
            ),
            const LeadsDivider(),
            _Line(
              label: 'Works from',
              value: app.baseAddress.isEmpty ? '—' : app.baseAddress,
            ),
            if (app.registrations.isNotEmpty) ...[
              const LeadsDivider(),
              for (final e in app.registrations.entries)
                _Line(label: _name(e.key), value: e.value),
            ],
          ],
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
            const Icon(LucideIcons.cloudOff,
                size: 30, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            const Text(
              'We could not load your application',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Anything you sent is still there — this is the status failing '
              'to load, not the application.',
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

/// What a live tradesperson is actually matched on.
///
/// The one thing worth showing once verification is behind them: the trades
/// and the area a job has to fall inside before it reaches them. Everything
/// else about the application is history.
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
