import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/responsive/responsive.dart';

/// Reusable profile card widget for displaying user profile information
class ProfileCard extends StatelessWidget {
  final String? name;
  final String? subtitle;
  final String? profileImageUrl;
  final String? initials;
  final bool isVerified;
  final List<String>? badges;
  final VoidCallback? onEditPressed;
  final DeviceInfo? deviceInfo;
  final Widget? trailing;

  const ProfileCard({
    super.key,
    this.name,
    this.subtitle,
    this.profileImageUrl,
    this.initials,
    this.isVerified = false,
    this.badges,
    this.onEditPressed,
    this.deviceInfo,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final device = deviceInfo ?? context.deviceInfo;
    final avatarSize = device.isTablet ? 72.0 : 56.0;

    final displayName = name?.isNotEmpty == true ? name! : 'User';
    final displayInitials = initials?.isNotEmpty == true
        ? initials!
        : _getInitials(displayName);

    return ShadCard(
      padding: EdgeInsets.all(device.isTablet ? 20 : 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ProfileAvatar(
                    imageUrl: profileImageUrl,
                    initials: displayInitials,
                    size: avatarSize,
                    deviceInfo: device,
                  ),
                  if (isVerified)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _buildVerifiedBadge(colorScheme, device),
                    ),
                ],
              ),
              SizedBox(width: device.isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style:
                          (device.isTablet
                                  ? theme.textTheme.h3
                                  : theme.textTheme.large)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (badges != null && badges!.isNotEmpty) ...[
                      SizedBox(height: device.isTablet ? 8 : 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: badges!.map((badge) {
                          return _buildBadge(badge, theme, colorScheme);
                        }).toList(),
                      ),
                    ],
                    if (subtitle != null) ...[
                      SizedBox(height: device.isTablet ? 6 : 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.muted.copyWith(
                          fontSize: device.isTablet ? 13 : 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onEditPressed != null)
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: onEditPressed,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.pencil,
                        size: 14,
                        color: colorScheme.foreground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge(ShadColorScheme colorScheme, DeviceInfo device) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.background, width: 2),
      ),
      child: Icon(
        LucideIcons.check,
        size: device.isTablet ? 12 : 10,
        color: colorScheme.primaryForeground,
      ),
    );
  }

  Widget _buildBadge(
    String text,
    ShadThemeData theme,
    ShadColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _capitalize(text),
        style: theme.textTheme.small.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

/// Reusable avatar component
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final DeviceInfo? deviceInfo;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 56,
    this.deviceInfo,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: colorScheme.muted,
            highlightColor: colorScheme.background,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colorScheme.muted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          errorWidget: (context, url, error) =>
              _buildInitialsAvatar(theme, colorScheme),
        ),
      );
    }
    return _buildInitialsAvatar(theme, colorScheme);
  }

  Widget _buildInitialsAvatar(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: theme.textTheme.large.copyWith(
            color: colorScheme.primaryForeground,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}

/// Contact information row
class ContactInfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final DeviceInfo? deviceInfo;

  const ContactInfoRow({
    super.key,
    required this.icon,
    required this.value,
    this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: colorScheme.mutedForeground),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.small.copyWith(
            color: colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
