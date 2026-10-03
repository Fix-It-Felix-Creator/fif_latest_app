import 'package:equatable/equatable.dart';

import '../../models/in_app_notification.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => const [];
}

/// Start the RTDB subscription for the signed-in user.
class NotificationsStartWatching extends NotificationsEvent {
  const NotificationsStartWatching();
}

/// Cancel the RTDB subscription (call on sign-out).
class NotificationsStopWatching extends NotificationsEvent {
  const NotificationsStopWatching();
}

/// Internal event fired when the stream emits a new list.
class NotificationsUpdated extends NotificationsEvent {
  const NotificationsUpdated(this.items);
  final List<InAppNotification> items;

  @override
  List<Object?> get props => [items];
}

class NotificationsMarkRead extends NotificationsEvent {
  const NotificationsMarkRead(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class NotificationsMarkAllRead extends NotificationsEvent {
  const NotificationsMarkAllRead();
}

class NotificationsClearOne extends NotificationsEvent {
  const NotificationsClearOne(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class NotificationsClearAll extends NotificationsEvent {
  const NotificationsClearAll();
}
