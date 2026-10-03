import 'package:flutter/widgets.dart';

import 'device_type.dart';

/// A builder widget that provides different layouts based on device type and orientation
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for mobile layout (required)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo) mobile;

  /// Builder for tablet layout (optional, falls back to mobile)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)? tablet;

  /// Builder for desktop layout (optional, falls back to tablet or mobile)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = DeviceInfo.of(context);

    switch (deviceInfo.type) {
      case DeviceType.desktop:
        return desktop?.call(context, deviceInfo) ??
            tablet?.call(context, deviceInfo) ??
            mobile(context, deviceInfo);
      case DeviceType.tablet:
        return tablet?.call(context, deviceInfo) ?? mobile(context, deviceInfo);
      case DeviceType.mobile:
        return mobile(context, deviceInfo);
    }
  }
}

/// A builder that provides different layouts based on orientation
class OrientationBuilder extends StatelessWidget {
  /// Builder for portrait layout
  final Widget Function(BuildContext context, DeviceInfo deviceInfo) portrait;

  /// Builder for landscape layout (optional, falls back to portrait)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)? landscape;

  const OrientationBuilder({super.key, required this.portrait, this.landscape});

  @override
  Widget build(BuildContext context) {
    final deviceInfo = DeviceInfo.of(context);

    if (deviceInfo.isLandscape && landscape != null) {
      return landscape!(context, deviceInfo);
    }
    return portrait(context, deviceInfo);
  }
}

/// A builder that provides different layouts based on both device type and orientation
class AdaptiveBuilder extends StatelessWidget {
  /// Mobile portrait layout (required)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)
  mobilePortrait;

  /// Mobile landscape layout
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)?
  mobileLandscape;

  /// Tablet portrait layout
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)?
  tabletPortrait;

  /// Tablet landscape layout
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)?
  tabletLandscape;

  /// Desktop layout (both orientations)
  final Widget Function(BuildContext context, DeviceInfo deviceInfo)? desktop;

  const AdaptiveBuilder({
    super.key,
    required this.mobilePortrait,
    this.mobileLandscape,
    this.tabletPortrait,
    this.tabletLandscape,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = DeviceInfo.of(context);

    switch (deviceInfo.type) {
      case DeviceType.desktop:
        return desktop?.call(context, deviceInfo) ??
            tabletLandscape?.call(context, deviceInfo) ??
            tabletPortrait?.call(context, deviceInfo) ??
            mobilePortrait(context, deviceInfo);

      case DeviceType.tablet:
        if (deviceInfo.isLandscape) {
          return tabletLandscape?.call(context, deviceInfo) ??
              tabletPortrait?.call(context, deviceInfo) ??
              mobileLandscape?.call(context, deviceInfo) ??
              mobilePortrait(context, deviceInfo);
        }
        return tabletPortrait?.call(context, deviceInfo) ??
            mobilePortrait(context, deviceInfo);

      case DeviceType.mobile:
        if (deviceInfo.isLandscape) {
          return mobileLandscape?.call(context, deviceInfo) ??
              mobilePortrait(context, deviceInfo);
        }
        return mobilePortrait(context, deviceInfo);
    }
  }
}

/// A simple responsive value selector
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({required this.mobile, this.tablet, this.desktop});

  T resolve(DeviceInfo deviceInfo) {
    switch (deviceInfo.type) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }

  static T of<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceInfo = DeviceInfo.of(context);
    return ResponsiveValue<T>(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    ).resolve(deviceInfo);
  }
}
