import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';
import '../../models/feature_limits_model.dart';

/// Helper class to hold usage statistics
class UsageStats {
  final int usedCount;
  final int totalLimit;
  final int unlimitedCount;
  final int limitedFeatureCount;
  final int nearLimitCount;
  final int totalActualUsage;
  final double percentage;

  const UsageStats({
    required this.usedCount,
    required this.totalLimit,
    required this.unlimitedCount,
    required this.limitedFeatureCount,
    required this.nearLimitCount,
    required this.totalActualUsage,
    required this.percentage,
  });

  /// Check if user has any actual usage (limited or unlimited)
  bool get hasAnyUsage => totalActualUsage > 0;
}

/// Mixin providing usage calculation methods
mixin UsageCalculationMixin {
  /// Calculate overall usage statistics
  UsageStats calculateUsageStats({
    required int addressCount,
    required int customerCount,
    required int invoiceCount,
    required int quotationCount,
    required int serviceCount,
    required int templateCount,
    required int jobApplicationsThisMonth,
    required int photoUploadCount,
    required int videoUploadCount,
    required int staffCount,
    required int freelanceHiresThisMonth,
    required FeatureLimitsModel limits,
  }) {
    int usedCount = 0;
    int totalLimit = 0;
    int unlimitedCount = 0;
    int limitedFeatureCount = 0;
    int nearLimitCount = 0;
    int totalActualUsage = 0;

    void addStat(int current, int max) {
      totalActualUsage += current;

      if (max == -1) {
        unlimitedCount++;
      } else if (max > 0) {
        limitedFeatureCount++;
        usedCount += current;
        totalLimit += max;
        if (current >= (max * 0.8)) {
          nearLimitCount++;
        }
      }
    }

    // Base limits
    addStat(addressCount, limits.maxAddresses);
    addStat(customerCount, limits.maxCustomers);
    addStat(invoiceCount, limits.maxInvoices);
    addStat(quotationCount, limits.maxQuotations);
    addStat(serviceCount, limits.maxServices);
    addStat(templateCount, limits.maxTemplates);

    // Tradesman/Business limits
    addStat(jobApplicationsThisMonth, limits.maxJobApplicationsPerMonth);
    addStat(photoUploadCount, limits.maxPhotoUploads);
    addStat(videoUploadCount, limits.maxVideoUploads);
    addStat(staffCount, limits.maxStaffMembers);
    addStat(freelanceHiresThisMonth, limits.maxFreelanceHiresPerMonth);

    final percentage = totalLimit > 0 ? (usedCount / totalLimit * 100) : 0.0;

    return UsageStats(
      usedCount: usedCount,
      totalLimit: totalLimit,
      unlimitedCount: unlimitedCount,
      limitedFeatureCount: limitedFeatureCount,
      nearLimitCount: nearLimitCount,
      totalActualUsage: totalActualUsage,
      percentage: percentage.clamp(0.0, 100.0),
    );
  }

  /// Calculate customer-specific usage statistics (addresses and jobs only)
  UsageStats calculateCustomerUsageStats({
    required int addressCount,
    required int jobCount,
    required FeatureLimitsModel limits,
  }) {
    int usedCount = 0;
    int totalLimit = 0;
    int unlimitedCount = 0;
    int limitedFeatureCount = 0;
    int nearLimitCount = 0;
    int totalActualUsage = 0;

    void addStat(int current, int max) {
      totalActualUsage += current;

      if (max == -1) {
        unlimitedCount++;
      } else if (max > 0) {
        limitedFeatureCount++;
        usedCount += current;
        totalLimit += max;
        if (current >= (max * 0.8)) {
          nearLimitCount++;
        }
      }
    }

    // Customer limits
    addStat(addressCount, limits.maxAddresses);
    addStat(jobCount, limits.maxJobs);

    final percentage = totalLimit > 0 ? (usedCount / totalLimit * 100) : 0.0;

    return UsageStats(
      usedCount: usedCount,
      totalLimit: totalLimit,
      unlimitedCount: unlimitedCount,
      limitedFeatureCount: limitedFeatureCount,
      nearLimitCount: nearLimitCount,
      totalActualUsage: totalActualUsage,
      percentage: percentage.clamp(0.0, 100.0),
    );
  }
}

/// Overall usage summary card showing percentage of limits used
class UsageSummaryCard extends StatelessWidget {
  final UsageStats stats;
  final DeviceInfo deviceInfo;

  const UsageSummaryCard({
    super.key,
    required this.stats,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final overallPercentage = stats.percentage;
    final isNearLimit = overallPercentage >= 80;
    final isAtLimit = overallPercentage >= 100;

    Color statusColor = colorScheme.primary;
    String statusText = 'Good';
    IconData statusIcon = LucideIcons.circleCheck;

    if (stats.limitedFeatureCount == 0) {
      statusColor = const Color(0xFF10B981);
      statusText = 'All Unlimited';
      statusIcon = LucideIcons.infinity;
    } else if (!stats.hasAnyUsage) {
      statusColor = const Color(0xFF3B82F6);
      statusText = 'Ready';
      statusIcon = LucideIcons.sparkles;
    } else if (isAtLimit) {
      statusColor = colorScheme.destructive;
      statusText = 'Limit Reached';
      statusIcon = LucideIcons.circleAlert;
    } else if (isNearLimit) {
      statusColor = Colors.orange;
      statusText = 'Near Limit';
      statusIcon = LucideIcons.triangleAlert;
    }

    String subtitleText;
    if (stats.limitedFeatureCount == 0 && stats.unlimitedCount > 0) {
      if (stats.hasAnyUsage) {
        subtitleText =
            '${stats.totalActualUsage} items created across ${stats.unlimitedCount} features';
      } else {
        subtitleText = '${stats.unlimitedCount} features with no limits';
      }
    } else if (stats.limitedFeatureCount > 0) {
      if (!stats.hasAnyUsage) {
        subtitleText = 'You haven\'t used any features yet';
      } else {
        subtitleText =
            '${stats.usedCount} of ${stats.totalLimit} limited capacity used';
      }
    } else {
      subtitleText = 'No usage data available';
    }

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  size: deviceInfo.isTablet ? 24 : 20,
                  color: statusColor,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 14 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Usage',
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h4
                                  : theme.textTheme.p)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(subtitleText, style: theme.textTheme.muted),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: deviceInfo.isTablet ? 14 : 12,
                  vertical: deviceInfo.isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 16 : 14),
          if (stats.limitedFeatureCount > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (overallPercentage / 100).clamp(0.0, 1.0),
                backgroundColor: colorScheme.muted.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 10,
              ),
            ),
            SizedBox(height: deviceInfo.isTablet ? 10 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  !stats.hasAnyUsage
                      ? 'No usage yet'
                      : '${overallPercentage.toStringAsFixed(0)}% of limits used',
                  style: theme.textTheme.small.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stats.unlimitedCount > 0 && stats.hasAnyUsage)
                  Text(
                    '+ ${stats.totalActualUsage - stats.usedCount} in unlimited',
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  )
                else if (stats.unlimitedCount > 0)
                  Text(
                    '+ ${stats.unlimitedCount} unlimited',
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: deviceInfo.isTablet ? 12 : 10,
                vertical: deviceInfo.isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.infinity,
                    size: 16,
                    color: const Color(0xFF10B981),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Your plan has unlimited access to all features',
                    style: theme.textTheme.small.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section header for usage sections
class UsageSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final DeviceInfo deviceInfo;

  const UsageSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: deviceInfo.isTablet ? 20 : 18,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(width: deviceInfo.isTablet ? 12 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    (deviceInfo.isTablet
                            ? theme.textTheme.h4
                            : theme.textTheme.large)
                        .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Data model for usage card
class UsageCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final int current;
  final int max;
  final Color color;
  final bool isMonthly;
  final String? lockedMessage;

  const UsageCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.max,
    required this.color,
    this.isMonthly = false,
    this.lockedMessage,
  });
}

/// Individual usage card widget
class UsageCard extends StatelessWidget {
  final UsageCardData data;
  final DeviceInfo deviceInfo;

  const UsageCard({super.key, required this.data, required this.deviceInfo});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final isUnlimited = data.max == -1;
    final isNotAvailable = data.max == 0;
    final isLocked = isNotAvailable;

    double percentage = 0.0;
    bool isNearLimit = false;
    bool isAtLimit = false;

    if (!isUnlimited && !isNotAvailable && data.max > 0) {
      percentage = (data.current / data.max).clamp(0.0, 1.0);
      isNearLimit = percentage >= 0.8;
      isAtLimit = data.current >= data.max;
    }

    Color displayColor = data.color;
    if (isLocked) {
      displayColor = colorScheme.mutedForeground;
    } else if (isAtLimit) {
      displayColor = colorScheme.destructive;
    } else if (isNearLimit) {
      displayColor = Colors.orange;
    }

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLocked ? LucideIcons.lock : data.icon,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: displayColor,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.p
                                  : theme.textTheme.small)
                              .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.subtitle,
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 12 : 10),
          if (isLocked) ...[
            Text(
              'Not Available',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.large
                          : theme.textTheme.p)
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.mutedForeground,
                      ),
            ),
            SizedBox(height: 4),
            Text(
              data.lockedMessage ?? 'Upgrade to unlock',
              style: theme.textTheme.muted.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (isUnlimited) ...[
            Row(
              children: [
                Text(
                  '${data.current}',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h3
                              : theme.textTheme.h4)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.infinity,
                        size: 12,
                        color: const Color(0xFF10B981),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Unlimited',
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 10,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (data.isMonthly)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Resets monthly',
                  style: theme.textTheme.muted.copyWith(fontSize: 10),
                ),
              ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.current} / ${data.max}',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h4
                              : theme.textTheme.large)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                ),
                Text(
                  isAtLimit
                      ? 'Limit reached'
                      : '${data.max - data.current} left',
                  style: theme.textTheme.small.copyWith(
                    color: isAtLimit
                        ? colorScheme.destructive
                        : colorScheme.mutedForeground,
                    fontWeight: isAtLimit ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            SizedBox(height: deviceInfo.isTablet ? 10 : 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: colorScheme.muted.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                minHeight: 6,
              ),
            ),
            if (data.isMonthly)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Resets monthly',
                  style: theme.textTheme.muted.copyWith(fontSize: 10),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Data model for media upload card
class MediaUploadCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final int current;
  final int max;
  final Color color;
  final String maxFileSize;
  final String? maxDuration;

  const MediaUploadCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.max,
    required this.color,
    required this.maxFileSize,
    this.maxDuration,
  });
}

/// Media upload card with file size info
class MediaUploadCard extends StatelessWidget {
  final MediaUploadCardData data;
  final DeviceInfo deviceInfo;

  const MediaUploadCard({
    super.key,
    required this.data,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final isUnlimited = data.max == -1;
    final isNotAvailable = data.max == 0;
    final isLocked = isNotAvailable;

    double percentage = 0.0;
    bool isNearLimit = false;
    bool isAtLimit = false;

    if (!isUnlimited && !isNotAvailable && data.max > 0) {
      percentage = (data.current / data.max).clamp(0.0, 1.0);
      isNearLimit = percentage >= 0.8;
      isAtLimit = data.current >= data.max;
    }

    Color displayColor = data.color;
    if (isLocked) {
      displayColor = colorScheme.mutedForeground;
    } else if (isAtLimit) {
      displayColor = colorScheme.destructive;
    } else if (isNearLimit) {
      displayColor = Colors.orange;
    }

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLocked ? LucideIcons.lock : data.icon,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: displayColor,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.p
                                  : theme.textTheme.small)
                              .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.subtitle,
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 12 : 10),
          if (isLocked) ...[
            Text(
              'Not Available',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.large
                          : theme.textTheme.p)
                      .copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.mutedForeground,
                      ),
            ),
            SizedBox(height: 4),
            Text(
              'Upgrade to unlock',
              style: theme.textTheme.muted.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (isUnlimited) ...[
            Row(
              children: [
                Text(
                  '${data.current}',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h3
                              : theme.textTheme.h4)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.infinity,
                        size: 12,
                        color: const Color(0xFF10B981),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Unlimited',
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 10,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            _buildFileSizeInfo(theme, colorScheme),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.current} / ${data.max}',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h4
                              : theme.textTheme.large)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: displayColor,
                          ),
                ),
                Text(
                  isAtLimit
                      ? 'Limit reached'
                      : '${data.max - data.current} left',
                  style: theme.textTheme.small.copyWith(
                    color: isAtLimit
                        ? colorScheme.destructive
                        : colorScheme.mutedForeground,
                    fontWeight: isAtLimit ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            SizedBox(height: deviceInfo.isTablet ? 10 : 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: colorScheme.muted.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                minHeight: 6,
              ),
            ),
            SizedBox(height: 6),
            _buildFileSizeInfo(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSizeInfo(ShadThemeData theme, ShadColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          LucideIcons.hardDrive,
          size: 12,
          color: colorScheme.mutedForeground,
        ),
        SizedBox(width: 4),
        Text(
          'Max ${data.maxFileSize}/file',
          style: theme.textTheme.muted.copyWith(fontSize: 10),
        ),
        if (data.maxDuration != null) ...[
          SizedBox(width: 8),
          Icon(LucideIcons.clock, size: 12, color: colorScheme.mutedForeground),
          SizedBox(width: 4),
          Text(
            data.maxDuration!,
            style: theme.textTheme.muted.copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Service radius card (special display for distance)
class ServiceRadiusCard extends StatelessWidget {
  final FeatureLimitsModel limits;
  final DeviceInfo deviceInfo;

  const ServiceRadiusCard({
    super.key,
    required this.limits,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    const color = Color(0xFF06B6D4);

    final isUnlimited = limits.isServiceRadiusUnlimited;
    final radiusMiles = limits.serviceRadiusMiles;

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.radar,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: color,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Radius',
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.p
                                  : theme.textTheme.small)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Job visibility',
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 12 : 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                isUnlimited ? 'Nationwide' : '$radiusMiles mi',
                style:
                    (deviceInfo.isTablet
                            ? theme.textTheme.h3
                            : theme.textTheme.h4)
                        .copyWith(fontWeight: FontWeight.w700, color: color),
              ),
              if (isUnlimited)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.globe,
                        size: 12,
                        color: const Color(0xFF10B981),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'All Jobs',
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 10,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            isUnlimited
                ? 'See and apply to jobs anywhere'
                : 'Jobs within $radiusMiles miles',
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Upload constraint row data
class UploadConstraintData {
  final IconData icon;
  final String label;
  final List<String> constraints;

  const UploadConstraintData({
    required this.icon,
    required this.label,
    required this.constraints,
  });
}

/// Upload constraint row widget
class UploadConstraintRow extends StatelessWidget {
  final UploadConstraintData data;
  final DeviceInfo deviceInfo;

  const UploadConstraintRow({
    super.key,
    required this.data,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            data.icon,
            size: deviceInfo.isTablet ? 14 : 12,
            color: colorScheme.mutedForeground,
          ),
        ),
        SizedBox(width: deviceInfo.isTablet ? 10 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: data.constraints.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c,
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Upload constraints card
class UploadConstraintsCard extends StatelessWidget {
  final List<UploadConstraintData> constraints;
  final DeviceInfo deviceInfo;

  const UploadConstraintsCard({
    super.key,
    required this.constraints,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: deviceInfo.isTablet ? 18 : 16,
                color: colorScheme.primary,
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Text(
                'Upload Constraints',
                style:
                    (deviceInfo.isTablet
                            ? theme.textTheme.p
                            : theme.textTheme.small)
                        .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 14 : 12),
          ...constraints.asMap().entries.map((entry) {
            final index = entry.key;
            final constraint = entry.value;
            return Column(
              children: [
                UploadConstraintRow(data: constraint, deviceInfo: deviceInfo),
                if (index < constraints.length - 1)
                  SizedBox(height: deviceInfo.isTablet ? 10 : 8),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Row of two usage cards
class UsageCardRow extends StatelessWidget {
  final UsageCardData leftCard;
  final UsageCardData rightCard;
  final DeviceInfo deviceInfo;

  const UsageCardRow({
    super.key,
    required this.leftCard,
    required this.rightCard,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: UsageCard(data: leftCard, deviceInfo: deviceInfo),
        ),
        SizedBox(width: deviceInfo.isTablet ? 12 : 10),
        Expanded(
          child: UsageCard(data: rightCard, deviceInfo: deviceInfo),
        ),
      ],
    );
  }
}

/// Row with usage card and service radius card
class UsageCardWithRadiusRow extends StatelessWidget {
  final UsageCardData usageCard;
  final FeatureLimitsModel limits;
  final DeviceInfo deviceInfo;

  const UsageCardWithRadiusRow({
    super.key,
    required this.usageCard,
    required this.limits,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: UsageCard(data: usageCard, deviceInfo: deviceInfo),
        ),
        SizedBox(width: deviceInfo.isTablet ? 12 : 10),
        Expanded(
          child: ServiceRadiusCard(limits: limits, deviceInfo: deviceInfo),
        ),
      ],
    );
  }
}

/// Row of two media upload cards
class MediaUploadCardRow extends StatelessWidget {
  final MediaUploadCardData leftCard;
  final MediaUploadCardData rightCard;
  final DeviceInfo deviceInfo;

  const MediaUploadCardRow({
    super.key,
    required this.leftCard,
    required this.rightCard,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MediaUploadCard(data: leftCard, deviceInfo: deviceInfo),
        ),
        SizedBox(width: deviceInfo.isTablet ? 12 : 10),
        Expanded(
          child: MediaUploadCard(data: rightCard, deviceInfo: deviceInfo),
        ),
      ],
    );
  }
}

/// Data model for feature availability card
class FeatureAvailabilityData {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isAvailable;
  final Color color;

  const FeatureAvailabilityData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isAvailable,
    required this.color,
  });
}

/// Feature availability card (for boolean features like API Access, Priority Support)
class FeatureAvailabilityCard extends StatelessWidget {
  final FeatureAvailabilityData data;
  final DeviceInfo deviceInfo;

  const FeatureAvailabilityCard({
    super.key,
    required this.data,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final displayColor = data.isAvailable
        ? data.color
        : colorScheme.mutedForeground;

    return ShadCard(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  data.isAvailable ? data.icon : LucideIcons.lock,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: displayColor,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.p
                                  : theme.textTheme.small)
                              .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.subtitle,
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 12 : 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: data.isAvailable
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : colorScheme.destructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.isAvailable
                      ? LucideIcons.circleCheck
                      : LucideIcons.circleMinus,
                  size: 14,
                  color: data.isAvailable
                      ? const Color(0xFF10B981)
                      : colorScheme.destructive,
                ),
                SizedBox(width: 6),
                Text(
                  data.isAvailable ? 'Available' : 'Not Available',
                  style: theme.textTheme.small.copyWith(
                    color: data.isAvailable
                        ? const Color(0xFF10B981)
                        : colorScheme.destructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!data.isAvailable) ...[
            SizedBox(height: 6),
            Text(
              'Upgrade to unlock',
              style: theme.textTheme.muted.copyWith(
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Row of two feature availability cards
class FeatureAvailabilityRow extends StatelessWidget {
  final FeatureAvailabilityData leftCard;
  final FeatureAvailabilityData rightCard;
  final DeviceInfo deviceInfo;

  const FeatureAvailabilityRow({
    super.key,
    required this.leftCard,
    required this.rightCard,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FeatureAvailabilityCard(
            data: leftCard,
            deviceInfo: deviceInfo,
          ),
        ),
        SizedBox(width: deviceInfo.isTablet ? 12 : 10),
        Expanded(
          child: FeatureAvailabilityCard(
            data: rightCard,
            deviceInfo: deviceInfo,
          ),
        ),
      ],
    );
  }
}
