import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';

/// Data model for settings menu item
class SettingsItemData {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final bool showChevron;
  final bool isDestructive;

  const SettingsItemData({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.showChevron = true,
    this.isDestructive = false,
  });
}

/// Reusable settings menu item widget
class SettingsMenuItem extends StatelessWidget {
  final SettingsItemData item;
  final DeviceInfo? deviceInfo;

  const SettingsMenuItem({super.key, required this.item, this.deviceInfo});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    final iconSize = device.isTablet ? 22.0 : 20.0;
    final containerPadding = device.isTablet ? 12.0 : 10.0;

    // iOS-style: solid coloured tile with a white icon. Falls back to the
    // brand primary if a caller doesn't pick a colour for the row.
    final tileColor = item.isDestructive
        ? colorScheme.destructive
        : (item.iconColor ?? colorScheme.primary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: device.isTablet ? 14.0 : 12.0,
            horizontal: device.isTablet ? 4.0 : 2.0,
          ),
          child: Row(
            children: [
              Container(
                width: device.isTablet ? 44 : 40,
                height: device.isTablet ? 44 : 40,
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: device.isTablet ? 14 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style:
                          (device.isTablet
                                  ? theme.textTheme.p
                                  : theme.textTheme.small)
                              .copyWith(
                                fontWeight: FontWeight.w500,
                                color: item.isDestructive
                                    ? colorScheme.destructive
                                    : colorScheme.foreground,
                              ),
                    ),
                    if (item.subtitle != null) ...[
                      SizedBox(height: device.isTablet ? 3 : 2),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.muted.copyWith(
                          fontSize: device.isTablet ? 12 : 11,
                          color: item.isDestructive
                              ? colorScheme.destructive.withValues(alpha: 0.7)
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.trailing != null) ...[
                SizedBox(width: device.isTablet ? 10 : 8),
                item.trailing!,
              ],
              if (item.showChevron) ...[
                SizedBox(width: device.isTablet ? 10 : 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: device.isTablet ? 20 : 18,
                  color: item.isDestructive
                      ? colorScheme.destructive.withValues(alpha: 0.5)
                      : colorScheme.mutedForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds a toggle switch trailing widget for settings
class SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ShadSwitch(value: value, onChanged: onChanged);
  }
}

/// Badge widget for settings items
class SettingsBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  const SettingsBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor ?? colorScheme.primary,
        ),
      ),
    );
  }
}
