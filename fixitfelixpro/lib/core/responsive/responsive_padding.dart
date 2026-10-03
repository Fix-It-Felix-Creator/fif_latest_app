import 'package:flutter/widgets.dart';

import 'responsive_extensions.dart';

/// Provides responsive padding values based on device type and orientation
class ResponsivePadding {
  ResponsivePadding._();

  /// Get horizontal page padding
  static double horizontal(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) {
      return 64;
    }

    if (deviceInfo.isTablet) {
      return deviceInfo.isLandscape ? 48 : 32;
    }

    // Mobile
    return deviceInfo.isLandscape ? 24 : 16;
  }

  /// Get vertical page padding
  static double vertical(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) {
      return 32;
    }

    if (deviceInfo.isTablet) {
      return 24;
    }

    // Mobile
    return 16;
  }

  /// Get symmetric page padding
  static EdgeInsets page(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: horizontal(context),
      vertical: vertical(context),
    );
  }

  /// Get content padding (smaller than page padding)
  static EdgeInsets content(BuildContext context) {
    final h = horizontal(context) * 0.75;
    final v = vertical(context) * 0.75;

    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// Get card padding
  static EdgeInsets card(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) {
      return const EdgeInsets.all(24);
    }

    if (deviceInfo.isTablet) {
      return const EdgeInsets.all(20);
    }

    return const EdgeInsets.all(16);
  }

  /// Get list item padding
  static EdgeInsets listItem(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }

    if (deviceInfo.isTablet) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    }

    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  /// Get button padding
  static EdgeInsets button(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }

    if (deviceInfo.isTablet) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 14);
    }

    return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  }

  /// Get form field spacing
  static double formSpacing(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) return 24;
    if (deviceInfo.isTablet) return 20;
    return 16;
  }

  /// Get section spacing
  static double sectionSpacing(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) return 48;
    if (deviceInfo.isTablet) return 40;
    return 32;
  }

  /// Get item spacing (between list items, grid items, etc.)
  static double itemSpacing(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    if (deviceInfo.isDesktop) return 16;
    if (deviceInfo.isTablet) return 14;
    return 12;
  }
}

/// A widget that applies responsive padding
class ResponsivePaddingWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets? customPadding;
  final ResponsivePaddingType type;

  const ResponsivePaddingWidget({
    super.key,
    required this.child,
    this.customPadding,
    this.type = ResponsivePaddingType.page,
  });

  @override
  Widget build(BuildContext context) {
    final padding = customPadding ?? _getPadding(context);
    return Padding(padding: padding, child: child);
  }

  EdgeInsets _getPadding(BuildContext context) {
    switch (type) {
      case ResponsivePaddingType.page:
        return ResponsivePadding.page(context);
      case ResponsivePaddingType.content:
        return ResponsivePadding.content(context);
      case ResponsivePaddingType.card:
        return ResponsivePadding.card(context);
      case ResponsivePaddingType.listItem:
        return ResponsivePadding.listItem(context);
    }
  }
}

enum ResponsivePaddingType { page, content, card, listItem }
