import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/lead_application.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import 'leads_account_type_screen.dart';
import 'leads_journey.dart';
import 'leads_application.dart';
import 'leads_ui.dart';

/// What live leads are, and what applying commits you to.
///
/// Deliberately the whole explanation up front rather than a tooltip on each
/// later step. The single thing people get wrong about this product is
/// assuming applying is the same as receiving — so that distinction is the
/// first thing on the page, not a footnote after four screens of forms.
class LeadsIntroScreen extends StatelessWidget {
  const LeadsIntroScreen({
    super.key,
    required this.plan,
    this.previous,
    this.titleOverride,
  });

  /// Forces the app bar title — see [LeadsStatusScreen.titleOverride].

  final LeadsPlan plan;

  /// A rejected, withdrawn or superseded application to start from, so
  /// re-applying is a correction rather than a retype.
  final LeadApplication? previous;

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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF64C13), Color(0xFFFF7A45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.radioTower,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Get verified, get live leads',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'One application. It verifies your account — which opens '
                  'emailing quotes and invoices from Fix It Felix, and share '
                  'links customers can accept — and puts jobs from homeowners '
                  'near you straight on your phone.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),

          const LeadsCaption('How it works'),
          const LeadsCard(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              _Step(
                n: '1',
                title: 'Tell us about your work',
                body: 'How you work, your trades, where you travel from, and '
                    'who insures you.',
              ),
              _Step(
                n: '2',
                title: 'Show us who you are',
                body: 'A photo ID and a selfie, at the end. Stored privately '
                    'and seen only by the person checking it.',
              ),
              _Step(
                n: '3',
                title: 'We check it by hand',
                body: 'Usually within two working days. Approved, your account '
                    'is verified and matching jobs start arriving.',
                last: true,
              ),
            ],
          ),

          const LeadsCaption('Your plan'),
          LeadsCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              Row(
                children: [
                  Text(
                    plan.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: plan.receivesLeads
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      plan.receivesLeads ? 'LEADS ON' : 'LEADS OFF',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: plan.receivesLeads
                            ? const Color(0xFF065F46)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LeadsCheckLine(
                text: 'Visibility: ${plan.radiusLabel}',
                included: plan.receivesLeads,
              ),
              LeadsCheckLine(
                text: 'Live Leads delivered to your inbox',
                included: plan.receivesLeads,
              ),
              LeadsCheckLine(
                text: 'Apply and be verified',
                included: true,
              ),
              LeadsCheckLine(
                text: 'Apply as a business with multiple trades',
                included: plan.allowsBusiness,
              ),
            ],
          ),

          // The distinction the whole screen exists to make.
          if (!plan.receivesLeads)
            const LeadsNotice(
              icon: LucideIcons.info,
              text: 'You can apply and be approved on Standard. Live leads '
                  'start arriving the moment you move to Pro or Advance — you '
                  'will not have to apply again.',
            ),

          const LeadsCaption('What you will need'),
          const LeadsCard(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              _Need(
                icon: LucideIcons.hammer,
                text: 'The trades you want work in',
              ),
              _Need(
                icon: LucideIcons.mapPin,
                text: 'The area you are willing to travel from',
              ),
              _Need(
                icon: LucideIcons.shieldCheck,
                text: 'Your public liability insurance details',
              ),
              _Need(
                icon: LucideIcons.badgeCheck,
                text: 'Gas Safe or electrical scheme number, if you offer '
                    'those trades',
              ),
              _Need(
                icon: LucideIcons.idCard,
                text: 'A passport, driving licence or ID card, and a selfie',
                last: true,
              ),
            ],
          ),

          const LeadsNotice(
            icon: LucideIcons.lock,
            tone: LeadsNoticeTone.locked,
            text: 'Your documents are stored privately, seen only by the '
                'person checking your application, and never shown to '
                'customers.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsAccountTypeScreen(
                    draft: LeadsApplicationDraft.from(previous, plan: plan),
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
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.body,
    this.last = false,
  });

  final String n;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: leadsBrand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: leadsBrand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Need extends StatelessWidget {
  const _Need({required this.icon, required this.text, this.last = false});

  final IconData icon;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
