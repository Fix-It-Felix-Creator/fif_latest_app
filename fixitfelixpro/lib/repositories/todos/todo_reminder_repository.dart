import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences for the daily to-do reminder.
/// Persisted locally — lives in SharedPreferences, not Firebase.
class TodoReminderPrefs {
  const TodoReminderPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });

  final bool enabled;
  final int hour; // 0..23
  final int minute; // 0..59
  final String title;
  final String body;

  static const TodoReminderPrefs defaults = TodoReminderPrefs(
    enabled: false,
    hour: 21,
    minute: 0,
    title: 'Check your to-do list',
    body: "Don't forget to mark today's tasks as done.",
  );

  TodoReminderPrefs copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    String? title,
    String? body,
  }) {
    return TodoReminderPrefs(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
      };

  factory TodoReminderPrefs.fromJson(Map<String, dynamic> raw) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return TodoReminderPrefs(
      enabled: raw['enabled'] == true,
      hour: asInt(raw['hour'], defaults.hour).clamp(0, 23),
      minute: asInt(raw['minute'], defaults.minute).clamp(0, 59),
      title: (raw['title'] as String?)?.trim().isNotEmpty == true
          ? raw['title'] as String
          : defaults.title,
      body: (raw['body'] as String?)?.trim().isNotEmpty == true
          ? raw['body'] as String
          : defaults.body,
    );
  }
}

/// Local-only persistence for [TodoReminderPrefs] under SharedPreferences.
class TodoReminderRepository {
  static const _key = 'todo_reminder_prefs_v1';

  Future<TodoReminderPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return TodoReminderPrefs.defaults;
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return TodoReminderPrefs.fromJson(map);
      return TodoReminderPrefs.defaults;
    } catch (e) {
      debugPrint('TodoReminderRepository.load: $e');
      return TodoReminderPrefs.defaults;
    }
  }

  Future<bool> save(TodoReminderPrefs value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(_key, jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('TodoReminderRepository.save: $e');
      return false;
    }
  }
}
