import '../../models/device_info_model.dart';
import '../../models/login_session_model.dart';

/// Abstract base class for device info repository operations
/// Defines the contract for device management and login session operations
abstract class BaseDeviceInfoRepository {
  // ============================================
  // Device Information Methods
  // ============================================

  /// Collect current device information
  Future<DeviceInfoModel> collectDeviceInfo();

  /// Get cached device info or collect new
  Future<DeviceInfoModel> getDeviceInfo();

  /// Save or update device info to database
  Future<void> saveDeviceInfo({DeviceInfoModel? deviceInfo});

  /// Get all devices for current user
  Future<List<DeviceInfoModel>> getUserDevices();

  /// Mark device as inactive
  Future<void> markDeviceInactive(String deviceId);

  /// Remove device from database
  Future<void> removeDevice(String deviceId);

  // ============================================
  // Login Session Methods
  // ============================================

  /// Create a new login session
  Future<LoginSessionModel?> createLoginSession({
    required String loginMethod,
    String? ipAddress,
    String? loginLocation,
  });

  /// Update session activity time
  Future<void> updateSessionActivity({SessionStatus? status});

  /// Set session status to active
  Future<void> setSessionActive();

  /// Set session status to inactive
  Future<void> setSessionInactive();

  /// Get current session status
  Future<SessionStatus?> getCurrentSessionStatus();

  /// Check if current session is still valid
  Future<bool> isSessionValid();

  /// End login session (on logout)
  Future<void> endLoginSession({SessionStatus status});

  /// Get all valid sessions for current user
  Future<List<LoginSessionModel>> getActiveSessions({bool activeOnly});

  /// Get session history for current user
  Future<List<LoginSessionModel>> getSessionHistory({int limit});

  /// Force logout a specific session
  Future<void> forceLogoutSession(String sessionId);

  /// Force logout all other sessions except current
  Future<void> forceLogoutAllOtherSessions();

  // ============================================
  // Combined Operations
  // ============================================

  /// Called when user logs in
  Future<void> onUserLogin({
    required String loginMethod,
    String? ipAddress,
    String? loginLocation,
  });

  /// Called when user logs out
  Future<void> onUserLogout();

  /// Start listening for force logout on the current device
  Future<void> startForceLogoutListener();

  /// Stop listening for force logout
  void stopForceLogoutListener();

  /// Called when app opens
  Future<void> onAppOpened();

  /// Clear cached data
  void clearCache();
}
