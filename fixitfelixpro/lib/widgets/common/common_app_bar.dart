import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';

/// A reusable app bar widget used across settings and detail screens
class CommonAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final DeviceInfo? deviceInfo;
  final bool showBackButton;
  final Widget? leading;

  const CommonAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
    this.deviceInfo,
    this.showBackButton = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: device.isTablet ? 12 : 8,
        vertical: device.isTablet ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.background,
        border: Border(bottom: BorderSide(color: colorScheme.border, width: 1)),
      ),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (showBackButton)
            ShadButton.ghost(
              size: device.isTablet
                  ? ShadButtonSize.regular
                  : ShadButtonSize.sm,
              onPressed: onBackPressed ?? () => Navigator.pop(context),
              child: Icon(
                LucideIcons.chevronLeft,
                size: device.isTablet ? 26 : 22,
                color: colorScheme.foreground,
              ),
            ),
          SizedBox(width: device.isTablet ? 12 : 8),
          Expanded(
            child: Text(
              title,
              style: device.isTablet ? theme.textTheme.h3 : theme.textTheme.h4,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// App bar for main tabs (without back button)
class TabAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final DeviceInfo? deviceInfo;

  const TabAppBar({
    super.key,
    required this.title,
    this.actions,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: device.isTablet ? 24 : 16,
        vertical: device.isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.background,
        border: Border(bottom: BorderSide(color: colorScheme.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: (device.isTablet ? theme.textTheme.h3 : theme.textTheme.h4)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Icon button for app bar actions
class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final DeviceInfo? deviceInfo;
  final String? tooltip;
  final Color? iconColor;
  final int? badgeCount;

  const AppBarIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.deviceInfo,
    this.tooltip,
    this.iconColor,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    final button = ShadButton.ghost(
      size: device.isTablet ? ShadButtonSize.regular : ShadButtonSize.sm,
      onPressed: onPressed,
      child: Icon(
        icon,
        size: device.isTablet ? 22 : 18,
        color: iconColor ?? colorScheme.foreground,
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.destructive,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: TextStyle(
                  color: colorScheme.destructiveForeground,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return button;
  }
}
