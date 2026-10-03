import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../responsive/responsive.dart';

/// Modern, responsive dialog utilities for the FixItFelix app
/// All dialogs support mobile, tablet, and landscape orientations
class CommonDialogs {
  CommonDialogs._();

  /// Show a modern confirmation dialog with customizable actions
  /// Returns true if confirmed, false if cancelled, null if dismissed
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    final effectiveConfirmColor =
        confirmColor ??
        (isDangerous ? const Color(0xFFEF4444) : colorScheme.primary);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 480 : 360,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: effectiveConfirmColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: deviceInfo.isTablet ? 32 : 28,
                          color: effectiveConfirmColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.h4)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: theme.textTheme.p.copyWith(
                        color: colorScheme.mutedForeground,
                        fontSize: deviceInfo.isTablet ? 16 : 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Divider
              Divider(height: 1, color: colorScheme.border),
              // Actions
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: () => Navigator.pop(context, false),
                        size: deviceInfo.isTablet
                            ? ShadButtonSize.lg
                            : ShadButtonSize.regular,
                        child: Text(cancelText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShadButton(
                        onPressed: () => Navigator.pop(context, true),
                        size: deviceInfo.isTablet
                            ? ShadButtonSize.lg
                            : ShadButtonSize.regular,
                        backgroundColor: effectiveConfirmColor,
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern removal/delete confirmation dialog
  static Future<bool?> showRemoveDialog(
    BuildContext context, {
    required String itemName,
    String? itemType,
    String? additionalMessage,
  }) {
    final type = itemType ?? 'item';
    return showConfirmDialog(
      context,
      title: 'Remove $type',
      message:
          additionalMessage ??
          'Are you sure you want to remove $itemName? This action cannot be undone.',
      confirmText: 'Remove',
      cancelText: 'Cancel',
      icon: LucideIcons.trash2,
      isDangerous: true,
    );
  }

  /// Show a modern loading dialog with optional message
  /// Returns a function to dismiss the dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(deviceInfo.isTablet ? 32 : 24),
            decoration: BoxDecoration(
              color: colorScheme.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: deviceInfo.isTablet ? 48 : 40,
                  height: deviceInfo.isTablet ? 48 : 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
                if (message != null) ...[
                  SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                  Text(
                    message,
                    style: theme.textTheme.p.copyWith(
                      color: colorScheme.mutedForeground,
                      fontSize: deviceInfo.isTablet ? 16 : 14,
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

  /// Hide any dialog (including loading dialog)
  static void hideDialog(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// Loading box with circular spinner, title and message.
  /// Non-dismissible. Dismiss with [hideDialog].
  static void showLoadingBox(
    BuildContext context, {
    required String title,
    required String message,
    Color? accentColor,
  }) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;
    final accent = accentColor ?? colorScheme.primary;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: deviceInfo.isTablet ? 80 : 24,
            vertical: 24,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: deviceInfo.isTablet ? 440 : 360,
            ),
            padding: EdgeInsets.all(deviceInfo.isTablet ? 32 : 28),
            decoration: BoxDecoration(
              color: colorScheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: deviceInfo.isTablet ? 36 : 30,
                    height: deviceInfo.isTablet ? 36 : 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: (deviceInfo.isTablet
                          ? theme.textTheme.h4
                          : theme.textTheme.large)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.muted.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Typed confirmation boxes (Error / Info / Warning)
  // Two buttons: No pops the dialog, Yes runs onConfirm
  // ============================================================

  /// Error box — red destructive styling. [onConfirm] fires on "Yes".
  static Future<void> showErrorBox(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = LucideIcons.circleX,
    String yesText = 'Yes',
    String noText = 'No',
    VoidCallback? onConfirm,
  }) => _showTypedBox(
        context,
        title: title,
        message: message,
        icon: icon,
        accentColor: const Color(0xFFEF4444),
        yesText: yesText,
        noText: noText,
        onConfirm: onConfirm,
      );

  /// Information box — blue info styling. [onConfirm] fires on "Yes".
  static Future<void> showInfoBox(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = LucideIcons.info,
    String yesText = 'Yes',
    String noText = 'No',
    VoidCallback? onConfirm,
  }) => _showTypedBox(
        context,
        title: title,
        message: message,
        icon: icon,
        accentColor: const Color(0xFF3B82F6),
        yesText: yesText,
        noText: noText,
        onConfirm: onConfirm,
      );

  /// Warning box — amber caution styling. [onConfirm] fires on "Yes".
  static Future<void> showWarningBox(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = LucideIcons.triangleAlert,
    String yesText = 'Yes',
    String noText = 'No',
    VoidCallback? onConfirm,
  }) => _showTypedBox(
        context,
        title: title,
        message: message,
        icon: icon,
        accentColor: const Color(0xFFF59E0B),
        yesText: yesText,
        noText: noText,
        onConfirm: onConfirm,
      );

  static Future<void> _showTypedBox(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
    required String yesText,
    required String noText,
    VoidCallback? onConfirm,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 440 : 360,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: deviceInfo.isTablet ? 32 : 28,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: (deviceInfo.isTablet
                              ? theme.textTheme.h4
                              : theme.textTheme.large)
                          .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: theme.textTheme.muted
                          .copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.border),
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ShadButton(
                        backgroundColor: accentColor,
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onConfirm?.call();
                        },
                        child: Text(
                          yesText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ShadButton.outline(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          noText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern success dialog
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    String? message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 400 : 340,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.circleCheck,
                        size: deviceInfo.isTablet ? 40 : 32,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.h4)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: theme.textTheme.p.copyWith(
                          color: colorScheme.mutedForeground,
                          fontSize: deviceInfo.isTablet ? 16 : 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.border),
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
                child: ShadButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onPressed?.call();
                  },
                  width: double.infinity,
                  size: deviceInfo.isTablet
                      ? ShadButtonSize.lg
                      : ShadButtonSize.regular,
                  backgroundColor: const Color(0xFF10B981),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    String? message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 400 : 340,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.destructive.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.circleX,
                        size: deviceInfo.isTablet ? 40 : 32,
                        color: colorScheme.destructive,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.h4)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: theme.textTheme.p.copyWith(
                          color: colorScheme.mutedForeground,
                          fontSize: deviceInfo.isTablet ? 16 : 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.border),
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
                child: ShadButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onPressed?.call();
                  },
                  width: double.infinity,
                  size: deviceInfo.isTablet
                      ? ShadButtonSize.lg
                      : ShadButtonSize.regular,
                  backgroundColor: colorScheme.destructive,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern upgrade plan dialog
  static Future<void> showUpgradeDialog(
    BuildContext context, {
    String? title,
    String? message,
    List<UpgradePlanOption>? plans,
    VoidCallback? onViewPlans,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    final defaultPlans = [
      UpgradePlanOption(
        name: 'Plus',
        description: '100 mile radius',
        subtitle: 'Extended coverage',
        color: const Color(0xFF6366F1),
      ),
      UpgradePlanOption(
        name: 'Advance',
        description: 'Unlimited radius',
        subtitle: 'Full coverage',
        color: const Color(0xFF10B981),
      ),
    ];

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 500 : 380,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.1),
                            const Color(0xFF10B981).withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.sparkles,
                        size: deviceInfo.isTablet ? 32 : 28,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title ?? 'Upgrade Your Plan',
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.h4)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message ??
                          'Get access to more features by upgrading your plan:',
                      style: theme.textTheme.p.copyWith(
                        color: colorScheme.mutedForeground,
                        fontSize: deviceInfo.isTablet ? 16 : 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Plans
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: deviceInfo.isTablet ? 28 : 24,
                ),
                child: Column(
                  children: (plans ?? defaultPlans)
                      .map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildUpgradePlanCard(
                            context,
                            plan,
                            deviceInfo,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Actions
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: () => Navigator.pop(context),
                        size: deviceInfo.isTablet
                            ? ShadButtonSize.lg
                            : ShadButtonSize.regular,
                        child: const Text('Maybe Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShadButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onViewPlans?.call();
                        },
                        size: deviceInfo.isTablet
                            ? ShadButtonSize.lg
                            : ShadButtonSize.regular,
                        child: const Text('View Plans'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildUpgradePlanCard(
    BuildContext context,
    UpgradePlanOption plan,
    DeviceInfo deviceInfo,
  ) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: plan.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: plan.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: deviceInfo.isTablet ? 14 : 12,
              vertical: deviceInfo.isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: plan.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              plan.name,
              style: theme.textTheme.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: deviceInfo.isTablet ? 14 : 12,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.description,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 15 : 13,
                  ),
                ),
                if (plan.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    plan.subtitle!,
                    style: theme.textTheme.muted.copyWith(
                      fontSize: deviceInfo.isTablet ? 13 : 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: plan.color),
        ],
      ),
    );
  }

  /// Show a modern info dialog
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Got it',
    IconData? icon,
  }) async {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: deviceInfo.isTablet ? 80 : 24,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: deviceInfo.isTablet ? 420 : 340,
          ),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon ?? LucideIcons.info,
                        size: deviceInfo.isTablet ? 32 : 28,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.h4)
                              .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: theme.textTheme.p.copyWith(
                        color: colorScheme.mutedForeground,
                        fontSize: deviceInfo.isTablet ? 16 : 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
                child: ShadButton(
                  onPressed: () => Navigator.pop(context),
                  size: deviceInfo.isTablet
                      ? ShadButtonSize.lg
                      : ShadButtonSize.regular,
                  width: double.infinity,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modern bottom sheet
  static Future<T?> showModernBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeight,
  }) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final deviceInfo = context.deviceInfo;

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.9,
        maxWidth: deviceInfo.isTablet ? 600 : double.infinity,
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colorScheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Model for upgrade plan options
class UpgradePlanOption {
  final String name;
  final String description;
  final String? subtitle;
  final Color color;

  UpgradePlanOption({
    required this.name,
    required this.description,
    this.subtitle,
    required this.color,
  });

  /// Create UpgradePlanOption from SubscriptionPlanConfigModel
  /// Extracts the most relevant features for display
  factory UpgradePlanOption.fromSubscriptionPlan(
    dynamic planConfig, {
    Color? customColor,
  }) {
    // Handle SubscriptionPlanConfigModel
    final String planName = planConfig.name ?? '';
    final String planDescription = planConfig.description ?? '';
    final List<String> features = planConfig.features ?? [];
    final planType = planConfig.planType;

    // Determine color based on plan type
    Color color = customColor ?? const Color(0xFF6366F1);
    if (planType != null) {
      switch (planType.toString().split('.').last) {
        case 'standard':
          color = const Color(0xFF64748B); // Slate
          break;
        case 'plus':
          color = const Color(0xFF6366F1); // Indigo
          break;
        case 'advance':
          color = const Color(0xFF10B981); // Emerald
          break;
        case 'vip':
          color = const Color(0xFFF59E0B); // Amber
          break;
      }
    }

    // Extract description and subtitle from features or limits
    String description = planDescription;
    String? subtitle;

    // Try to get radius from tradesman or business limits
    final tradesmanLimits = planConfig.tradesmanLimits;
    final businessLimits = planConfig.businessLimits;

    if (tradesmanLimits != null) {
      final radius = tradesmanLimits.serviceRadiusMiles;
      if (radius != null && radius > 0) {
        description = '$radius mile radius';
      } else if (radius == -1) {
        description = 'Unlimited radius';
      }

      final apps = tradesmanLimits.maxJobApplicationsPerMonth;
      if (apps != null && apps > 0) {
        subtitle = '$apps applications/month';
      } else if (apps == -1) {
        subtitle = 'Unlimited applications';
      }
    } else if (businessLimits != null) {
      final radius = businessLimits.serviceRadiusMiles;
      if (radius != null && radius > 0) {
        description = '$radius mile radius';
      } else if (radius == -1) {
        description = 'Unlimited radius';
      }

      final staff = businessLimits.maxStaffMembers;
      if (staff != null && staff > 0) {
        subtitle = 'Up to $staff staff members';
      } else if (staff == -1) {
        subtitle = 'Unlimited staff';
      }
    }

    // Fallback to first feature if no limits-based description
    if (description == planDescription && features.isNotEmpty) {
      description = features.first;
      if (features.length > 1) {
        subtitle = features[1];
      }
    }

    return UpgradePlanOption(
      name: planName,
      description: description,
      subtitle: subtitle,
      color: color,
    );
  }
}
