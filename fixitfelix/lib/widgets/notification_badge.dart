import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/notifications/notifications_bloc.dart';
import '../blocs/notifications/notifications_state.dart';

/// Wraps [child] (typically an IconButton) and overlays a small red
/// counter in the top-right when unread notifications > 0.
///
/// Pass [count] explicitly to drive the badge from something other than
/// the NotificationsBloc (e.g. unread-messages).
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key, required this.child, this.count});

  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (count != null) {
      return _buildStack(count!, child);
    }
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (a, b) => a.unreadCount != b.unreadCount,
      builder: (context, state) => _buildStack(state.unreadCount, child),
    );
  }

  Widget _buildStack(int n, Widget child) {
    if (n <= 0) return child;
    final label = n > 99 ? '99+' : '$n';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
