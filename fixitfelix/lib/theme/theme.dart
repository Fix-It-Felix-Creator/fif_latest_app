import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'custom_color_scheme.dart';

/// App Theme Configuration
///
/// Custom color scheme based on seed color: RGB(246, 76, 19)
/// Font: Montserrat (via Google Fonts)

class AppTheme {
  // Custom FixItFelix color scheme
  // static const ShadColorScheme lightColorScheme = ShadOrangeColorScheme.light();
  // static const ShadColorScheme darkColorScheme = ShadOrangeColorScheme.dark();
  static const ShadColorScheme lightColorScheme = FixItFelixColorScheme.light;
  static const ShadColorScheme darkColorScheme = FixItFelixColorScheme.dark;

  // Text theme with Montserrat font (medium weight for a bolder feel)
  static TextStyle _montserratMedium({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final baseWeight =
        fontWeight ?? textStyle?.fontWeight ?? FontWeight.w400;
    final bumped = baseWeight.index < FontWeight.w500.index
        ? FontWeight.w500
        : baseWeight;
    return GoogleFonts.montserrat(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: bumped,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static final ShadTextTheme textTheme =
      ShadTextTheme.fromGoogleFont(_montserratMedium);

  // Toast theme configuration
  static const ShadToastTheme toastTheme = ShadToastTheme(
    alignment: Alignment.topRight,
    showCloseIconOnlyWhenHovered: false,
  );

  static ShadThemeData light() {
    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      textTheme: textTheme,
      primaryToastTheme: toastTheme,
      destructiveToastTheme: toastTheme,
    );
  }

  static ShadThemeData dark() {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      textTheme: textTheme,
      primaryToastTheme: toastTheme,
      destructiveToastTheme: toastTheme,
    );
  }
}

/// Available Color Schemes (uncomment to use):
///
/// ShadBlueColorScheme.light() / .dark()
/// ShadGrayColorScheme.light() / .dark()
/// ShadGreenColorScheme.light() / .dark()
/// ShadNeutralColorScheme.light() / .dark()
/// ShadOrangeColorScheme.light() / .dark()
/// ShadRedColorScheme.light() / .dark()
/// ShadRoseColorScheme.light() / .dark()
/// ShadSlateColorScheme.light() / .dark()
/// ShadStoneColorScheme.light() / .dark()
/// ShadVioletColorScheme.light() / .dark()
/// ShadYellowColorScheme.light() / .dark()
/// ShadZincColorScheme.light() / .dark()

/// To change font, replace GoogleFonts.montserrat with:
/// GoogleFonts.inter
/// GoogleFonts.roboto
/// GoogleFonts.poppins
/// GoogleFonts.openSans
/// GoogleFonts.lato
/// etc.
