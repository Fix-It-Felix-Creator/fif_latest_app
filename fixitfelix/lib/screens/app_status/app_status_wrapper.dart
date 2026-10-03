import 'package:flutter/material.dart';

import '../../core/config/config_service.dart';
import 'force_update_screen.dart';
import 'maintenance_screen.dart';

/// App Status Wrapper
///
/// Wraps the app and checks for maintenance mode and force update requirements.
/// Displays the appropriate screen based on the app status from remote config.
///
/// Priority:
/// 1. Force Update (if required) - User must update the app
/// 2. Maintenance Mode - App is under maintenance
/// 3. Normal - Show the child widget
class AppStatusWrapper extends StatefulWidget {
  final Widget child;
  final bool checkOnResume;

  const AppStatusWrapper({
    super.key,
    required this.child,
    this.checkOnResume = true,
  });

  @override
  State<AppStatusWrapper> createState() => _AppStatusWrapperState();
}

class _AppStatusWrapperState extends State<AppStatusWrapper>
    with WidgetsBindingObserver {
  final ConfigService _configService = ConfigService();
  bool _bypassMaintenance = false;

  @override
  void initState() {
    super.initState();
    if (widget.checkOnResume) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (widget.checkOnResume) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh config when app resumes
      _configService.refresh().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _handleMaintenanceBypass() {
    setState(() {
      _bypassMaintenance = true;
    });
  }

  void _handleRetry() {
    setState(() {
      _bypassMaintenance = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AppStatusWrapper: Building...");
    debugPrint(
      "AppStatusWrapper: requiresForceUpdate=${_configService.requiresForceUpdate}",
    );
    debugPrint(
      "AppStatusWrapper: isUnderMaintenance=${_configService.isUnderMaintenance}",
    );
    debugPrint("AppStatusWrapper: bypassMaintenance=$_bypassMaintenance");

    // Priority 1: Check for force update
    if (_configService.requiresForceUpdate) {
      debugPrint("AppStatusWrapper: Showing ForceUpdateScreen");
      return ForceUpdateScreen(onRetry: _handleRetry);
    }

    // Priority 2: Check for maintenance mode
    if (_configService.isUnderMaintenance && !_bypassMaintenance) {
      debugPrint("AppStatusWrapper: Showing MaintenanceScreen");
      return MaintenanceScreen(
        onRetry: _handleRetry,
        onBypass: _configService.allowMaintenanceBypass
            ? _handleMaintenanceBypass
            : null,
      );
    }

    // Priority 3: Show normal content
    debugPrint("AppStatusWrapper: Showing child widget");
    return widget.child;
  }
}

/// Extension to easily check app status
extension AppStatusCheck on BuildContext {
  /// Check if app is under maintenance
  bool get isUnderMaintenance => ConfigService().isUnderMaintenance;

  /// Check if force update is required
  bool get requiresForceUpdate => ConfigService().requiresForceUpdate;

  /// Check if app can proceed normally
  bool get canProceed =>
      !ConfigService().isUnderMaintenance &&
      !ConfigService().requiresForceUpdate;
}
