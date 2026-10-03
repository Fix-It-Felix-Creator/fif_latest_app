import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';

/// Data model for quick action items
class QuickActionData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;
  final Widget? screen;

  const QuickActionData({
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
    this.screen,
  });
}

/// A reusable quick actions grid widget
class QuickActionsGrid extends StatelessWidget {
  final List<QuickActionData> actions;
  final DeviceInfo? deviceInfo;
  final int? columns;
  final double spacing;
  final double runSpacing;

  const QuickActionsGrid({
    super.key,
    required this.actions,
    this.deviceInfo,
    this.columns,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final device = deviceInfo ?? context.deviceInfo;
    final effectiveColumns =
        columns ?? (device.isTablet && device.isLandscape ? 6 : 3);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveColumns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: device.isTablet ? 1.0 : 0.95,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return QuickActionItem(action: actions[index], deviceInfo: device);
      },
    );
  }
}

/// Individual quick action item
class QuickActionItem extends StatelessWidget {
  final QuickActionData action;
  final DeviceInfo? deviceInfo;

  const QuickActionItem({super.key, required this.action, this.deviceInfo});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final device = deviceInfo ?? context.deviceInfo;

    return GestureDetector(
      onTap:
          action.onTap ??
          (action.screen != null
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => action.screen!),
                )
              : null),
      child: ShadCard(
        padding: EdgeInsets.all(device.isTablet ? 14 : 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(device.isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                action.icon,
                size: device.isTablet ? 24 : 20,
                color: action.color,
              ),
            ),
            SizedBox(height: device.isTablet ? 10 : 8),
            Text(
              action.title,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: device.isTablet ? 13 : 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with "View All" action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final DeviceInfo? deviceInfo;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionPressed,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: (device.isTablet ? theme.textTheme.large : theme.textTheme.p)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        if (actionText != null && onActionPressed != null)
          ShadButton.link(
            onPressed: onActionPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText!,
                  style: theme.textTheme.small.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
