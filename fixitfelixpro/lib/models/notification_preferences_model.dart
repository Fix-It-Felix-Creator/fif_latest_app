import 'package:equatable/equatable.dart';

/// Model for user notification preferences
///
/// Stores settings for push notifications, email notifications, and SMS notifications.
/// All notifications are enabled by default when a new account is created.
class NotificationPreferencesModel extends Equatable {
  /// Whether push notifications are enabled
  final bool pushEnabled;

  /// Whether email notifications are enabled
  final bool emailEnabled;

  /// Whether SMS notifications are enabled
  final bool smsEnabled;

  const NotificationPreferencesModel({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = true,
  });

  /// Create default preferences with all notifications enabled
  factory NotificationPreferencesModel.defaultEnabled() {
    return const NotificationPreferencesModel(
      pushEnabled: true,
      emailEnabled: true,
      smsEnabled: true,
    );
  }

  /// Create preferences with all notifications disabled
  factory NotificationPreferencesModel.allDisabled() {
    return const NotificationPreferencesModel(
      pushEnabled: false,
      emailEnabled: false,
      smsEnabled: false,
    );
  }

  NotificationPreferencesModel copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) {
    return NotificationPreferencesModel(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'smsEnabled': smsEnabled,
    };
  }

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NotificationPreferencesModel.defaultEnabled();
    }
    return NotificationPreferencesModel(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? true,
      smsEnabled: json['smsEnabled'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [pushEnabled, emailEnabled, smsEnabled];
}
