import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../widgets/banners/leads_banner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../blocs/customers/customers_bloc.dart';
import '../../../blocs/customers/customers_event.dart';
import '../../../blocs/customers/customers_state.dart';
import '../../../blocs/jobs/jobs_bloc.dart';
import '../../../blocs/journal/journal_bloc.dart';
import '../../../blocs/journal/journal_event.dart' as j;
import '../../../blocs/journal/journal_state.dart';
import '../../../core/config/config_service.dart';
import '../../../models/customer.dart';
import '../../../models/job_model.dart';
import '../../../models/journal_entry.dart';
import '../../../repositories/jobs/jobs_repository.dart';
import '../../../widgets/banners/learn_banner.dart';
import '../../jobs/new_job_screen.dart';
import '../../../widgets/jobs/job_clock.dart';
import '../../../widgets/banners/share_banner.dart';
import '../../../widgets/notification_badge.dart';
import '../journal/journal_event_edit_screen.dart';
import '../tradesman_home.dart';

const _brand = Color(0xFFF64C13);
const _brandTint = Color(0xFFFFF4EE);

/// Home dashboard — greeting, next-up event, quick actions grid.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _topOverscroll = 0;
  // Local controller so the CustomScrollView doesn't fall back to
  // PrimaryScrollController. Sharing the primary controller across the
  // bottom-nav tab pages caused "attached to more than one
  // ScrollPosition" assertions once the home grew tall enough to
  // actually scroll (after the learn banner shipped).
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JournalBloc>().add(const j.JournalStartWatching());
      context.read<CustomersBloc>().add(const CustomersStartWatching());
      context.read<JobsBloc>().add(const JobsStartWatching());
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final p = n.metrics.pixels;
    final minE = n.metrics.minScrollExtent;
    final newOver = p < minE ? (minE - p) : 0.0;
    if ((newOver - _topOverscroll).abs() > 0.5) {
      setState(() => _topOverscroll = newOver);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300 + _topOverscroll,
            child: Container(color: _brand),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              controller: _scrollCtrl,
              primary: false,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  titleSpacing: 16,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Fix It Felix',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.montserrat(
                            color: _brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    NotificationBadge(
                      child: IconButton(
                        tooltip: 'Notifications',
                        iconSize: 20,
                        icon:
                            const Icon(LucideIcons.bell, color: Colors.white),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/notifications'),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                const SliverToBoxAdapter(child: _OrangeHero()),
                const SliverToBoxAdapter(child: _QuickActionsSection()),
                // Above the community and share banners: this one is about
                // getting work, which beats both of them for a tradesperson
                // opening the app on a quiet morning.
                const SliverToBoxAdapter(child: _HomeLeadsBanner()),
                const SliverToBoxAdapter(child: _HomeLearnBanner()),
                const SliverToBoxAdapter(child: _HomeShareBanner()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quick actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _QuickActionsGrid(),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final nav = TradesmanNavScope.of(context);

    final actions = <_Action>[
      _Action(
        icon: LucideIcons.users,
        label: 'Customers',
        color: _ActionPalette.indigo,
        onTap: () => Navigator.of(context).pushNamed('/customers'),
      ),
      _Action(
        icon: LucideIcons.briefcase,
        label: 'Jobs',
        color: _ActionPalette.blue,
        onTap: () => nav?.switchTab(1),
      ),
      _Action(
        icon: LucideIcons.fileText,
        label: 'Quotes',
        color: _ActionPalette.violet,
        onTap: () => Navigator.of(context).pushNamed('/quotes'),
      ),
      _Action(
        icon: LucideIcons.receipt,
        label: 'Invoices',
        color: _ActionPalette.rose,
        onTap: () => Navigator.of(context).pushNamed('/invoices'),
      ),
      _Action(
        icon: LucideIcons.bookOpen,
        label: 'Journal',
        color: _ActionPalette.teal,
        onTap: () => nav?.switchTab(2),
      ),
      _Action(
        icon: LucideIcons.calculator,
        label: 'Pricing',
        color: _ActionPalette.amber,
        onTap: () => Navigator.of(context).pushNamed('/pricing'),
      ),
      _Action(
        icon: LucideIcons.listChecks,
        label: 'To-Do',
        color: _ActionPalette.emerald,
        onTap: () => Navigator.of(context).pushNamed('/todos'),
      ),
      _Action(
        icon: LucideIcons.hardHat,
        label: 'Staff',
        color: _ActionPalette.orange,
        onTap: () => Navigator.of(context).pushNamed('/staff'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Explicit zero padding — the default ScrollView behaviour is to
      // inherit ambient MediaQuery padding, which was adding top inset.
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (_, i) => _ActionCard(action: actions[i]),
    );
  }

}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

class _ActionPalette {
  _ActionPalette._();

  static const indigo = Color(0xFF6366F1);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const rose = Color(0xFFF43F5E);
  static const teal = Color(0xFF14B8A6);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action.color ?? _brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live timers for every job the tradesperson is currently clocked in on.
/// Hidden when nothing is running; a single job shows one card, two or
/// more collapse behind an expandable header.
class _ActiveJobsSection extends StatelessWidget {
  const _ActiveJobsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JobsBloc, JobsState>(
      builder: (context, state) {
        final running =
            state.items.where((j) => j.isClockedIn).toList(growable: false);
        if (running.isEmpty) return const SizedBox.shrink();
        return HomeActiveJobs(
          jobs: running,
          margin: const EdgeInsets.only(top: 12),
          onClockOut: (Job job) =>
              context.read<JobsRepository>().clockOut(job),
          onTapJob: (Job job) => Navigator.of(context).pushNamed(
            '/jobs/new',
            arguments: NewJobArgs(existing: job),
          ),
        );
      },
    );
  }
}

class _OrangeHero extends StatelessWidget {
  const _OrangeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      // Bottom padding 32 so the 24px rounded corners always have room
      // to draw, even when there's no Next Up card below the greeting.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Greeting(),
          _ActiveJobsSection(),
          _NextUpSection(),
        ],
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

  /// Display rule: if the first name field already contains two or
  /// more space-separated parts (e.g. "Mary Anne"), show just that
  /// — the first part of `firstName` is enough on its own. If
  /// `firstName` is a single token, append `lastName` so the
  /// greeting reads as a full "First Last".
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

class _NextUpSection extends StatelessWidget {
  const _NextUpSection();

  JournalEntry? _findNext(List<JournalEntry> all) {
    for (final e in all) {
      if (!e.isPast) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalBloc, JournalState>(
      builder: (context, jState) {
        final next = _findNext(jState.entries);
        if (next == null) return const SizedBox.shrink();

        return BlocBuilder<CustomersBloc, CustomersState>(
          builder: (context, cState) {
            Customer? customer;
            final id = next.customerId;
            if (id != null) {
              for (final c in cState.items) {
                if (c.id == id) {
                  customer = c;
                  break;
                }
              }
            }
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _NextUpCard(entry: next, customer: customer),
            );
          },
        );
      },
    );
  }
}


class _NextUpCard extends StatefulWidget {
  const _NextUpCard({required this.entry, required this.customer});

  final JournalEntry entry;
  final Customer? customer;

  @override
  State<_NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<_NextUpCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    lowerBound: 0.94,
    upperBound: 1.0,
    value: 1.0,
  );

  JournalEntry get entry => widget.entry;
  Customer? get customer => widget.customer;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onLongPressStart() {
    _ctrl.animateTo(0.94, curve: Curves.easeOut);
  }

  void _onLongPressEnd() {
    _ctrl.animateTo(1.0, curve: Curves.easeOut);
  }

  Future<void> _openEdit() async {
    _onLongPressEnd();
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        opaque: true,
        pageBuilder: (_, __, ___) => JournalEventEditScreen(
          args: JournalEditArgs(existing: entry),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  String get _startsIn {
    final at = entry.startAtObj;
    if (entry.allDay || at == null) {
      final today = DateTime.now();
      final d = entry.dateObj;
      final days = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (days == 0) return 'Today';
      if (days == 1) return 'Tomorrow';
      return 'In $days days';
    }
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return 'Starting now';
    if (diff.inMinutes < 1) return 'In a moment';
    if (diff.inMinutes < 60) return 'Starts in ${diff.inMinutes}min';
    if (diff.inHours < 24) {
      final m = diff.inMinutes % 60;
      return m == 0
          ? 'Starts in ${diff.inHours}h'
          : 'Starts in ${diff.inHours}h ${m}min';
    }
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    return 'In ${(diff.inDays / 7).floor()} weeks';
  }

  String? get _address {
    if (customer != null) {
      final f = customer!.formattedAddress;
      if (f != null && f.isNotEmpty) return f;
      final a = customer!.address;
      if (a.isNotEmpty) return a;
    }
    final loc = entry.location;
    if (loc != null && loc.isNotEmpty) return loc;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = (customer?.phone ?? '').isNotEmpty;
    final hasEmail = (customer?.email ?? '').isNotEmpty;
    final hasContact = hasPhone || hasEmail;

    final canDirections = _address != null ||
        (customer?.latitude != null && customer?.longitude != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current & Upcoming Activity',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: (_) => _openEdit(),
          onLongPressCancel: _onLongPressEnd,
          child: ScaleTransition(
            scale: _ctrl,
            child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _brandTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _startsIn,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _brand,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title.isEmpty ? 'Scheduled entry' : entry.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((customer?.name ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.user,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        customer!.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (_address != null) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.mapPin,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.phone,
                      label: 'Contact',
                      enabled: hasContact,
                      onTap: () => _showContactSheet(
                        context,
                        hasPhone: hasPhone,
                        hasEmail: hasEmail,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.navigation,
                      label: 'Directions',
                      enabled: canDirections,
                      onTap: () => _showDirectionsSheet(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        ),
      ],
    );
  }

  // ---------- action sheets ----------

  Future<void> _showContactSheet(
    BuildContext context, {
    required bool hasPhone,
    required bool hasEmail,
  }) async {
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Contact'),
          actions: [
            if (hasPhone)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _call();
                },
                child: const Text('Call'),
              ),
            if (hasEmail)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showEmailSheet(context);
                },
                child: const Text('Email'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _materialSheet(context, [
      if (hasPhone)
        _SheetItem(LucideIcons.phone, 'Call', () {
          _call();
        }),
      if (hasEmail)
        _SheetItem(LucideIcons.mail, 'Email', () {
          _showEmailSheet(context);
        }),
    ]);
  }

  Future<void> _showEmailSheet(BuildContext context) async {
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Send email via'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _emailGmail();
              },
              child: const Text('Gmail'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _emailDefault();
              },
              child: const Text('Mail'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _materialSheet(context, [
      _SheetItem(LucideIcons.mail, 'Gmail', _emailGmail),
      _SheetItem(LucideIcons.mail, 'Default Mail', _emailDefault),
    ]);
  }

  Future<void> _showDirectionsSheet(BuildContext context) async {
    // Apple Maps doesn't exist on Android — go straight to Google Maps.
    if (Platform.isAndroid) {
      await _openGoogleMaps();
      return;
    }
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Get directions'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(c).pop();
                _openAppleMaps();
              },
              child: const Text('Apple Maps'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(c).pop();
                _openGoogleMaps();
              },
              child: const Text('Google Maps'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _openGoogleMaps();
  }

  Future<void> _materialSheet(
    BuildContext context,
    List<_SheetItem> items,
  ) async {
    if (items.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final it in items)
              ListTile(
                leading: Icon(it.icon, color: _brand),
                title: Text(it.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  it.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------- launchers ----------

  Future<void> _call() async {
    final phone = customer?.phone.trim();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _emailDefault() async {
    final to = customer?.email.trim();
    if (to == null || to.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: to);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _emailGmail() async {
    final to = customer?.email.trim();
    if (to == null || to.isEmpty) return;
    // iOS Gmail app deep link. Falls back to default mail if Gmail isn't
    // installed (launchUrl will throw → we catch and mailto).
    final gmail = Uri.parse('googlegmail:///co?to=$to');
    try {
      final ok = await launchUrl(gmail, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await _emailDefault();
  }

  Future<void> _openAppleMaps() async {
    final dest = _directionsQuery();
    if (dest == null) return;
    final uri = Uri(
      scheme: 'http',
      host: 'maps.apple.com',
      queryParameters: {'daddr': dest},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openGoogleMaps() async {
    final dest = _directionsQuery();
    if (dest == null) return;
    final uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: {'api': '1', 'destination': dest},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _directionsQuery() {
    final a = _address;
    if (a != null && a.isNotEmpty) return a;
    final lat = customer?.latitude;
    final lng = customer?.longitude;
    if (lat != null && lng != null) return '$lat,$lng';
    return null;
  }
}

class _SheetItem {
  _SheetItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShadButton.secondary(
      onPressed: enabled ? onTap : null,
      enabled: enabled,
      size: ShadButtonSize.sm,
      leading: Icon(icon, size: 14),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Wraps [LearnBanner] with the home-page chrome (white background,
/// horizontal padding) so it slots cleanly under Quick actions.
class _HomeLearnBanner extends StatelessWidget {
  const _HomeLearnBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: LearnBanner(
        imageAsset: 'assets/images/banner/youtube_banner.png',
        title: 'Learn Fix It Felix Faster',
        body: 'Watch quick tutorials, real job workflows, and pro '
            'tips to manage customers, quotes, invoices, and daily '
            'trade work like a professional.',
        url: ConfigService().youtubeChannelUrl,
        webviewTitle: 'YouTube',
      ),
    );
  }
}

/// Same chrome as [_HomeLearnBanner] — sits directly underneath it on
/// the tradesman home and opens the system share sheet so the user
/// can invite friends/teammates.
class _HomeLeadsBanner extends StatelessWidget {
  const _HomeLeadsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const LeadsBanner(),
    );
  }
}

class _HomeShareBanner extends StatelessWidget {
  const _HomeShareBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: const ShareBanner(
        imageAsset: 'assets/images/banner/share_message.jpg',
        title: 'Invite Friends to Fix It Felix',
        body: 'Share Fix It Felix with your friends and team to manage '
            'jobs, quotes, invoices, customers, staff, and daily '
            'trade work together.',
        shareSubject: 'Try Fix It Felix',
        shareText: 'Hey 👋\n'
            'Check out Fix It Felix — the smart app for tradespeople '
            'to manage jobs, quotes, invoices, customers, and staff.\n'
            '\n'
            'Share with your friends and join us:\n'
            'fixitfelixsoftwaresolutions.com',
      ),
    );
  }
}

