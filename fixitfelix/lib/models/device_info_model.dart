import 'package:equatable/equatable.dart';

/// Model representing device information for tracking and session management
class DeviceInfoModel extends Equatable {
  /// Unique device identifier (hash of FCM token or device ID)
  final String deviceId;

  /// Firebase Cloud Messaging token for push notifications
  final String? fcmToken;

  /// Device platform (ios, android, web)
  final String platform;

  /// Operating system version (e.g., "iOS 17.0", "Android 14")
  final String osVersion;

  /// Device model (e.g., "iPhone 15 Pro", "Samsung Galaxy S24")
  final String deviceModel;

  /// Device manufacturer (e.g., "Apple", "Samsung")
  final String? manufacturer;

  /// App version (e.g., "1.0.0")
  final String appVersion;

  /// App build number (e.g., "1")
  final String? buildNumber;

  /// Device screen width in pixels
  final double? screenWidth;

  /// Device screen height in pixels
  final double? screenHeight;

  /// Device locale (e.g., "en_US")
  final String? locale;

  /// Device timezone (e.g., "America/New_York")
  final String? timezone;

  /// Whether the device is a physical device or emulator/simulator
  final bool isPhysicalDevice;

  /// First time this device was registered
  final DateTime createdAt;

  /// Last time device info was updated
  final DateTime updatedAt;

  /// Last time the app was opened on this device
  final DateTime? lastActiveAt;

  /// Whether this device is currently active (user logged in)
  final bool isActive;

  const DeviceInfoModel({
    required this.deviceId,
    this.fcmToken,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    this.manufacturer,
    required this.appVersion,
    this.buildNumber,
    this.screenWidth,
    this.screenHeight,
    this.locale,
    this.timezone,
    this.isPhysicalDevice = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
    this.isActive = true,
  });

  /// Create from JSON map (Firebase)
  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      deviceId: json['deviceId'] as String? ?? '',
      fcmToken: json['fcmToken'] as String?,
      platform: json['platform'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String? ?? 'unknown',
      deviceModel: json['deviceModel'] as String? ?? 'unknown',
      manufacturer: json['manufacturer'] as String?,
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      buildNumber: json['buildNumber'] as String?,
      screenWidth: (json['screenWidth'] as num?)?.toDouble(),
      screenHeight: (json['screenHeight'] as num?)?.toDouble(),
      locale: json['locale'] as String?,
      timezone: json['timezone'] as String?,
      isPhysicalDevice: json['isPhysicalDevice'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Convert to JSON map for Firebase
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'platform': platform,
      'osVersion': osVersion,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'locale': locale,
      'timezone': timezone,
      'isPhysicalDevice': isPhysicalDevice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Create a copy with updated fields
  DeviceInfoModel copyWith({
    String? deviceId,
    String? fcmToken,
    String? platform,
    String? osVersion,
    String? deviceModel,
    String? manufacturer,
    String? appVersion,
    String? buildNumber,
    double? screenWidth,
    double? screenHeight,
    String? locale,
    String? timezone,
    bool? isPhysicalDevice,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
    bool? isActive,
  }) {
    return DeviceInfoModel(
      deviceId: deviceId ?? this.deviceId,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      screenWidth: screenWidth ?? this.screenWidth,
      screenHeight: screenHeight ?? this.screenHeight,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      isPhysicalDevice: isPhysicalDevice ?? this.isPhysicalDevice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    fcmToken,
    platform,
    osVersion,
    deviceModel,
    manufacturer,
    appVersion,
    buildNumber,
    screenWidth,
    screenHeight,
    locale,
    timezone,
    isPhysicalDevice,
    createdAt,
    updatedAt,
    lastActiveAt,
    isActive,
  ];

  @override
  String toString() {
    return 'DeviceInfoModel(deviceId: $deviceId, platform: $platform, model: $deviceModel, appVersion: $appVersion)';
  }
}
