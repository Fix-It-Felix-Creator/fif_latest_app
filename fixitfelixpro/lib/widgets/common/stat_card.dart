import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/design_system/design_system.dart';
import '../../core/responsive/responsive.dart';

/// A reusable stat card widget for displaying statistics
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;
  final bool isLoading;
  final DeviceInfo? deviceInfo;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
    this.isLoading = false,
    this.deviceInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;

    final effectiveIconColor = iconColor ?? AppColors.primaryIndigo;

    final card = ShadCard(
      padding: EdgeInsets.all(device.isTablet ? 18 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconContainer(
            icon: icon,
            color: effectiveIconColor,
            size: device.isTablet ? 40 : 34,
            iconSize: device.isTablet ? 18 : 15,
            withBorder: true,
          ),
          SizedBox(height: device.isTablet ? 12 : 10),
          if (isLoading)
            Shimmer.fromColors(
              baseColor: colorScheme.muted,
              highlightColor: colorScheme.background,
              child: Container(
                width: 40,
                height: device.isTablet ? 28 : 24,
                decoration: BoxDecoration(
                  color: colorScheme.muted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  effectiveIconColor,
                  effectiveIconColor.withValues(alpha: 0.7),
                ],
              ).createShader(bounds),
              child: Text(
                value,
                style:
                    (device.isTablet ? theme.textTheme.h3 : theme.textTheme.h4)
                        .copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
              ),
            ),
          SizedBox(height: device.isTablet ? 4 : 2),
          Text(
            label,
            style: theme.textTheme.muted.copyWith(
              fontSize: device.isTablet ? 12 : 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

/// A row of stat cards
class StatCardsRow extends StatelessWidget {
  final List<StatCardData> stats;
  final bool isLoading;
  final DeviceInfo? deviceInfo;
  final double spacing;

  const StatCardsRow({
    super.key,
    required this.stats,
    this.isLoading = false,
    this.deviceInfo,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    final device = deviceInfo ?? context.deviceInfo;

    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          Expanded(
            child: StatCard(
              icon: stats[i].icon,
              label: stats[i].label,
              value: isLoading ? '-' : stats[i].value,
              iconColor: stats[i].iconColor,
              valueColor: stats[i].valueColor,
              isLoading: isLoading,
              deviceInfo: device,
              onTap: stats[i].onTap,
            ),
          ),
          if (i < stats.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

/// Data model for stat cards
class StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  const StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
    this.onTap,
  });
}

/// Compact stat card for smaller displays
class CompactStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final DeviceInfo? deviceInfo;

  const CompactStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final device = deviceInfo ?? context.deviceInfo;
    final effectiveColor = color ?? AppColors.primaryIndigo;

    return ShadCard(
      padding: EdgeInsets.all(device.isTablet ? 14 : 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconContainer(
            icon: icon,
            color: effectiveColor,
            size: device.isTablet ? 36 : 32,
            iconSize: device.isTablet ? 16 : 14,
          ),
          SizedBox(width: device.isTablet ? 10 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style:
                    (device.isTablet
                            ? theme.textTheme.large
                            : theme.textTheme.p)
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          color: effectiveColor,
                        ),
              ),
              Text(
                label,
                style: theme.textTheme.muted.copyWith(
                  fontSize: device.isTablet ? 11 : 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
