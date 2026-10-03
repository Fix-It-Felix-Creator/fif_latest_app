import 'package:flutter/material.dart';

import 'job_requests_screen.dart';

/// Bottom-nav tab host for the Jobs section.
///
/// Points at [JobRequestsScreen] — the jobs this customer POSTED.
///
/// The ported `JobsScreen` beside it is now unreachable. It listed
/// `public.jobs`, a tradesperson's own work records, which is always empty for
/// a customer, and its row tap pushed `/jobs/new` — a route `lib/routes.dart`
/// never registered, so tapping a row could only ever have thrown. It and the
/// job editor it opens are left in place rather than deleted here: that is a
/// removal of its own, not a side effect of pointing this tab somewhere else.
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) => const JobRequestsScreen();
}
