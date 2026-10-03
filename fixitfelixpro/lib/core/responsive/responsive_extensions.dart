import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'device_type.dart';

/// Extension on BuildContext for responsive utilities
extension ResponsiveContext on BuildContext {
  /// Get device info for the current context
  DeviceInfo get deviceInfo => DeviceInfo.of(this);

  /// Get screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Get shortest side (useful for orientation-independent sizing)
  double get shortestSide => MediaQuery.of(this).size.shortestSide;

  /// Get longest side
  double get longestSide => MediaQuery.of(this).size.longestSide;

  /// Check if device is mobile
  bool get isMobile => deviceInfo.isMobile;

  /// Check if device is tablet
  bool get isTablet => deviceInfo.isTablet;

  /// Check if device is desktop
  bool get isDesktop => deviceInfo.isDesktop;

  /// Check if orientation is portrait
  bool get isPortrait => deviceInfo.isPortrait;

  /// Check if orientation is landscape
  bool get isLandscape => deviceInfo.isLandscape;

  /// Get responsive value based on device type
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    final info = deviceInfo;
    switch (info.type) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }

  /// Get responsive value based on orientation
  T orientationValue<T>({required T portrait, T? landscape}) {
    return isLandscape ? (landscape ?? portrait) : portrait;
  }

  /// Get max content width based on device type
  double get maxContentWidth {
    if (isDesktop) return ResponsiveBreakpoints.maxContentWidthDesktop;
    if (isTablet) return ResponsiveBreakpoints.maxContentWidthTablet;
    return ResponsiveBreakpoints.maxContentWidthMobile;
  }

  /// Get number of grid columns based on device type
  int get gridColumns {
    if (isDesktop) return ResponsiveBreakpoints.desktopColumns;
    if (isTablet) return ResponsiveBreakpoints.tabletColumns;
    return ResponsiveBreakpoints.mobileColumns;
  }

  /// Get spacing multiplier based on device type
  double get spacingMultiplier {
    if (isDesktop) return 1.5;
    if (isTablet) return 1.25;
    return 1.0;
  }

  /// Get adaptive padding
  EdgeInsets get adaptivePadding {
    if (isTablet) {
      return EdgeInsets.symmetric(
        horizontal: isLandscape ? 48 : 32,
        vertical: 24,
      );
    }
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 64, vertical: 32);
    }
    return EdgeInsets.symmetric(
      horizontal: isLandscape ? 24 : 16,
      vertical: 16,
    );
  }

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;
}

/// Extension on num for responsive sizing
extension ResponsiveNum on num {
  /// Convert to responsive width percentage
  double w(BuildContext context) => context.screenWidth * (this / 100);

  /// Convert to responsive height percentage
  double h(BuildContext context) => context.screenHeight * (this / 100);

  /// Convert to shortest side percentage (orientation independent)
  double sp(BuildContext context) => context.shortestSide * (this / 100);

  /// Scale value based on device type
  double scaled(BuildContext context) => toDouble() * context.spacingMultiplier;
}

/// Extension for responsive EdgeInsets
extension ResponsiveEdgeInsets on EdgeInsets {
  /// Scale padding based on device type
  EdgeInsets scaled(BuildContext context) {
    final multiplier = context.spacingMultiplier;
    return EdgeInsets.only(
      left: left * multiplier,
      top: top * multiplier,
      right: right * multiplier,
      bottom: bottom * multiplier,
    );
  }
}

/// Extension for responsive SizedBox
extension ResponsiveSizedBox on SizedBox {
  /// Create a responsive sized box that scales with device type
  static SizedBox responsive(
    BuildContext context, {
    double? width,
    double? height,
  }) {
    final multiplier = context.spacingMultiplier;
    return SizedBox(
      width: width != null ? width * multiplier : null,
      height: height != null ? height * multiplier : null,
    );
  }
}
