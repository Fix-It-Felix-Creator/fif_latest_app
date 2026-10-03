import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Represents the type of device based on screen width
enum DeviceType { mobile, tablet, desktop }

/// Represents the screen orientation
enum ScreenOrientation { portrait, landscape }

/// Device information including type and orientation
class DeviceInfo {
  final DeviceType type;
  final ScreenOrientation orientation;
  final double width;
  final double height;
  final double shortestSide;
  final double longestSide;
  final double pixelRatio;
  final bool isSmallMobile;
  final bool isLargeMobile;
  final bool isSmallTablet;
  final bool isLargeTablet;

  const DeviceInfo({
    required this.type,
    required this.orientation,
    required this.width,
    required this.height,
    required this.shortestSide,
    required this.longestSide,
    required this.pixelRatio,
    required this.isSmallMobile,
    required this.isLargeMobile,
    required this.isSmallTablet,
    required this.isLargeTablet,
  });

  bool get isMobile => type == DeviceType.mobile;
  bool get isTablet => type == DeviceType.tablet;
  bool get isDesktop => type == DeviceType.desktop;
  bool get isPortrait => orientation == ScreenOrientation.portrait;
  bool get isLandscape => orientation == ScreenOrientation.landscape;

  /// Factory constructor from MediaQueryData
  factory DeviceInfo.fromMediaQuery(MediaQueryData mediaQuery) {
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final shortestSide = mediaQuery.size.shortestSide;
    final longestSide = mediaQuery.size.longestSide;
    final pixelRatio = mediaQuery.devicePixelRatio;

    // Determine orientation
    final orientation = width > height
        ? ScreenOrientation.landscape
        : ScreenOrientation.portrait;

    // Determine device type based on shortest side (works for both orientations)
    DeviceType type;
    if (shortestSide < ResponsiveBreakpoints.tabletMin) {
      type = DeviceType.mobile;
    } else if (shortestSide < ResponsiveBreakpoints.desktopMin) {
      type = DeviceType.tablet;
    } else {
      type = DeviceType.desktop;
    }

    // Determine sub-categories
    final isSmallMobile = shortestSide <= ResponsiveBreakpoints.mobileSmall;
    final isLargeMobile =
        shortestSide > ResponsiveBreakpoints.mobileLarge &&
        shortestSide < ResponsiveBreakpoints.tabletMin;
    final isSmallTablet =
        shortestSide >= ResponsiveBreakpoints.tabletMin &&
        shortestSide < ResponsiveBreakpoints.tabletMedium;
    final isLargeTablet =
        shortestSide >= ResponsiveBreakpoints.tabletMedium &&
        shortestSide < ResponsiveBreakpoints.desktopMin;

    return DeviceInfo(
      type: type,
      orientation: orientation,
      width: width,
      height: height,
      shortestSide: shortestSide,
      longestSide: longestSide,
      pixelRatio: pixelRatio,
      isSmallMobile: isSmallMobile,
      isLargeMobile: isLargeMobile,
      isSmallTablet: isSmallTablet,
      isLargeTablet: isLargeTablet,
    );
  }

  /// Factory constructor from BuildContext
  factory DeviceInfo.of(BuildContext context) {
    return DeviceInfo.fromMediaQuery(MediaQuery.of(context));
  }

  @override
  String toString() {
    return 'DeviceInfo(type: $type, orientation: $orientation, width: $width, height: $height)';
  }
}
