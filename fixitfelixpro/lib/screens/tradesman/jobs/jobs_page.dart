import 'package:flutter/material.dart';

import '../../jobs/jobs_screen.dart';

/// Bottom-nav tab host for the Jobs section. Just defers to the
/// real list under lib/screens/jobs/ so the same screen is reusable
/// from a deep link or a route push.
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) => const JobsScreen();
}
