import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_design_system.dart';

/// Modern Toast System
///
/// A beautiful toast notification system with glass effects,
/// gradient accents, and smooth animations.

enum ToastType { success, error, warning, info, loading }

class AppToast {
  AppToast._();

  /// Show a success toast
  static void success(
    BuildContext context, {
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      type: ToastType.success,
      title: title,
      description: description,
      duration: duration,
    );
  }

  /// Show an error toast
  static void error(
    BuildContext context, {
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      type: ToastType.error,
      title: title,
      description: description,
      duration: duration,
    );
  }

  /// Show a warning toast
  static void warning(
    BuildContext context, {
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      type: ToastType.warning,
      title: title,
      description: description,
      duration: duration,
    );
  }

  /// Show an info toast
  static void info(
    BuildContext context, {
    required String title,
    String? description,
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      type: ToastType.info,
      title: title,
      description: description,
      duration: duration,
    );
  }

  /// Show a loading toast
  static void loading(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    _show(
      context,
      type: ToastType.loading,
      title: title,
      description: description,
      duration: const Duration(days: 1), // Will be dismissed manually
    );
  }

  /// Show a custom toast with action button
  static void withAction(
    BuildContext context, {
    required String title,
    String? description,
    required String actionLabel,
    required VoidCallback onAction,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 6),
  }) {
    _showWithAction(
      context,
      type: type,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Hide all current toasts
  static void hideAll(BuildContext context) {
    ShadToaster.of(context).hide();
  }

  static void _show(
    BuildContext context, {
    required ToastType type,
    required String title,
    String? description,
    required Duration duration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final toastConfig = _getToastConfig(type);

    ShadToaster.of(context).show(
      ShadToast(
        duration: duration,
        title: _buildToast(
          isDark: isDark,
          colorScheme: colorScheme,
          theme: theme,
          config: toastConfig,
          title: title,
          description: description,
          type: type,
        ),
      ),
    );
  }

  static void _showWithAction(
    BuildContext context, {
    required ToastType type,
    required String title,
    String? description,
    required String actionLabel,
    required VoidCallback onAction,
    required Duration duration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final toastConfig = _getToastConfig(type);

    ShadToaster.of(context).show(
      ShadToast(
        duration: duration,
        title: _buildToastWithAction(
          isDark: isDark,
          colorScheme: colorScheme,
          theme: theme,
          config: toastConfig,
          title: title,
          description: description,
          type: type,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  static Widget _buildToast({
    required bool isDark,
    required ShadColorScheme colorScheme,
    required ShadThemeData theme,
    required _ToastConfig config,
    required String title,
    String? description,
    required ToastType type,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [config.color, config.colorDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: type == ToastType.loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(config.icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                      fontSize: 12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Accent bar
          Container(
            width: 3,
            height: 28,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [config.color, config.colorDark],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildToastWithAction({
    required bool isDark,
    required ShadColorScheme colorScheme,
    required ShadThemeData theme,
    required _ToastConfig config,
    required String title,
    String? description,
    required ToastType type,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [config.color, config.colorDark],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(config.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Action button
          GestureDetector(
            onTap: onAction,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [config.color, config.colorDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _ToastConfig _getToastConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          color: AppColors.success,
          colorDark: AppColors.successDark,
          icon: LucideIcons.circleCheck,
        );
      case ToastType.error:
        return _ToastConfig(
          color: AppColors.error,
          colorDark: AppColors.errorDark,
          icon: LucideIcons.circleX,
        );
      case ToastType.warning:
        return _ToastConfig(
          color: AppColors.warning,
          colorDark: AppColors.warningDark,
          icon: LucideIcons.triangleAlert,
        );
      case ToastType.info:
        return _ToastConfig(
          color: AppColors.info,
          colorDark: AppColors.infoDark,
          icon: LucideIcons.info,
        );
      case ToastType.loading:
        return _ToastConfig(
          color: AppColors.primaryIndigo,
          colorDark: AppColors.primaryPurple,
          icon: LucideIcons.loader,
        );
    }
  }
}

class _ToastConfig {
  final Color color;
  final Color colorDark;
  final IconData icon;

  const _ToastConfig({
    required this.color,
    required this.colorDark,
    required this.icon,
  });
}

// =============================================================================
// SNACKBAR ALTERNATIVE (for quick notifications)
// =============================================================================

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final config = _getConfig(type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: config.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [config.color, config.colorDark],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(config.icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              if (onAction != null && actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [config.color, config.colorDark],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.zero,
      ),
    );
  }

  static _ToastConfig _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          color: AppColors.success,
          colorDark: AppColors.successDark,
          icon: LucideIcons.circleCheck,
        );
      case ToastType.error:
        return _ToastConfig(
          color: AppColors.error,
          colorDark: AppColors.errorDark,
          icon: LucideIcons.circleX,
        );
      case ToastType.warning:
        return _ToastConfig(
          color: AppColors.warning,
          colorDark: AppColors.warningDark,
          icon: LucideIcons.triangleAlert,
        );
      case ToastType.info:
        return _ToastConfig(
          color: AppColors.info,
          colorDark: AppColors.infoDark,
          icon: LucideIcons.info,
        );
      case ToastType.loading:
        return _ToastConfig(
          color: AppColors.primaryIndigo,
          colorDark: AppColors.primaryPurple,
          icon: LucideIcons.loader,
        );
    }
  }
}

// =============================================================================
// DIALOG HELPERS
// =============================================================================

class AppDialog {
  AppDialog._();

  /// Show a modern confirmation dialog
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String description,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDestructive
                        ? [AppColors.error, AppColors.errorDark]
                        : [AppColors.primaryIndigo, AppColors.primaryPurple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isDestructive ? LucideIcons.triangleAlert : LucideIcons.info,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                title,
                style: theme.textTheme.h4.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colorScheme.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                description,
                style: theme.textTheme.p.copyWith(
                  color: colorScheme.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.muted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.border),
                        ),
                        child: Text(
                          cancelText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDestructive
                                ? [AppColors.error, AppColors.errorDark]
                                : [
                                    AppColors.primaryIndigo,
                                    AppColors.primaryPurple,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          confirmText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern success dialog
  static Future<void> success(
    BuildContext context, {
    required String title,
    String? description,
    String buttonText = 'Done',
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppGradients.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                title,
                style: theme.textTheme.h4.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colorScheme.foreground,
                ),
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.p.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              // Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppGradients.success,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    buttonText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.p.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a processing/loading dialog (non-dismissible)
  ///
  /// Returns nothing - caller must pop it manually with Navigator.of(context).pop()
  static void processing(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated loading icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  title,
                  style: theme.textTheme.h4.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: theme.textTheme.p.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
