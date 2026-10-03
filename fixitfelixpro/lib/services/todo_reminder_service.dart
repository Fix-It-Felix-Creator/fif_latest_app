import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../globals.dart';

/// Channel / notification IDs kept outside the class so they survive hot
/// reload cleanly.
const _channelId = 'todo_daily_reminder';
const _channelName = 'To-Do Reminder';
const _channelDesc = 'Daily reminder to check your to-do list.';
const int _notificationId = 1001;

/// Schedules the user-configurable daily to-do reminder.
///
/// Uses `flutter_local_notifications` so the alert fires whether the app is
/// foregrounded, backgrounded, or terminated. The scheduling is inexact
/// (`inexactAllowWhileIdle`) which avoids the `SCHEDULE_EXACT_ALARM`
/// runtime permission on Android 12+; alerts still fire within minutes of
/// the requested time.
class TodoReminderService {
  TodoReminderService._();
  static final TodoReminderService instance = TodoReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> initialise() async {
    if (_initialised) return;

    tzdata.initializeTimeZones();
    // Best-effort local tz detection — fall back to UTC if plugin isn't
    // present. The scheduled time is still correct because `tz.TZDateTime`
    // from `tz.local` maps to the host's current offset.
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleTap,
    );

    // Create the Android channel up-front so imports / appearance changes
    // apply before the first scheduling call.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    _initialised = true;
  }

  /// Cancel the existing scheduled reminder (no-op if none).
  Future<void> cancel() async {
    if (!_initialised) await initialise();
    await _plugin.cancel(_notificationId);
  }

  /// Returns the currently scheduled reminder, or null if none is queued.
  /// Useful for showing a status line in settings.
  Future<PendingNotificationRequest?> pending() async {
    if (!_initialised) await initialise();
    final list = await _plugin.pendingNotificationRequests();
    for (final p in list) {
      if (p.id == _notificationId) return p;
    }
    return null;
  }

  /// Schedule (or re-schedule) the daily reminder at the given local time.
  /// Always clears any previously queued reminder first so there is only
  /// ever one scheduled notification under [_notificationId].
  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_initialised) await initialise();
    await _plugin.cancel(_notificationId);

    final first = _nextInstance(hour, minute);
    debugPrint('TodoReminderService: scheduling daily at $hour:$minute — first fire $first');

    await _plugin.zonedSchedule(
      _notificationId,
      title,
      body,
      first,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'todos',
    );
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var fire = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!fire.isAfter(now)) {
      fire = fire.add(const Duration(days: 1));
    }
    return fire;
  }

  static void _handleTap(NotificationResponse response) {
    final route = response.payload ?? '/todos';
    globalNavigatorKey.currentState?.pushNamed('/$route'.replaceAll('//', '/'));
  }
}
