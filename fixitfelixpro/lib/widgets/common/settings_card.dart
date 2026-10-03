import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';
import 'settings_menu_item.dart';

/// A reusable card that contains settings menu items with proper dividers
class SettingsCard extends StatelessWidget {
  final List<SettingsItemData> items;
  final DeviceInfo? deviceInfo;
  final EdgeInsets? padding;

  const SettingsCard({
    super.key,
    required this.items,
    this.deviceInfo,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    final cardPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: device.isTablet ? 16 : 12,
          vertical: device.isTablet ? 8 : 6,
        );

    return ShadCard(
      padding: cardPadding,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            SettingsMenuItem(item: items[i], deviceInfo: device),
            if (i < items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

/// A section with a title and a settings card
class SettingsSection extends StatelessWidget {
  final String title;
  final List<SettingsItemData> items;
  final DeviceInfo? deviceInfo;
  final EdgeInsets? cardPadding;

  const SettingsSection({
    super.key,
    required this.title,
    required this.items,
    this.deviceInfo,
    this.cardPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final device = deviceInfo ?? context.deviceInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: device.isTablet ? 4 : 2,
            bottom: device.isTablet ? 12 : 10,
          ),
          child: Text(
            title,
            style: (device.isTablet ? theme.textTheme.large : theme.textTheme.p)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SettingsCard(items: items, deviceInfo: device, padding: cardPadding),
      ],
    );
  }
}

/// A header for settings sections (without card)
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final DeviceInfo? deviceInfo;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    return Padding(
      padding: EdgeInsets.only(
        left: device.isTablet ? 4 : 2,
        bottom: device.isTablet ? 12 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      (device.isTablet
                              ? theme.textTheme.large
                              : theme.textTheme.p)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.muted.copyWith(
                      fontSize: device.isTablet ? 13 : 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
