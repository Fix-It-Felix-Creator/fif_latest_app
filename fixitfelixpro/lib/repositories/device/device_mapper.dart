/// Row mapping for `user_devices` and `user_sessions`.
///
/// Both models serialise to camelCase JSON; the tables are snake_case. As with
/// ProfileMapper and UsageMapper, the translation lives here so
/// DeviceInfoModel and LoginSessionModel stay untouched.
class DeviceMapper {
  const DeviceMapper._();

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> deviceToRow(
    Map<String, dynamic> json,
    String ownerId,
  ) =>
      {
        'owner_id': ownerId,
        'device_id': json['deviceId'],
        'fcm_token': json['fcmToken'],
        'platform': json['platform'],
        'os_version': json['osVersion'],
        'device_model': json['deviceModel'],
        'manufacturer': json['manufacturer'],
        'app_version': json['appVersion'],
        'build_number': json['buildNumber'],
        'screen_width': json['screenWidth'],
        'screen_height': json['screenHeight'],
        'locale': json['locale'],
        'timezone': json['timezone'],
        'is_physical_device': json['isPhysicalDevice'] ?? true,
        'is_active': json['isActive'] ?? true,
        if (json['lastActiveAt'] != null) 'last_active_at': json['lastActiveAt'],
      };

  static Map<String, dynamic> deviceToJson(Map<String, dynamic> row) => {
        'deviceId': row['device_id'],
        'fcmToken': row['fcm_token'],
        'platform': row['platform'],
        'osVersion': row['os_version'],
        'deviceModel': row['device_model'],
        'manufacturer': row['manufacturer'],
        'appVersion': row['app_version'],
        'buildNumber': row['build_number'],
        'screenWidth': row['screen_width'],
        'screenHeight': row['screen_height'],
        'locale': row['locale'],
        'timezone': row['timezone'],
        'isPhysicalDevice': row['is_physical_device'] ?? true,
        'isActive': row['is_active'] ?? true,
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
        'lastActiveAt': row['last_active_at'],
      };

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> sessionToRow(
    Map<String, dynamic> json,
    String ownerId,
  ) =>
      {
        'owner_id': ownerId,
        'session_id': json['sessionId'],
        'device_id': json['deviceId'],
        'fcm_token': json['fcmToken'],
        'status': json['status'],
        'ip_address': json['ipAddress'],
        'user_agent': json['userAgent'],
        'login_method': json['loginMethod'],
        'platform': json['platform'],
        'device_model': json['deviceModel'],
        'app_version': json['appVersion'],
        'login_at': json['loginAt'],
        'last_activity_at': json['lastActivityAt'],
        'logout_at': json['logoutAt'],
        // jsonb column: the model carries a free-form location string, so it
        // is wrapped rather than losing the value to a type mismatch.
        'login_location': json['loginLocation'] == null
            ? null
            : {'value': json['loginLocation']},
      };

  static Map<String, dynamic> sessionToJson(Map<String, dynamic> row) {
    final loc = row['login_location'];
    return {
      'sessionId': row['session_id'],
      'userId': row['owner_id'],
      'deviceId': row['device_id'],
      'fcmToken': row['fcm_token'],
      'status': row['status'],
      'ipAddress': row['ip_address'],
      'userAgent': row['user_agent'],
      'loginMethod': row['login_method'],
      'platform': row['platform'],
      'deviceModel': row['device_model'],
      'appVersion': row['app_version'],
      'loginAt': row['login_at'],
      'lastActivityAt': row['last_activity_at'],
      'logoutAt': row['logout_at'],
      'loginLocation': loc is Map ? loc['value'] : loc,
    };
  }
}
