import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/notifications/notifications_bloc.dart';
import '../../blocs/notifications/notifications_event.dart';
import '../../services/push_notifications_service.dart';
import 'home/home_page.dart';
import 'jobs/jobs_page.dart';
import 'journal/journal_page.dart';
import 'profile/profile_page.dart';
import 'tools/tools_page.dart';

/// Container scaffold hosting the 5-tab bottom-nav layout.
/// Each tab has its own page with its own `AppBar`.
class TradesmanHomeScreen extends StatefulWidget {
  const TradesmanHomeScreen({
    super.key,
    this.initialTabIndex,
    this.initialJobsTabIndex,
  });

  final int? initialTabIndex;
  final int? initialJobsTabIndex;

  @override
  State<TradesmanHomeScreen> createState() => _TradesmanHomeScreenState();
}

class _TradesmanHomeScreenState extends State<TradesmanHomeScreen> {
  late int _index;

  static const _pages = [
    HomePage(),
    JobsPage(),
    JournalPage(),
    ToolsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTabIndex ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<NotificationsBloc>()
          .add(const NotificationsStartWatching());
      PushNotificationsService.instance.initialise();
    });
  }

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return TradesmanNavScope(
      switchTab: _onTap,
      child: Scaffold(
        // IndexedStack keeps each page's state alive across tab switches.
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: _BottomNav(
          currentIndex: _index,
          onTap: _onTap,
        ),
      ),
    );
  }
}

/// Exposes the tab-switching callback to descendants (e.g. the quick
/// actions on the Home tab). Use `TradesmanNavScope.of(context).switchTab(i)`.
class TradesmanNavScope extends InheritedWidget {
  const TradesmanNavScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  final void Function(int index) switchTab;

  static TradesmanNavScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TradesmanNavScope>();

  @override
  bool updateShouldNotify(TradesmanNavScope old) => false;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <({IconData icon, String label})>[
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.briefcase, label: 'Jobs'),
    (icon: LucideIcons.bookOpen, label: 'Journal'),
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
          top: BorderSide(
            color: colorScheme.border.withValues(alpha: 0.5),
          ),
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
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.mutedForeground;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
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
