import 'package:equatable/equatable.dart';

/// Enum representing the status of a login session
enum SessionStatus {
  /// Session is currently active and in use
  active,

  /// Session is temporarily inactive (app in background/closed)
  inactive,

  /// Session has expired due to timeout
  expired,

  /// User manually logged out
  loggedOut,

  /// User was forced to logout (another device login)
  forcedLogout,
}

/// Extension for SessionStatus enum
extension SessionStatusExtension on SessionStatus {
  String get value {
    switch (this) {
      case SessionStatus.active:
        return 'active';
      case SessionStatus.inactive:
        return 'inactive';
      case SessionStatus.expired:
        return 'expired';
      case SessionStatus.loggedOut:
        return 'loggedOut';
      case SessionStatus.forcedLogout:
        return 'forcedLogout';
    }
  }

  static SessionStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return SessionStatus.active;
      case 'inactive':
        return SessionStatus.inactive;
      case 'expired':
        return SessionStatus.expired;
      case 'loggedOut':
        return SessionStatus.loggedOut;
      case 'forcedLogout':
        return SessionStatus.forcedLogout;
      default:
        return SessionStatus.active;
    }
  }

  /// Check if session is still valid (can be resumed)
  bool get isValid =>
      this == SessionStatus.active || this == SessionStatus.inactive;

  /// Check if session has ended
  bool get hasEnded =>
      this == SessionStatus.loggedOut ||
      this == SessionStatus.forcedLogout ||
      this == SessionStatus.expired;
}

/// Model representing a user login session
class LoginSessionModel extends Equatable {
  /// Unique session identifier
  final String sessionId;

  /// User ID associated with this session
  final String userId;

  /// Device ID where the session is active
  final String deviceId;

  /// FCM token for this session
  final String? fcmToken;

  /// Session status
  final SessionStatus status;

  /// IP address at login (if available)
  final String? ipAddress;

  /// User agent / device info string
  final String? userAgent;

  /// Login method (email, google, apple, phone)
  final String loginMethod;

  /// Platform (ios, android, web)
  final String platform;

  /// Device model
  final String? deviceModel;

  /// App version at login
  final String appVersion;

  /// Session creation time (login time)
  final DateTime loginAt;

  /// Last activity time
  final DateTime lastActivityAt;

  /// Session end time (logout time)
  final DateTime? logoutAt;

  /// Location at login (city, country)
  final String? loginLocation;

  const LoginSessionModel({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    this.fcmToken,
    this.status = SessionStatus.active,
    this.ipAddress,
    this.userAgent,
    required this.loginMethod,
    required this.platform,
    this.deviceModel,
    required this.appVersion,
    required this.loginAt,
    required this.lastActivityAt,
    this.logoutAt,
    this.loginLocation,
  });

  /// Check if session is currently active
  bool get isActive => status == SessionStatus.active;

  /// Get session duration
  Duration get sessionDuration {
    final endTime = logoutAt ?? DateTime.now();
    return endTime.difference(loginAt);
  }

  /// Create from JSON map (Firebase)
  factory LoginSessionModel.fromJson(Map<String, dynamic> json) {
    return LoginSessionModel(
      sessionId: json['sessionId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      fcmToken: json['fcmToken'] as String?,
      status: SessionStatusExtension.fromString(json['status'] as String?),
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      loginMethod: json['loginMethod'] as String? ?? 'unknown',
      platform: json['platform'] as String? ?? 'unknown',
      deviceModel: json['deviceModel'] as String?,
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      loginAt: json['loginAt'] != null
          ? DateTime.parse(json['loginAt'] as String)
          : DateTime.now(),
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'] as String)
          : DateTime.now(),
      logoutAt: json['logoutAt'] != null
          ? DateTime.parse(json['logoutAt'] as String)
          : null,
      loginLocation: json['loginLocation'] as String?,
    );
  }

  /// Convert to JSON map for Firebase
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'status': status.value,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'loginMethod': loginMethod,
      'platform': platform,
      'deviceModel': deviceModel,
      'appVersion': appVersion,
      'loginAt': loginAt.toIso8601String(),
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'logoutAt': logoutAt?.toIso8601String(),
      'loginLocation': loginLocation,
    };
  }

  /// Create a copy with updated fields
  LoginSessionModel copyWith({
    String? sessionId,
    String? userId,
    String? deviceId,
    String? fcmToken,
    SessionStatus? status,
    String? ipAddress,
    String? userAgent,
    String? loginMethod,
    String? platform,
    String? deviceModel,
    String? appVersion,
    DateTime? loginAt,
    DateTime? lastActivityAt,
    DateTime? logoutAt,
    String? loginLocation,
  }) {
    return LoginSessionModel(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      fcmToken: fcmToken ?? this.fcmToken,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      loginMethod: loginMethod ?? this.loginMethod,
      platform: platform ?? this.platform,
      deviceModel: deviceModel ?? this.deviceModel,
      appVersion: appVersion ?? this.appVersion,
      loginAt: loginAt ?? this.loginAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      logoutAt: logoutAt ?? this.logoutAt,
      loginLocation: loginLocation ?? this.loginLocation,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    userId,
    deviceId,
    fcmToken,
    status,
    ipAddress,
    userAgent,
    loginMethod,
    platform,
    deviceModel,
    appVersion,
    loginAt,
    lastActivityAt,
    logoutAt,
    loginLocation,
  ];

  @override
  String toString() {
    return 'LoginSessionModel(sessionId: $sessionId, userId: $userId, deviceId: $deviceId, status: $status)';
  }
}
