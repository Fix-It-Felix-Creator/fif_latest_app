/// Responsive breakpoints for different device sizes
///
/// These breakpoints are based on common device widths and are designed
/// to work well with both portrait and landscape orientations.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  // Width breakpoints
  static const double mobileSmall = 320;
  static const double mobileMedium = 375;
  static const double mobileLarge = 414;
  static const double mobileMax = 599;

  static const double tabletMin = 600;
  static const double tabletMedium = 768;
  static const double tabletLarge = 900;
  static const double tabletMax = 1023;

  static const double desktopMin = 1024;
  static const double desktopMedium = 1280;
  static const double desktopLarge = 1440;
  static const double desktopMax = 1920;

  // Height breakpoints (for landscape considerations)
  static const double heightSmall = 568; // iPhone SE landscape
  static const double heightMedium = 667; // iPhone 8
  static const double heightLarge = 812; // iPhone X+
  static const double heightXLarge = 1024; // iPad

  // Content max widths
  static const double maxContentWidthMobile = 600;
  static const double maxContentWidthTablet = 800;
  static const double maxContentWidthDesktop = 1200;

  // Grid columns
  static const int mobileColumns = 4;
  static const int tabletColumns = 8;
  static const int desktopColumns = 12;

  // Common spacing values based on device type
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;
}

/// Spacing multipliers for different device sizes
class ResponsiveSpacing {
  ResponsiveSpacing._();

  static const double mobileMultiplier = 1.0;
  static const double tabletMultiplier = 1.25;
  static const double desktopMultiplier = 1.5;
}
