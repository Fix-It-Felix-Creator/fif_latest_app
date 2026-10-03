import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/enum.dart';
import '../../models/lead_application.dart';
import '../leads/leads_intro_screen.dart';
import '../leads/leads_ui.dart';

/// Whether this account is verified, and nothing else.
///
/// Reached from the Verification row in Settings. It deliberately says nothing
/// about live leads: somebody checking "am I verified" is asking about their
/// account, not about work. Leads are one of the things verification opens,
/// not what verification is.
class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

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
        title: const Text('Verification'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          return BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
            builder: (context, leads) {
              final verification = auth.userDetails?.verificationStatus;
              final app = leads.application;
              final status = app?.status;

              // The application is how somebody gets verified, so its state is
              // the honest answer to "where is my verification up to" — but it
              // is described here as verification, because that is what the
              // person came to ask about.
              final verified = verification == VerificationStatus.verified ||
                  status == LeadApplicationStatus.approved;
              final waiting = !verified &&
                  status == LeadApplicationStatus.submitted;
              final rejected = !verified &&
                  (status == LeadApplicationStatus.rejected ||
                      verification == VerificationStatus.rejected);

              final (icon, tint, title, body) = verified
                  ? (
                      LucideIcons.badgeCheck,
                      const Color(0xFF059669),
                      'Your account is verified',
                      'We have checked your ID and you are confirmed as a '
                          'real tradesperson.',
                    )
                  : waiting
                      ? (
                          LucideIcons.clock,
                          const Color(0xFFD97706),
                          'We are checking your details',
                          'Our team looks at every account by hand, usually '
                              'within two working days. We will let you know '
                              'either way.',
                        )
                      : rejected
                          ? (
                              LucideIcons.circleX,
                              const Color(0xFFDC2626),
                              'We could not verify you yet',
                              'This is not final. Most accounts go through '
                                  'once the point below is sorted out.',
                            )
                          : (
                              LucideIcons.shieldQuestion,
                              leadsBrand,
                              'Your account is not verified',
                              'A photo ID and a selfie, checked by our team. '
                                  'It is how customers know the person we send '
                                  'is who they say they are.',
                            );

              final reason = app?.rejectionReason ??
                  auth.userDetails?.rejectionReason;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
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
                        ),

                        if (rejected)
                          LeadsCard(
                            padding: const EdgeInsets.all(14),
                            children: [
                              Row(
                                children: const [
                                  Icon(LucideIcons.messageSquareWarning,
                                      size: 16, color: Color(0xFFB91C1C)),
                                  SizedBox(width: 8),
                                  Text(
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
                                (reason ?? '').trim().isEmpty
                                    ? 'Our team will be in touch with the '
                                        'details.'
                                    : reason!.trim(),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),

                        const LeadsCaption('What we checked'),
                        LeadsCard(
                          children: [
                            _Row(
                              label: 'Photo ID',
                              value: _documentLabel(app?.documentType) ??
                                  'Not provided',
                              done: app?.documentType != null,
                            ),
                            const LeadsDivider(),
                            _Row(
                              label: 'Selfie',
                              value: verified || waiting || rejected
                                  ? 'Provided'
                                  : 'Not provided',
                              done: verified || waiting || rejected,
                            ),
                          ],
                        ),

                        if (!verified && !waiting)
                          const LeadsNotice(
                            icon: LucideIcons.lock,
                            text: 'Your documents are stored privately and '
                                'seen only by the person checking them. They '
                                'are never shown to customers.',
                          ),
                      ],
                    ),
                  ),

                  if (!verified && !waiting)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LeadsIntroScreen(
                                  plan: leads.plan,
                                  previous: app,
                                  titleOverride: 'Verification',
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: leadsBrand,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                            child: Text(rejected ? 'Try again' : 'Get verified'),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String? _documentLabel(String? wire) => switch (wire) {
        'passport' => 'Passport',
        'driving_licence' => 'Driving licence',
        'id_card' => 'National ID card',
        _ => null,
      };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.done});

  final String label;
  final String value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(
            done ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 17,
            color: done ? const Color(0xFF059669) : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14.5)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
