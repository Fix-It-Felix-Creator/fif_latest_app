import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/notifications/notifications_bloc.dart';
import '../../blocs/notifications/notifications_event.dart';
import '../../widgets/notification_badge.dart';
import 'home_services_section.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Where a signed-in customer lands.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Own controller, so this list does not claim the ambient
  /// PrimaryScrollController — every tab of the shell is built at once, and
  /// three scroll views sharing one controller is what Scrollbar asserts on.
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    // After the first frame: adding a bloc event during build is what causes
    // "setState called during build" inside a tab shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsBloc>().add(const NotificationsStartWatching());
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      // A fixed header above a scrolling list, rather than an app bar and a
      // hero inside one scroll view.
      //
      // Those were two slivers sharing a colour: scrolling pulled them apart
      // and the page showed through the seam. Folding the greeting into the
      // bar's flexibleSpace then laid it BEHIND the toolbar, so the wordmark
      // printed over the customer's name. Taking the whole orange block out of
      // the scroll view removes both failures — there is one widget, it never
      // moves, and nothing can slide out from under anything else.
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              primary: false,
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: const [HomeServicesSection()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The orange block at the top: wordmark, notifications, greeting.
///
/// Fixed. It sits outside the scroll view, so it neither collapses nor
/// scrolls away, and the list passes beneath its rounded bottom edge.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        // Only the top inset: the bottom belongs to the nav bar, and taking it
        // here would pad the header by the home indicator's height.
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fix It Felix',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  NotificationBadge(
                    child: IconButton(
                      tooltip: 'Notifications',
                      iconSize: 20,
                      icon: const Icon(LucideIcons.bell, color: Colors.white),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/notifications'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _Greeting(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => a.userDetails != b.userDetails,
      builder: (context, state) {
        final u = state.userDetails;
        final displayName = _buildDisplayName(
          firstName: u?.firstName,
          lastName: u?.lastName,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greetingPrefix(),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              displayName.isEmpty ? 'Welcome' : displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ],
        );
      },
    );
  }

  String _greetingPrefix() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  /// Display rule: if the first name field already holds two or more
  /// space-separated parts (e.g. "Mary Anne"), show just that. If `firstName`
  /// is a single token, append `lastName` so it reads as "First Last".
  static String _buildDisplayName({
    required String? firstName,
    required String? lastName,
  }) {
    final first = (firstName ?? '').trim();
    if (first.isEmpty) return '';
    final parts = first.split(RegExp(r'\s+'));
    if (parts.length >= 2) return first;
    final last = (lastName ?? '').trim();
    if (last.isEmpty) return first;
    return '$first $last';
  }
}
