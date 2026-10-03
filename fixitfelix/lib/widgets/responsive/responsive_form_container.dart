import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';

/// A responsive container for form screens (signin, signup, onboarding, etc.)
/// Adapts layout for mobile, tablet portrait/landscape, and desktop
class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final Widget? logo;
  final String? title;
  final String? subtitle;
  final double mobileMaxWidth;
  final double tabletMaxWidth;
  final bool showCardOnMobile;
  final EdgeInsetsGeometry? customPadding;

  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.logo,
    this.title,
    this.subtitle,
    this.mobileMaxWidth = 400,
    this.tabletMaxWidth = 500,
    this.showCardOnMobile = true,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: customPadding ?? _getPadding(deviceInfo),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: _buildContent(context, deviceInfo, theme),
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _getPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return const EdgeInsets.all(48);
    }
    if (deviceInfo.isTablet) {
      return EdgeInsets.symmetric(
        horizontal: deviceInfo.isLandscape ? 48 : 32,
        vertical: deviceInfo.isLandscape ? 24 : 32,
      );
    }
    // Mobile
    return EdgeInsets.symmetric(
      horizontal: deviceInfo.isLandscape ? 32 : 24,
      vertical: deviceInfo.isLandscape ? 16 : 24,
    );
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return tabletMaxWidth;
    if (deviceInfo.isTablet) return tabletMaxWidth;
    return mobileMaxWidth;
  }

  Widget _buildContent(
    BuildContext context,
    DeviceInfo deviceInfo,
    ShadThemeData theme,
  ) {
    // On tablet landscape, show side-by-side layout
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Logo and info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (logo != null) ...[logo!, const SizedBox(height: 32)],
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.muted,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
          // Right side: Form
          Expanded(
            flex: 5,
            child: ShadCard(padding: const EdgeInsets.all(32), child: child),
          ),
        ],
      );
    }

    // Standard vertical layout
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (logo != null) ...[
          logo!,
          SizedBox(height: deviceInfo.isTablet ? 40 : 32),
        ],
        if (showCardOnMobile || deviceInfo.isTablet || deviceInfo.isDesktop)
          ShadCard(
            padding: EdgeInsets.all(deviceInfo.isTablet ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null &&
                    !(deviceInfo.isTablet && deviceInfo.isLandscape)) ...[
                  Text(title!, style: theme.textTheme.h2),
                  const SizedBox(height: 8),
                ],
                if (subtitle != null &&
                    !(deviceInfo.isTablet && deviceInfo.isLandscape)) ...[
                  Text(subtitle!, style: theme.textTheme.muted),
                  const SizedBox(height: 24),
                ],
                child,
              ],
            ),
          )
        else
          child,
      ],
    );
  }
}
