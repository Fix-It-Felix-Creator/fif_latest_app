import 'package:flutter/widgets.dart';

import 'device_type.dart';
import 'responsive_extensions.dart';

/// Provides responsive text sizing based on device type
class ResponsiveText {
  ResponsiveText._();

  /// Base font size multiplier
  static double _getMultiplier(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 1.15;
    if (deviceInfo.isTablet) return 1.1;
    return 1.0;
  }

  /// Get responsive font size
  static double fontSize(BuildContext context, double baseSize) {
    final deviceInfo = context.deviceInfo;
    return baseSize * _getMultiplier(deviceInfo);
  }

  /// Display large (like hero text)
  static double displayLarge(BuildContext context) {
    return fontSize(context, 57);
  }

  /// Display medium
  static double displayMedium(BuildContext context) {
    return fontSize(context, 45);
  }

  /// Display small
  static double displaySmall(BuildContext context) {
    return fontSize(context, 36);
  }

  /// Headline large
  static double headlineLarge(BuildContext context) {
    return fontSize(context, 32);
  }

  /// Headline medium
  static double headlineMedium(BuildContext context) {
    return fontSize(context, 28);
  }

  /// Headline small
  static double headlineSmall(BuildContext context) {
    return fontSize(context, 24);
  }

  /// Title large
  static double titleLarge(BuildContext context) {
    return fontSize(context, 22);
  }

  /// Title medium
  static double titleMedium(BuildContext context) {
    return fontSize(context, 16);
  }

  /// Title small
  static double titleSmall(BuildContext context) {
    return fontSize(context, 14);
  }

  /// Body large
  static double bodyLarge(BuildContext context) {
    return fontSize(context, 16);
  }

  /// Body medium
  static double bodyMedium(BuildContext context) {
    return fontSize(context, 14);
  }

  /// Body small
  static double bodySmall(BuildContext context) {
    return fontSize(context, 12);
  }

  /// Label large
  static double labelLarge(BuildContext context) {
    return fontSize(context, 14);
  }

  /// Label medium
  static double labelMedium(BuildContext context) {
    return fontSize(context, 12);
  }

  /// Label small
  static double labelSmall(BuildContext context) {
    return fontSize(context, 11);
  }

  /// Get max lines based on available space
  static int maxLines(BuildContext context, {int defaultLines = 2}) {
    final deviceInfo = context.deviceInfo;
    if (deviceInfo.isDesktop) return defaultLines + 2;
    if (deviceInfo.isTablet) return defaultLines + 1;
    return defaultLines;
  }
}

/// Extension for responsive text styling
extension ResponsiveTextStyle on TextStyle {
  /// Scale the font size responsively
  TextStyle responsive(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    double multiplier;

    if (deviceInfo.isDesktop) {
      multiplier = 1.15;
    } else if (deviceInfo.isTablet) {
      multiplier = 1.1;
    } else {
      multiplier = 1.0;
    }

    return copyWith(fontSize: (fontSize ?? 14) * multiplier);
  }
}
