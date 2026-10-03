import 'package:flutter/material.dart';

import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/enum.dart';
import '../../models/lead_application.dart';
import '../verification/verification_status_screen.dart';
import 'leads_intro_screen.dart';
import 'leads_status_screen.dart';
import 'live_leads_screen.dart';

/// Where the verification journey sends somebody, and what to call it.
///
/// One definition, used by the home card and by the Settings row. They are two
/// doors onto the same room, and when each worked out for itself where that
/// room was they drifted — one offering "get live leads" while the other
/// offered "verify your account", with nothing saying the second came first.
class LeadsJourney {
  const LeadsJourney._();

  /// The screen for whatever stage this account is at.
  static Widget destination(
    LeadApplicationState leads,
    VerificationStatus? verification, {
    /// Forces the app bar title on whichever screen this resolves to.
    ///
    /// Settings passes 'Verification', because its row is called "Verify your
    /// account" and a screen headed anything else is a door that lies about
    /// the room behind it. The home card passes nothing and lets the title
    /// follow the stage.
    String? title,
  }) {
    final status = leads.application?.status;

    // From Settings, the answer is always about verification — the row is
    // called "Verify your account" and somebody tapping it is asking about
    // their account, not about work.
    if (title == 'Verification') return const VerificationStatusScreen();

    // From the home card: once approved, the card has done its job as a hook
    // and becomes the way into live leads.
    if (status == LeadApplicationStatus.approved) {
      return const LiveLeadsScreen();
    }
    if (status == LeadApplicationStatus.submitted) {
      return LeadsStatusScreen(titleOverride: title);
    }
    return LeadsIntroScreen(plan: leads.plan, titleOverride: title);
  }

  /// What to call this journey, where somebody currently stands in it.
  ///
  /// "Live leads" is the destination, not the journey. Calling every screen
  /// that before anybody is verified promises the wrong thing — somebody part
  /// way through an identity check is not looking at live leads, they are
  /// looking at verification.
  static String title(
    LeadApplicationState leads,
    VerificationStatus? verification,
  ) {
    final approved =
        leads.application?.status == LeadApplicationStatus.approved;
    return approved || verification == VerificationStatus.verified
        ? 'Live Leads'
        : 'Verification';
  }

  /// One line for a settings row: where they are, in their own terms.
  static String subtitle(
    LeadApplicationState leads,
    VerificationStatus? verification,
  ) {
    switch (leads.application?.status) {
      case LeadApplicationStatus.submitted:
        return 'Being checked';
      case LeadApplicationStatus.approved:
        return 'Verified';
      case LeadApplicationStatus.rejected:
        return 'Needs attention';
      case LeadApplicationStatus.withdrawn:
        return 'Withdrawn — you can apply again';
      default:
        break;
    }
    // No application, but the account may have been verified some other way.
    return verification == VerificationStatus.verified
        ? 'Verified'
        : 'Not verified';
  }

  /// Colour for the settings row's icon.
  static Color tint(
    LeadApplicationState leads,
    VerificationStatus? verification,
  ) {
    switch (leads.application?.status) {
      case LeadApplicationStatus.approved:
        return const Color(0xFF059669);
      case LeadApplicationStatus.rejected:
        return const Color(0xFFDC2626);
      case LeadApplicationStatus.submitted:
        return const Color(0xFFD97706);
      default:
        return verification == VerificationStatus.verified
            ? const Color(0xFF059669)
            : const Color(0xFF6366F1);
    }
  }
}
