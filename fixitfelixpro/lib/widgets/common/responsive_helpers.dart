import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';

/// Mixin providing common responsive sizing methods used across screens
mixin ResponsiveHelpersMixin {
  /// Get max content width based on device type
  double getMaxWidth(DeviceInfo deviceInfo, {ScreenSizeCategory? category}) {
    final cat = category ?? ScreenSizeCategory.medium;
    switch (cat) {
      case ScreenSizeCategory.small:
        if (deviceInfo.isDesktop) return 500;
        if (deviceInfo.isTablet) return 450;
        return 400;
      case ScreenSizeCategory.medium:
        if (deviceInfo.isDesktop) return 600;
        if (deviceInfo.isTablet) return 550;
        return 500;
      case ScreenSizeCategory.large:
        if (deviceInfo.isDesktop) return 700;
        if (deviceInfo.isTablet) return 650;
        return 600;
      case ScreenSizeCategory.extraLarge:
        if (deviceInfo.isDesktop) return 1000;
        if (deviceInfo.isTablet) return 800;
        return double.infinity;
    }
  }

  /// Get content padding based on device type
  EdgeInsets getContentPadding(DeviceInfo deviceInfo, {PaddingSize? size}) {
    final paddingSize = size ?? PaddingSize.medium;
    switch (paddingSize) {
      case PaddingSize.small:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(20);
        if (deviceInfo.isTablet) return const EdgeInsets.all(16);
        return const EdgeInsets.all(12);
      case PaddingSize.medium:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(28);
        if (deviceInfo.isTablet) return const EdgeInsets.all(24);
        return const EdgeInsets.all(20);
      case PaddingSize.large:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(32);
        if (deviceInfo.isTablet) return const EdgeInsets.all(28);
        return const EdgeInsets.all(24);
    }
  }

  /// Get responsive padding for home/profile screens
  EdgeInsets getResponsivePadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (deviceInfo.isTablet) {
      return const EdgeInsets.all(28);
    }
    return const EdgeInsets.all(20);
  }

  /// Get max content width for home/profile screens
  double getMaxContentWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 1000;
    if (deviceInfo.isTablet) return 800;
    return double.infinity;
  }
}

/// Screen size categories for max width calculation
enum ScreenSizeCategory { small, medium, large, extraLarge }

/// Padding size categories
enum PaddingSize { small, medium, large }

/// Static helper class for responsive sizing (for use outside mixins)
class ResponsiveHelpers {
  ResponsiveHelpers._();

  static double getMaxWidth(
    DeviceInfo deviceInfo, {
    ScreenSizeCategory? category,
  }) {
    final cat = category ?? ScreenSizeCategory.medium;
    switch (cat) {
      case ScreenSizeCategory.small:
        if (deviceInfo.isDesktop) return 500;
        if (deviceInfo.isTablet) return 450;
        return 400;
      case ScreenSizeCategory.medium:
        if (deviceInfo.isDesktop) return 600;
        if (deviceInfo.isTablet) return 550;
        return 500;
      case ScreenSizeCategory.large:
        if (deviceInfo.isDesktop) return 700;
        if (deviceInfo.isTablet) return 650;
        return 600;
      case ScreenSizeCategory.extraLarge:
        if (deviceInfo.isDesktop) return 1000;
        if (deviceInfo.isTablet) return 800;
        return double.infinity;
    }
  }

  static EdgeInsets getContentPadding(
    DeviceInfo deviceInfo, {
    PaddingSize? size,
  }) {
    final paddingSize = size ?? PaddingSize.medium;
    switch (paddingSize) {
      case PaddingSize.small:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(20);
        if (deviceInfo.isTablet) return const EdgeInsets.all(16);
        return const EdgeInsets.all(12);
      case PaddingSize.medium:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(28);
        if (deviceInfo.isTablet) return const EdgeInsets.all(24);
        return const EdgeInsets.all(20);
      case PaddingSize.large:
        if (deviceInfo.isDesktop) return const EdgeInsets.all(32);
        if (deviceInfo.isTablet) return const EdgeInsets.all(28);
        return const EdgeInsets.all(24);
    }
  }

  static EdgeInsets getResponsivePadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (deviceInfo.isTablet) {
      return const EdgeInsets.all(28);
    }
    return const EdgeInsets.all(20);
  }

  static double getMaxContentWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 1000;
    if (deviceInfo.isTablet) return 800;
    return double.infinity;
  }
}
