import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/notifications/notifications_bloc.dart';
import '../../blocs/notifications/notifications_event.dart';
import '../../blocs/notifications/notifications_state.dart';
import '../../models/in_app_notification.dart';
import 'notification_detail_screen.dart';

const _brand = Color(0xFFF64C13);

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            buildWhen: (a, b) =>
                a.hasUnread != b.hasUnread || a.items.length != b.items.length,
            builder: (context, state) {
              final bloc = context.read<NotificationsBloc>();
              return PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical),
                onSelected: (value) {
                  if (value == 'read_all') {
                    bloc.add(const NotificationsMarkAllRead());
                  } else if (value == 'clear_all') {
                    bloc.add(const NotificationsClearAll());
                  }
                },
                itemBuilder: (_) => [
                  if (state.hasUnread)
                    const PopupMenuItem(
                      value: 'read_all',
                      child: Text('Mark all as read'),
                    ),
                  if (state.items.isNotEmpty)
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Text('Clear all'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          final bloc = context.read<NotificationsBloc>();
          final entries = _buildEntries(state.items);
          return RefreshIndicator(
            color: _brand,
            onRefresh: () async {
              bloc.add(const NotificationsStartWatching());
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child:
                state.status == NotificationsStatus.loading &&
                    state.items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator(color: _brand)),
                    ],
                  )
                : state.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 120), _EmptyState()],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      if (e is _HeaderEntry) {
                        return _SectionHeader(label: e.label);
                      }
                      final tile = (e as _ItemEntry).item;
                      return _NotificationTile(item: tile);
                    },
                  ),
          );
        },
      ),
    );
  }

  List<_Entry> _buildEntries(List<InAppNotification> items) {
    final entries = <_Entry>[];
    String? currentLabel;
    for (final n in items) {
      final label = _dayLabel(n.createdAt);
      if (label != currentLabel) {
        entries.add(_HeaderEntry(label));
        currentLabel = label;
      }
      entries.add(_ItemEntry(n));
    }
    return entries;
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    return '${_weekday(that.weekday)}, ${_dayOrdinal(that.day)} ${_month(that.month)}${that.year == now.year ? '' : ' ${that.year}'}';
  }

  String _weekday(int w) => const [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][w];

  String _month(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];

  String _dayOrdinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }
}

sealed class _Entry {
  const _Entry();
}

class _HeaderEntry extends _Entry {
  const _HeaderEntry(this.label);
  final String label;
}

class _ItemEntry extends _Entry {
  const _ItemEntry(this.item);
  final InAppNotification item;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final divider = Expanded(
      child: Container(height: 1, color: Colors.grey.shade200),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          divider,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          divider,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.bellOff, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          'No notifications yet',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You\'re all caught up.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

bool _hasDetail(InAppNotification n) {
  if (n.body.length > 140) return true;
  final p = n.payload;
  if (p == null) return false;
  final img = p['imageUrl'] ?? p['image_url'] ?? p['image'];
  return img is String && img.isNotEmpty;
}

IconData _iconFor(String type) {
  final t = type.toLowerCase();
  if (t.contains('payment') ||
      t.contains('subscription') ||
      t.contains('renewal')) {
    return LucideIcons.creditCard;
  }
  if (t.contains('job') || t.contains('offer')) return LucideIcons.briefcase;
  if (t.contains('message') || t.contains('chat')) {
    return LucideIcons.messageSquare;
  }
  if (t.contains('staff') || t.contains('team') || t.contains('invitation')) {
    return LucideIcons.users;
  }
  if (t.contains('verified') ||
      t.contains('welcome') ||
      t.contains('milestone')) {
    return LucideIcons.circleCheck;
  }
  if (t.contains('announcement') || t.contains('promo')) {
    return LucideIcons.megaphone;
  }
  if (t.contains('tip') || t.contains('update') || t.contains('policy')) {
    return LucideIcons.info;
  }
  return LucideIcons.bell;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final InAppNotification item;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotificationsBloc>();
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (_) => bloc.add(NotificationsClearOne(item.id)),
      child: InkWell(
        onTap: () {
          if (!item.read) bloc.add(NotificationsMarkRead(item.id));
          // The pro app deep-links quote and invoice notifications straight
          // to those documents. Neither screen exists here, so such a
          // notification falls through to the detail view like any other —
          // the body still says what happened.
          if (_hasDetail(item)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationDetailScreen(notification: item),
              ),
            );
          }
        },
        child: Container(
              color: item.read ? Colors.white : const Color(0xFFFFF4EE),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  _iconFor(item.type),
                  size: 20,
                  color: Colors.grey.shade700,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_hasDetail(item)) ...[
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
