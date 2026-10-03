import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/job_requests/job_requests_bloc.dart';
import '../jobs/jobs_page.dart';
import '../profile/profile_page.dart';
import '../tools/tools_page.dart';
import 'home_screen.dart';

/// Container scaffold hosting the bottom-nav layout.
///
/// The same bar as the Pro app, down to the sizes and weights, so the two
/// apps feel like one product. The tabs differ because the apps do: a
/// homeowner has no Journal. Home, Jobs, Tools and Profile are what exist
/// today — adding a tab is one entry in [_items] plus one page in [_pages].
///
/// Plans is not a tab: it is reached from the Profile tab's plan card, which
/// is where the pro app puts it too. A paywall is somewhere you go when you
/// want more, not a permanent fifth of the navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTabIndex});

  final int? initialTabIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  static const _pages = [
    HomeScreen(),
    JobsPage(),
    ToolsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTabIndex ?? 0;
  }

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return HomeNavScope(
      switchTab: _onTap,
      child: Scaffold(
        // IndexedStack keeps each page's state alive across tab switches, so
        // a half-filled form or a scroll position survives a trip to Profile.
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: BlocBuilder<JobRequestsBloc, JobRequestsState>(
          // buildWhen so a job changing address or description does not
          // rebuild the whole bar — only the number it draws matters here.
          buildWhen: (a, b) => a.openCount != b.openCount,
          builder: (context, state) => _BottomNav(
            currentIndex: _index,
            onTap: _onTap,
            openJobs: state.openCount,
          ),
        ),
      ),
    );
  }
}

/// Exposes the tab-switching callback to descendants, so a button on the Home
/// tab can switch tabs without pushing a second copy of a page onto the
/// stack. Use `HomeNavScope.of(context)?.switchTab(i)`.
class HomeNavScope extends InheritedWidget {
  const HomeNavScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  final void Function(int index) switchTab;

  static HomeNavScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeNavScope>();

  @override
  bool updateShouldNotify(HomeNavScope old) => false;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.openJobs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Jobs posted and not yet done or cancelled.
  final int openJobs;

  static const _items = <({IconData icon, String label})>[
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.briefcase, label: 'Jobs'),
    (icon: LucideIcons.wrench, label: 'Tools'),
    (icon: LucideIcons.user, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.background,
        border: Border(
          top: BorderSide(color: colorScheme.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavTab(
                    icon: _items[i].icon,
                    label: _items[i].label,
                    isSelected: i == currentIndex,
                    // Only the Jobs tab counts anything. Passing 0 elsewhere
                    // keeps the badge decision in one place rather than
                    // building two kinds of tab.
                    badge: i == 1 ? openJobs : 0,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Shown over the icon when above zero. Zero draws nothing at all — an
  /// empty badge is worse than no badge.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isSelected ? colorScheme.primary : colorScheme.mutedForeground;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The badge sits outside the icon's box and must not be clipped
            // by it, so the stack is allowed to overflow rather than the icon
            // being made smaller to fit one.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: _Badge(count: badge),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The count over a tab icon.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Past 9 the number stops being readable at this size and the pill starts
    // pushing into the neighbouring tab, so it caps.
    final text = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF64C13),
        borderRadius: BorderRadius.circular(8),
        // A ring in the bar's own colour, so the pill reads as sitting on top
        // of the icon rather than merging with it.
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
