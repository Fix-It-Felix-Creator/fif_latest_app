import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Custom Color Scheme for FixItFelix Pro Design System
/// Seed Color: RGB(246, 76, 19) - #F64C13
///
/// This file contains custom light and dark color schemes
/// based on the brand's primary orange color.

class FixItFelixColorScheme {
  // Seed color
  static const Color seedColor = Color.fromRGBO(246, 76, 19, 1);

  // Primary color variations
  static const Color primaryLight = Color(0xFFF64C13);
  static const Color primaryDark = Color(0xFFFF6B3D);

  // Light theme colors
  static const ShadColorScheme light = ShadColorScheme(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0A0A0A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0A0A0A),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF0A0A0A),
    primary: Color(0xFFF64C13),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFF0EB),
    secondaryForeground: Color(0xFFB33D0F),
    muted: Color(0xFFF5F5F5),
    mutedForeground: Color(0xFF737373),
    accent: Color(0xFFFFF0EB),
    accentForeground: Color(0xFFB33D0F),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFAFAFA),
    border: Color(0xFFE5E5E5),
    input: Color(0xFFE5E5E5),
    ring: Color(0xFFF64C13),
    selection: Color(0xFFFED7C7),
  );

  // Dark theme colors
  static const ShadColorScheme dark = ShadColorScheme(
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF0A0A0A),
    cardForeground: Color(0xFFFAFAFA),
    popover: Color(0xFF0A0A0A),
    popoverForeground: Color(0xFFFAFAFA),
    primary: Color(0xFFFF6B3D),
    primaryForeground: Color(0xFF1A0A05),
    secondary: Color(0xFF2D1810),
    secondaryForeground: Color(0xFFFFB699),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA3A3A3),
    accent: Color(0xFF2D1810),
    accentForeground: Color(0xFFFFB699),
    destructive: Color(0xFF7F1D1D),
    destructiveForeground: Color(0xFFFAFAFA),
    border: Color(0xFF262626),
    input: Color(0xFF262626),
    ring: Color(0xFFFF6B3D),
    selection: Color(0xFF5C2410),
  );
}
