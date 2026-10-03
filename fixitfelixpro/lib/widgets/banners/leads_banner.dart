import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/enum.dart';
import '../../models/lead_application.dart';
import '../../screens/leads/leads_intro_screen.dart';
import '../../screens/leads/leads_journey.dart';

/// The one card on the home tab for getting work.
///
/// Deliberately ONE card, not two. Verification and live leads were showing
/// separately and saying different things — a tradesperson could be told "get
/// live leads" by one and "verify your account" by the other, with no
/// indication that the second was a prerequisite for the first.
///
/// They are one journey, and this renders whichever stage of it somebody is
/// at:
///
///   not verified   → verify your account
///   being checked  → we are checking your documents
///   turned down    → what needs fixing
///   verified       → get live leads
///   applied        → your application is in review
///   approved       → you are approved
///
/// Every state taps through to the screen for that stage, so there is never a
/// question of where to go next: there is only ever one next thing.
class LeadsBanner extends StatelessWidget {
  const LeadsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) =>
          a.userDetails?.verificationStatus !=
          b.userDetails?.verificationStatus,
      builder: (context, auth) {
        final verification = auth.userDetails?.verificationStatus;
        return BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
          // Only the status and the plan change what this draws. Rebuilding
          // on every field of the application would repaint the home tab for
          // nothing.
          buildWhen: (a, b) =>
              a.application?.status != b.application?.status ||
              a.plan != b.plan,
          builder: (context, leads) => _Banner(
            verification: verification,
            leads: leads,
          ),
        );
      },
    );
  }
}

/// What the card says, where it goes, and how loudly.
class _Stage {
  const _Stage({
    required this.badge,
    required this.title,
    required this.body,
    required this.cta,
    required this.destination,
    this.urgent = false,
    this.footnote,
  });

  final String badge;
  final String title;
  final String body;
  final String cta;
  final Widget Function() destination;

  /// Red rather than charcoal. Reserved for the two states somebody has to do
  /// something about — everything else can wait until they are ready.
  final bool urgent;

  final String? footnote;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.verification, required this.leads});

  final VerificationStatus? verification;
  final LeadApplicationState leads;

  _Stage _stage() {
    // One application, so one sequence. The verification status only matters
    // for the two states the application itself cannot describe: an account
    // verified some other way, and one whose approval was later revoked.
    final status = leads.application?.status;

    switch (status) {
      case LeadApplicationStatus.submitted:
        return _Stage(
          badge: 'IN REVIEW',
          title: 'We are verifying your account',
          body: 'Our team looks at every one by hand, usually within two '
              'working days. We will let you know either way.',
          cta: 'View application',
          destination: () => LeadsJourney.destination(leads, verification),
        );
      case LeadApplicationStatus.rejected:
        return _Stage(
          badge: 'ACTION NEEDED',
          title: 'Your verification needs attention',
          // Deliberately not the reason itself. It can be a paragraph, and a
          // banner is not where somebody should read bad news in full.
          body: 'There is something to fix before we can approve you. Tap to '
              'see what.',
          cta: 'See what to fix',
          urgent: true,
          destination: () => LeadsJourney.destination(leads, verification),
        );
      case LeadApplicationStatus.approved:
        // The hook has done its job. From here the card IS the live leads
        // entry point, and says nothing about verification.
        return _Stage(
          badge: leads.plan.receivesLeads ? 'LIVE' : 'READY',
          title: 'Live Leads',
          body: leads.plan.receivesLeads
              ? 'Matching jobs near you arrive here as homeowners post them.'
              : 'Your plan does not receive leads yet. Upgrading turns them '
                  'on immediately.',
          cta: leads.plan.receivesLeads ? 'Open live leads' : 'Upgrade',
          destination: () => LeadsJourney.destination(leads, verification),
        );
      default:
        break;
    }

    // Verified but no application in play — possible after a withdrawal.
    if (verification == VerificationStatus.verified) {
      return _Stage(
        badge: 'VERIFIED',
        title: 'Get live leads',
        body: 'Your account is verified. Apply once and matching jobs near '
            'you come straight to your phone.',
        cta: 'See how it works',
        footnote: leads.plan.receivesLeads ? null : 'Pro or Advance to receive',
        destination: () => LeadsJourney.destination(leads, verification),
      );
    }

    return _Stage(
      badge: 'START HERE',
      title: 'Get Live Leads',
      body: 'Customers only see verified tradespeople. It takes one '
          'application — what you do, where you work, and who you are.',
      cta: 'See how it works',
      footnote: leads.plan.receivesLeads ? null : 'Pro or Advance to receive',
      destination: () => LeadsIntroScreen(plan: leads.plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => stage.destination()),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: stage.urgent
                    ? const [Color(0xFF7F1D1D), Color(0xFF450A0A)]
                    : const [Color(0xFF1F2937), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF64C13)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          LucideIcons.radioTower,
                          size: 17,
                          color: Color(0xFFFF7A45),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stage.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          stage.badge,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stage.body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        stage.cta,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF7A45),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.arrowRight,
                          size: 14, color: Color(0xFFFF7A45)),
                      const Spacer(),
                      if (stage.footnote != null)
                        Text(
                          stage.footnote!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
