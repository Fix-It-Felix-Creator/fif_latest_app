import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/services/supabase_service.dart';
import 'device_mapper.dart';
import '../../models/device_info_model.dart';
import '../../models/login_session_model.dart';
import 'base_device_info_repository.dart';

/// Repository for managing device information and login sessions
class DeviceInfoRepository implements BaseDeviceInfoRepository {
  // Singleton pattern
  static final DeviceInfoRepository _instance =
      DeviceInfoRepository._internal();

  factory DeviceInfoRepository() => _instance;

  DeviceInfoRepository._internal()
    :       _messaging = FirebaseMessaging.instance,
      _deviceInfoPlugin = DeviceInfoPlugin();
  final FirebaseMessaging _messaging;
  final DeviceInfoPlugin _deviceInfoPlugin;

  // Cached values
  DeviceInfoModel? _cachedDeviceInfo;
  String? _currentSessionId;
  PackageInfo? _packageInfo;

  // Force logout listener
  StreamSubscription? _forceLogoutSubscription;

  /// Callback when device is force logged out from another device
  /// Set this to handle force logout (e.g., sign out user and navigate to login)
  static void Function(String reason)? onForceLogout;

  /// Get current user ID
  String? get _userId => SupabaseService().auth.currentUser?.id;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  // ============================================
  // Device Information Methods
  // ============================================

  /// Collect current device information
  Future<DeviceInfoModel> collectDeviceInfo() async {
    try {
      // Get package info
      _packageInfo ??= await PackageInfo.fromPlatform();

      // Get FCM token
      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }

      // Generate device ID from FCM token or create a unique one
      final deviceId = _generateDeviceId(fcmToken);

      // Get platform-specific device info
      String platform;
      String osVersion;
      String deviceModel;
      String? manufacturer;
      bool isPhysicalDevice = true;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        platform = 'android';
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        deviceModel = androidInfo.model;
        manufacturer = androidInfo.manufacturer;
        isPhysicalDevice = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        platform = 'ios';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        deviceModel = iosInfo.model;
        manufacturer = 'Apple';
        isPhysicalDevice = iosInfo.isPhysicalDevice;
      } else {
        platform = 'unknown';
        osVersion = Platform.operatingSystemVersion;
        deviceModel = 'Unknown Device';
      }

      // Get screen dimensions
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final screenWidth = window.physicalSize.width / window.devicePixelRatio;
      final screenHeight = window.physicalSize.height / window.devicePixelRatio;

      // Get locale and timezone
      final locale = Platform.localeName;
      final timezone = DateTime.now().timeZoneName;

      final now = DateTime.now();

      _cachedDeviceInfo = DeviceInfoModel(
        deviceId: deviceId,
        fcmToken: fcmToken,
        platform: platform,
        osVersion: osVersion,
        deviceModel: deviceModel,
        manufacturer: manufacturer,
        appVersion: _packageInfo!.version,
        buildNumber: _packageInfo!.buildNumber,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        locale: locale,
        timezone: timezone,
        isPhysicalDevice: isPhysicalDevice,
        createdAt: now,
        updatedAt: now,
        lastActiveAt: now,
        isActive: true,
      );

      return _cachedDeviceInfo!;
    } catch (e) {
      debugPrint('Error collecting device info: $e');
      rethrow;
    }
  }

  /// Generate a unique device ID
  String _generateDeviceId(String? fcmToken) {
    if (fcmToken != null && fcmToken.isNotEmpty) {
      return fcmToken.hashCode.abs().toString();
    }
    // Fallback: generate from timestamp and random
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get cached device info or collect new
  Future<DeviceInfoModel> getDeviceInfo() async {
    _cachedDeviceInfo ??= await collectDeviceInfo();
    return _cachedDeviceInfo!;
  }

  /// Save or update device info to database
  Future<void> saveDeviceInfo({DeviceInfoModel? deviceInfo}) async {
    final uid = _userId;
    if (uid == null) {
      debugPrint('DeviceInfoRepository: No user logged in');
      return;
    }

    try {
      final info = deviceInfo ?? await getDeviceInfo();
      final client = SupabaseService().client;

      final existingRow = await client
          .from('user_devices')
          .select()
          .eq('owner_id', uid)
          .eq('device_id', info.deviceId)
          .maybeSingle();

      if (existingRow != null) {
        final existingDevice = DeviceInfoModel.fromJson(
          DeviceMapper.deviceToJson(Map<String, dynamic>.from(existingRow)),
        );

        // Check if info has changed
        if (_hasDeviceInfoChanged(existingDevice, info)) {
          final updatedInfo = info.copyWith(
            createdAt: existingDevice.createdAt,
            updatedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          );
          await client
              .from('user_devices')
              .update(DeviceMapper.deviceToRow(updatedInfo.toJson(), uid))
              .eq('owner_id', uid)
              .eq('device_id', info.deviceId);
          debugPrint('DeviceInfoRepository: Device info updated');
        } else {
          // Just update last active time
          await client
              .from('user_devices')
              .update({
                'last_active_at': DateTime.now().toUtc().toIso8601String(),
                'is_active': true,
              })
              .eq('owner_id', uid)
              .eq('device_id', info.deviceId);
          debugPrint('DeviceInfoRepository: Device last active time updated');
        }
      } else {
        // Save new device info
        await client
            .from('user_devices')
            .insert(DeviceMapper.deviceToRow(info.toJson(), uid));
        debugPrint('DeviceInfoRepository: New device info saved');
      }

      _cachedDeviceInfo = info;
    } catch (e) {
      debugPrint('Error saving device info: $e');
    }
  }

  /// Check if device info has changed
  bool _hasDeviceInfoChanged(
    DeviceInfoModel existing,
    DeviceInfoModel current,
  ) {
    return existing.fcmToken != current.fcmToken ||
        existing.osVersion != current.osVersion ||
        existing.appVersion != current.appVersion ||
        existing.locale != current.locale;
  }

  /// Get all devices for current user
  Future<List<DeviceInfoModel>> getUserDevices() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final rows = await SupabaseService()
          .client
          .from('user_devices')
          .select()
          .eq('owner_id', uid);

      final devices = List<Map<String, dynamic>>.from(rows)
          .map((r) => DeviceInfoModel.fromJson(DeviceMapper.deviceToJson(r)))
          .toList();

      // Sort by last active time (newest first)
      devices.sort(
        (a, b) => (b.lastActiveAt ?? b.updatedAt).compareTo(
          a.lastActiveAt ?? a.updatedAt,
        ),
      );

      return devices;
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return [];
    }
  }

  /// Mark device as inactive
  Future<void> markDeviceInactive(String deviceId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await SupabaseService()
          .client
          .from('user_devices')
          .update({'is_active': false})
          .eq('owner_id', uid)
          .eq('device_id', deviceId);
    } catch (e) {
      debugPrint('Error marking device inactive: $e');
    }
  }

  /// Remove device from database
  Future<void> removeDevice(String deviceId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await SupabaseService()
          .client
          .from('user_devices')
          .delete()
          .eq('owner_id', uid)
          .eq('device_id', deviceId);
      debugPrint('DeviceInfoRepository: Device removed');
    } catch (e) {
      debugPrint('Error removing device: $e');
    }
  }

  // ============================================
  // Login Session Methods
  // ============================================

  /// Create a new login session
  /// Uses deviceId as sessionId to ensure ONE device = ONE session
  Future<LoginSessionModel?> createLoginSession({
    required String loginMethod,
    String? ipAddress,
    String? loginLocation,
  }) async {
    final uid = _userId;
    if (uid == null) {
      debugPrint('DeviceInfoRepository: No user logged in');
      return null;
    }

    try {
      final deviceInfo = await getDeviceInfo();
      final now = DateTime.now();

      // Use deviceId as sessionId - ensures one device = one session
      final sessionId = deviceInfo.deviceId;

      final session = LoginSessionModel(
        sessionId: sessionId,
        userId: uid,
        deviceId: deviceInfo.deviceId,
        fcmToken: deviceInfo.fcmToken,
        status: SessionStatus.active,
        ipAddress: ipAddress,
        loginMethod: loginMethod,
        platform: deviceInfo.platform,
        deviceModel: deviceInfo.deviceModel,
        appVersion: deviceInfo.appVersion,
        loginAt: now,
        lastActivityAt: now,
        loginLocation: loginLocation,
      );

      // Save session (overwrites any existing session for this device).
      // `(owner_id, session_id)` is unique, so this is an upsert.
      await SupabaseService().client.from('user_sessions').upsert(
            DeviceMapper.sessionToRow(session.toJson(), uid),
            onConflict: 'owner_id,session_id',
          );

      _currentSessionId = sessionId;
      debugPrint(
        'DeviceInfoRepository: Login session created/updated for device: $sessionId',
      );

      return session;
    } catch (e) {
      debugPrint('Error creating login session: $e');
      return null;
    }
  }

  /// Update session activity time and optionally update status
  Future<void> updateSessionActivity({SessionStatus? status}) async {
    final uid = _userId;
    if (uid == null || _currentSessionId == null) return;

    try {
      final updates = <String, dynamic>{
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (status != null) {
        updates['status'] = status.value;
      }

      await _updateSession(uid, _currentSessionId!, updates);
      debugPrint(
        'DeviceInfoRepository: Session activity updated${status != null ? " (status: ${status.value})" : ""}',
      );
    } catch (e) {
      debugPrint('Error updating session activity: $e');
    }
  }

  /// Set session status to active (when app comes to foreground)
  Future<void> setSessionActive() async {
    final uid = _userId;
    if (uid == null || _currentSessionId == null) return;

    try {
      final deviceInfo = await getDeviceInfo();

      await _updateSession(uid, _currentSessionId!, {
        'status': SessionStatus.active.value,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Also update device as active
      await SupabaseService()
          .client
          .from('user_devices')
          .update({
            'is_active': true,
            'last_active_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('owner_id', uid)
          .eq('device_id', deviceInfo.deviceId);

      debugPrint('DeviceInfoRepository: Session set to active');
    } catch (e) {
      debugPrint('Error setting session active: $e');
    }
  }

  /// Set session status to inactive (when app goes to background)
  Future<void> setSessionInactive() async {
    final uid = _userId;
    if (uid == null || _currentSessionId == null) return;

    try {
      await _updateSession(uid, _currentSessionId!, {
        'status': SessionStatus.inactive.value,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint('DeviceInfoRepository: Session set to inactive');
    } catch (e) {
      debugPrint('Error setting session inactive: $e');
    }
  }

  /// Get current session status
  Future<SessionStatus?> getCurrentSessionStatus() async {
    final uid = _userId;
    if (uid == null || _currentSessionId == null) return null;

    try {
      final row = await SupabaseService()
          .client
          .from('user_sessions')
          .select('status')
          .eq('owner_id', uid)
          .eq('session_id', _currentSessionId!)
          .maybeSingle();

      if (row != null) {
        return SessionStatusExtension.fromString(row['status'] as String?);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session status: $e');
      return null;
    }
  }

  /// Check if current session is still valid
  Future<bool> isSessionValid() async {
    final status = await getCurrentSessionStatus();
    return status?.isValid ?? false;
  }

  /// End login session (on logout)
  Future<void> endLoginSession({
    SessionStatus status = SessionStatus.loggedOut,
  }) async {
    final uid = _userId;
    if (uid == null || _currentSessionId == null) return;

    try {
      final now = DateTime.now();

      // RTDB kept two nodes and physically MOVED the record from
      // `sessions/{uid}/{id}` into `sessions/{uid}/history/{id}` on logout.
      // One table with a `status` column expresses the same thing, so ending a
      // session is an update rather than a copy-then-delete — which also means
      // a crash between the two steps can no longer lose the record.
      final updated = await _updateSession(uid, _currentSessionId!, {
        'status': status.value,
        'logout_at': now.toUtc().toIso8601String(),
        'last_activity_at': now.toUtc().toIso8601String(),
      });

      if (updated) {
        debugPrint('DeviceInfoRepository: Login session ended');
      }

      // Mark device as inactive
      final deviceInfo = await getDeviceInfo();
      await markDeviceInactive(deviceInfo.deviceId);

      _currentSessionId = null;
    } catch (e) {
      debugPrint('Error ending login session: $e');
    }
  }

  /// Updates one session row. Returns false when no row matched.
  ///
  /// Every session mutation goes through here so the owner_id + session_id
  /// scoping is written once rather than at a dozen call sites.
  Future<bool> _updateSession(
    String uid,
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final rows = await SupabaseService()
          .client
          .from('user_sessions')
          .update(updates)
          .eq('owner_id', uid)
          .eq('session_id', sessionId)
          .select('session_id');
      return List<Map<String, dynamic>>.from(rows).isNotEmpty;
    } catch (e) {
      debugPrint('DeviceInfoRepository._updateSession failed: $e');
      return false;
    }
  }

  /// Get all valid sessions for current user (active and inactive)
  /// Set [activeOnly] to true to only get active sessions
  Future<List<LoginSessionModel>> getActiveSessions({
    bool activeOnly = false,
  }) async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final rows = await SupabaseService()
          .client
          .from('user_sessions')
          .select()
          .eq('owner_id', uid);

      final sessions = <LoginSessionModel>[];
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final session =
            LoginSessionModel.fromJson(DeviceMapper.sessionToJson(r));
        // Check if session is valid (active or inactive)
        if (activeOnly) {
          if (session.status == SessionStatus.active) {
            sessions.add(session);
          }
        } else {
          // Include both active and inactive sessions
          if (session.status.isValid) {
            sessions.add(session);
          }
        }
      }

      // Sort by login time (newest first)
      sessions.sort((a, b) => b.loginAt.compareTo(a.loginAt));

      return sessions;
    } catch (e) {
      debugPrint('Error getting active sessions: $e');
      return [];
    }
  }

  /// Get session history for current user
  Future<List<LoginSessionModel>> getSessionHistory({int limit = 20}) async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      // History is no longer a separate node: an ended session is one whose
      // status is no longer valid, so it is selected rather than moved.
      final rows = await SupabaseService()
          .client
          .from('user_sessions')
          .select()
          .eq('owner_id', uid)
          .not('logout_at', 'is', null)
          .order('login_at', ascending: false)
          .limit(limit);

      final sessions = List<Map<String, dynamic>>.from(rows)
          .map((r) => LoginSessionModel.fromJson(DeviceMapper.sessionToJson(r)))
          .toList();

      // Sort by login time (newest first)
      sessions.sort((a, b) => b.loginAt.compareTo(a.loginAt));

      return sessions;
    } catch (e) {
      debugPrint('Error getting session history: $e');
      return [];
    }
  }

  /// Force logout a specific session (from another device)
  Future<void> forceLogoutSession(String sessionId) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final row = await SupabaseService()
          .client
          .from('user_sessions')
          .select()
          .eq('owner_id', uid)
          .eq('session_id', sessionId)
          .maybeSingle();

      if (row != null) {
        final session = LoginSessionModel.fromJson(
          DeviceMapper.sessionToJson(Map<String, dynamic>.from(row)),
        );

        // Status change, not a move between nodes — see endLoginSession.
        await _updateSession(uid, sessionId, {
          'status': SessionStatus.forcedLogout.value,
          'logout_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Mark device as inactive
        await markDeviceInactive(session.deviceId);

        debugPrint('DeviceInfoRepository: Session force logged out');
      }
    } catch (e) {
      debugPrint('Error force logging out session: $e');
    }
  }

  /// Force logout all other sessions except current
  Future<void> forceLogoutAllOtherSessions() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final sessions = await getActiveSessions();

      for (final session in sessions) {
        if (session.sessionId != _currentSessionId) {
          await forceLogoutSession(session.sessionId);
        }
      }

      debugPrint('DeviceInfoRepository: All other sessions logged out');
    } catch (e) {
      debugPrint('Error logging out other sessions: $e');
    }
  }

  // ============================================
  // Combined Operations
  // ============================================

  /// Called when user logs in - saves device info and creates session
  /// Implements SINGLE DEVICE LOGIN - all other sessions are forced to logout
  Future<void> onUserLogin({
    required String loginMethod,
    String? ipAddress,
    String? loginLocation,
  }) async {
    // Save/update device info and clear any force logout flags
    await saveDeviceInfo();
    await _clearForceLogoutFlag();

    // Force logout all other sessions (single device login)
    await _forceLogoutAllOtherDevices();

    // Create login session
    await createLoginSession(
      loginMethod: loginMethod,
      ipAddress: ipAddress,
      loginLocation: loginLocation,
    );

    // Start listening for force logout from other devices
    await startForceLogoutListener();
  }

  /// Clear force logout flag for current device (called on login)
  Future<void> _clearForceLogoutFlag() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final deviceInfo = await getDeviceInfo();
      await SupabaseService()
          .client
          .from('user_devices')
          .update({
            'force_logout_at': null,
            'force_logout_reason': null,
            'is_active': true,
          })
          .eq('owner_id', uid)
          .eq('device_id', deviceInfo.deviceId);
      debugPrint(
        'DeviceInfoRepository: Cleared force logout flag for current device',
      );
    } catch (e) {
      debugPrint('Error clearing force logout flag: $e');
    }
  }

  /// Force logout all other devices and clear their FCM tokens
  /// This ensures only one device can be logged in at a time
  Future<void> _forceLogoutAllOtherDevices() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final deviceInfo = await getDeviceInfo();
      final currentDeviceId = deviceInfo.deviceId;

      // Get all sessions
      final sessions = await getActiveSessions();

      for (final session in sessions) {
        // Skip current device
        if (session.deviceId == currentDeviceId) continue;

        // Force logout the session
        await forceLogoutSession(session.sessionId);

        debugPrint(
          'DeviceInfoRepository: Forced logout device ${session.deviceId}',
        );
      }

      // Also clear FCM tokens from all other devices.
      //
      // One statement with `neq` instead of read-all-then-loop: the old code
      // issued a write per device, so a failure partway left some devices
      // logged out and others not.
      await SupabaseService()
          .client
          .from('user_devices')
          .update({
            'fcm_token': null,
            'is_active': false,
            'force_logout_at': DateTime.now().toUtc().toIso8601String(),
            'force_logout_reason': 'New device login',
          })
          .eq('owner_id', uid)
          .neq('device_id', currentDeviceId);

      debugPrint('DeviceInfoRepository: Cleared FCM tokens on other devices');

      debugPrint(
        'DeviceInfoRepository: Single device login enforced - all other devices logged out',
      );
    } catch (e) {
      debugPrint('Error forcing logout other devices: $e');
    }
  }

  /// Called when user logs out
  Future<void> onUserLogout() async {
    // Stop listening for force logout
    stopForceLogoutListener();
    await endLoginSession();
  }

  // Track when listener started to avoid false positives
  DateTime? _listenerStartTime;
  bool _initialLoadComplete = false;

  /// Start listening for force logout on the current device
  /// This detects when another device logs in and forces this device to logout
  Future<void> startForceLogoutListener() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final deviceInfo = await getDeviceInfo();

      debugPrint(
        'DeviceInfoRepository: Starting force logout listener for '
        'device ${deviceInfo.deviceId}',
      );

      // Cancel any existing subscription
      await _forceLogoutSubscription?.cancel();

      // Record when we started listening
      _listenerStartTime = DateTime.now();
      _initialLoadComplete = false;

      // Listen for changes to the device record
      _forceLogoutSubscription = SupabaseService()
          .client
          .from('user_devices')
          .stream(primaryKey: const ['owner_id', 'device_id'])
          .eq('owner_id', uid)
          .listen(
            (rows) {
              final match = rows.where(
                (r) => r['device_id'] == deviceInfo.deviceId,
              );
              if (match.isEmpty) return;

              final data = DeviceMapper.deviceToJson(
                Map<String, dynamic>.from(match.first),
              )..addAll({
                  'forceLogoutAt': match.first['force_logout_at'],
                  'forceLogoutReason': match.first['force_logout_reason'],
                });

              // Skip the initial load (first event after subscribing)
              if (!_initialLoadComplete) {
                _initialLoadComplete = true;
                debugPrint(
                  'DeviceInfoRepository: Initial device state loaded, now watching for changes',
                );
                return;
              }

              // Check if device was force logged out
              final forceLogoutAtStr = data['forceLogoutAt'] as String?;
              final isActive = data['isActive'] as bool? ?? true;
              final forceLogoutReason =
                  data['forceLogoutReason'] as String? ??
                  'Logged in from another device';

              // Only trigger if forceLogoutAt is set and is after we started listening
              if (forceLogoutAtStr != null && _listenerStartTime != null) {
                final forceLogoutAt = DateTime.tryParse(forceLogoutAtStr);
                if (forceLogoutAt != null &&
                    forceLogoutAt.isAfter(_listenerStartTime!)) {
                  debugPrint('DeviceInfoRepository: Force logout detected!');
                  debugPrint(
                    'DeviceInfoRepository: Reason: $forceLogoutReason',
                  );

                  // Stop listening
                  stopForceLogoutListener();

                  // Call the callback
                  if (onForceLogout != null) {
                    onForceLogout!(forceLogoutReason);
                  }
                  return;
                }
              }

              // Also check if isActive was explicitly set to false after listener started
              if (isActive == false && _initialLoadComplete) {
                debugPrint(
                  'DeviceInfoRepository: Device marked inactive - force logout',
                );
                debugPrint('DeviceInfoRepository: Reason: $forceLogoutReason');

                // Stop listening
                stopForceLogoutListener();

                // Call the callback
                if (onForceLogout != null) {
                  onForceLogout!(forceLogoutReason);
                }
              }
            },
            onError: (error) {
              debugPrint(
                'DeviceInfoRepository: Force logout listener error: $error',
              );
            },
          );

      debugPrint('DeviceInfoRepository: Force logout listener started');
    } catch (e) {
      debugPrint('Error starting force logout listener: $e');
    }
  }

  /// Stop listening for force logout
  void stopForceLogoutListener() {
    _forceLogoutSubscription?.cancel();
    _forceLogoutSubscription = null;
    _listenerStartTime = null;
    _initialLoadComplete = false;
    debugPrint('DeviceInfoRepository: Force logout listener stopped');
  }

  /// Called when app opens (to update activity)
  Future<void> onAppOpened() async {
    final uid = _userId;
    if (uid == null) return;

    // Update device info if needed
    await saveDeviceInfo();

    // Update session activity if session exists
    if (_currentSessionId != null) {
      await updateSessionActivity();
    }
  }

  /// Clear cached data
  void clearCache() {
    _cachedDeviceInfo = null;
    _currentSessionId = null;
  }
}
