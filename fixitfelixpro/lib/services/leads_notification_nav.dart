import 'package:flutter/material.dart';

import '../globals.dart';
import '../screens/verification/verification_status_screen.dart';

/// The type the `lead_applications_notify` trigger writes.
///
/// Still named for the table it comes from — the row is a lead_application —
/// but what it tells somebody about is their verification, which is what
/// approving that application decides.
const _leadsNotificationType = 'lead_application';

bool isLeadsNotificationType(String? type) =>
    type != null && type.toLowerCase() == _leadsNotificationType;

/// Opens the verification screen from a notification.
///
/// Verification, not live leads. The message says the account is verified, or
/// that verification needs attention — and landing somebody on a leads screen
/// after either would answer a question they did not ask. Live leads are one
/// of the things being verified opens, reachable from the home card.
///
/// No id lookup, unlike the quote and invoice helpers: there is only ever one
/// account to be verified, and the screen reads its state itself.
Future<void> openLeadsFromNotification() async {
  final navigator = globalNavigatorKey.currentState;
  if (navigator == null) return;
  await navigator.push(
    MaterialPageRoute(builder: (_) => const VerificationStatusScreen()),
  );
}
