import 'package:flutter/material.dart';

import '../responsive/responsive.dart';

/// Mixin providing common responsive helpers for screens
/// Use this to avoid duplicating max width and padding calculations
mixin ResponsiveHelpersMixin {
  /// Get max width for form/content screens
  /// Desktop: 600, Tablet: 550, Mobile: 500
  double getFormMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 600;
    if (deviceInfo.isTablet) return 550;
    return 500;
  }

  /// Get max width for settings/list screens
  /// Desktop: 700, Tablet: 600, Mobile: double.infinity
  double getSettingsMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 700;
    if (deviceInfo.isTablet) return 600;
    return double.infinity;
  }

  /// Get max width for detail screens
  /// Desktop: 800, Tablet: 700, Mobile: double.infinity
  double getDetailMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 800;
    if (deviceInfo.isTablet) return 700;
    return double.infinity;
  }

  /// Get max width for auth/onboarding screens
  /// Desktop: 500, Tablet: 450, Mobile: 400
  double getAuthMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 500;
    if (deviceInfo.isTablet) return 450;
    return 400;
  }

  /// Get content padding for form screens
  /// Desktop: 28, Tablet: 24, Mobile: 20
  EdgeInsets getFormPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(28);
    if (deviceInfo.isTablet) return const EdgeInsets.all(24);
    return const EdgeInsets.all(20);
  }

  /// Get content padding for auth/onboarding screens
  /// Desktop: 32, Tablet: 28, Mobile: 24
  EdgeInsets getAuthPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(32);
    if (deviceInfo.isTablet) return const EdgeInsets.all(28);
    return const EdgeInsets.all(24);
  }

  /// Get horizontal padding for list screens
  /// Tablet: 24, Mobile: 16
  EdgeInsets getListHorizontalPadding(DeviceInfo deviceInfo) {
    return EdgeInsets.symmetric(horizontal: deviceInfo.isTablet ? 24 : 16);
  }

  /// Get spacing between sections
  /// Tablet: 24, Mobile: 20
  double getSectionSpacing(DeviceInfo deviceInfo) {
    return deviceInfo.isTablet ? 24 : 20;
  }

  /// Get spacing between items
  /// Tablet: 16, Mobile: 12
  double getItemSpacing(DeviceInfo deviceInfo) {
    return deviceInfo.isTablet ? 16 : 12;
  }

  /// Get icon size
  /// Tablet: 24, Mobile: 20
  double getIconSize(DeviceInfo deviceInfo) {
    return deviceInfo.isTablet ? 24 : 20;
  }

  /// Get small icon size
  /// Tablet: 20, Mobile: 18
  double getSmallIconSize(DeviceInfo deviceInfo) {
    return deviceInfo.isTablet ? 20 : 18;
  }
}

/// Mixin providing common text utilities
mixin TextHelpersMixin {
  /// Capitalize first letter of a string
  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Capitalize first letter of each word
  String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// Get initials from a name (first letter of first and last name)
  String getInitials(String? firstName, String? lastName) {
    final first = firstName?.isNotEmpty == true
        ? firstName![0].toUpperCase()
        : '';
    final last = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    return '$first$last';
  }

  /// Get full name from first and last name
  String getFullName(String? firstName, String? lastName) {
    final parts = <String>[];
    if (firstName?.isNotEmpty == true) parts.add(firstName!);
    if (lastName?.isNotEmpty == true) parts.add(lastName!);
    return parts.join(' ');
  }

  /// Truncate text with ellipsis
  String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// Mixin providing common user data getters from AuthBloc
mixin UserDataHelpersMixin {
  /// Get customer/user display name from context
  String getDisplayName(String? firstName, String? lastName, String? email) {
    if (firstName != null && firstName.isNotEmpty) {
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName;
    }
    return email ?? 'User';
  }

  /// Get formatted location string
  String getFormattedLocation(String? city, String? postcode) {
    final parts = <String>[];
    if (city?.isNotEmpty == true) parts.add(city!);
    if (postcode?.isNotEmpty == true) parts.add(postcode!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not set';
  }
}
