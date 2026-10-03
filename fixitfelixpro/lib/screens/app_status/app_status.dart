/// App Status Screens
///
/// Screens for handling app maintenance mode and force update requirements.
///
/// Usage in main.dart or app entry point:
/// ```dart
/// return AppStatusWrapper(
///   child: MaterialApp(...),
/// );
/// ```
///
/// Or use individual screens:
/// ```dart
/// if (ConfigService().isUnderMaintenance) {
///   return MaintenanceScreen();
/// }
/// if (ConfigService().requiresForceUpdate) {
///   return ForceUpdateScreen();
/// }
/// ```

export 'app_status_wrapper.dart';
export 'force_update_screen.dart';
export 'maintenance_screen.dart';
