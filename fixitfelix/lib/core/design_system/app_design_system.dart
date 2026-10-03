import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../responsive/responsive.dart';

/// Modern Design System Constants
///
/// This file contains all reusable design tokens and components
/// for the FixItFelix app's glassmorphism UI design system.

// =============================================================================
// COLOR PALETTE
// =============================================================================

class AppColors {
  AppColors._();

  // Primary gradient colors
  static const Color primaryIndigo = Color(0xFF6366F1);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryPink = Color(0xFFEC4899);

  // Accent colors
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentYellow = Color(0xFFFBBF24);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentDarkRed = Color(0xFFDC2626);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF2563EB);

  // Premium/Gold colors
  static const Color premium = Color(0xFFF59E0B);
  static const Color premiumDark = Color(0xFFEAB308);

  // Dark mode background hints
  static const Color darkBgPrimary = Color(0xFF1E1B4B);
  static const Color darkBgSecondary = Color(0xFF312E81);

  // Light mode background hints
  static const Color lightBgPrimary = Color(0xFFEEF2FF);
  static const Color lightBgSecondary = Color(0xFFE0E7FF);
}

// =============================================================================
// GRADIENTS
// =============================================================================

class AppGradients {
  AppGradients._();

  // Primary gradients
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryIndigo, AppColors.primaryPurple],
  );

  static const LinearGradient primaryExtended = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primaryIndigo,
      AppColors.primaryPurple,
      AppColors.primaryPink,
    ],
  );

  static const LinearGradient success = LinearGradient(
    colors: [AppColors.success, AppColors.successDark],
  );

  static const LinearGradient warning = LinearGradient(
    colors: [AppColors.warning, AppColors.warningDark],
  );

  static const LinearGradient error = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.error, AppColors.errorDark],
  );

  static const LinearGradient premium = LinearGradient(
    colors: [AppColors.premium, AppColors.premiumDark],
  );

  // Glass gradients
  static LinearGradient glassLight({
    double startAlpha = 0.9,
    double endAlpha = 0.7,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: startAlpha),
        Colors.white.withValues(alpha: endAlpha),
      ],
    );
  }

  static LinearGradient glassDark({
    double startAlpha = 0.1,
    double endAlpha = 0.05,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: startAlpha),
        Colors.white.withValues(alpha: endAlpha),
      ],
    );
  }

  static LinearGradient glass(
    bool isDark, {
    double? startAlpha,
    double? endAlpha,
  }) {
    if (isDark) {
      return glassDark(
        startAlpha: startAlpha ?? 0.1,
        endAlpha: endAlpha ?? 0.05,
      );
    }
    return glassLight(startAlpha: startAlpha ?? 0.9, endAlpha: endAlpha ?? 0.7);
  }

  // Icon container gradients
  static LinearGradient iconContainer(Color color) {
    return LinearGradient(
      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
    );
  }
}

// =============================================================================
// SHADOWS
// =============================================================================

class AppShadows {
  AppShadows._();

  static List<BoxShadow> glow(
    Color color, {
    double blur = 16,
    double spread = 0,
    Offset offset = const Offset(0, 6),
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
    ];
  }

  static List<BoxShadow> glowLarge(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.5),
        blurRadius: 30,
        spreadRadius: 2,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> card(bool isDark) {
    return [
      BoxShadow(
        color: AppColors.primaryIndigo.withValues(alpha: isDark ? 0.1 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> elevated(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// =============================================================================
// BORDERS
// =============================================================================

class AppBorders {
  AppBorders._();

  static Border glass(bool isDark) {
    return Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.5),
    );
  }

  static Border glassSubtle(bool isDark) {
    return Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.3),
    );
  }

  static Border accent(Color color, {double alpha = 0.3}) {
    return Border.all(color: color.withValues(alpha: alpha));
  }

  static Border bottom(bool isDark) {
    return Border(
      bottom: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.5),
        width: 1,
      ),
    );
  }
}

// =============================================================================
// BORDER RADIUS
// =============================================================================

class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 14.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double xxxl = 24.0;
  static const double card = 20.0;
  static const double button = 14.0;
  static const double input = 14.0;
  static const double pill = 25.0;

  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

// =============================================================================
// SPACING
// =============================================================================

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  static EdgeInsets all(double value) => EdgeInsets.all(value);
  static EdgeInsets horizontal(double value) =>
      EdgeInsets.symmetric(horizontal: value);
  static EdgeInsets vertical(double value) =>
      EdgeInsets.symmetric(vertical: value);
  static EdgeInsets symmetric({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: h, vertical: v);
}

// =============================================================================
// GLASS CARD WIDGET
// =============================================================================

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Color? accentColor;
  final bool enableBlur;
  final double blurAmount;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.card,
    this.accentColor,
    this.enableBlur = true,
    this.blurAmount = 10,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colorScheme.border),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

// =============================================================================
// GLASS APP BAR
// =============================================================================

class GlassAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final DeviceInfo deviceInfo;
  final bool showBackButton;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    required this.deviceInfo,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: deviceInfo.isTablet ? 20 : 16,
        vertical: deviceInfo.isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.card,
        border: Border(bottom: BorderSide(color: colorScheme.border)),
      ),
      child: Row(
        children: [
          if (showBackButton)
            GlassIconButton(
              icon: LucideIcons.chevronLeft,
              onTap: onBack ?? () => Navigator.maybePop(context),
              size: deviceInfo.isTablet ? 44 : 40,
            ),
          if (showBackButton) SizedBox(width: deviceInfo.isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  title,
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h3
                              : theme.textTheme.h4)
                          .copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.small.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// =============================================================================
// GLASS ICON BUTTON
// =============================================================================

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;
  final bool useGradient;
  final List<Color>? gradientColors;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconColor,
    this.useGradient = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      gradientColors ??
                      [AppColors.primaryIndigo, AppColors.primaryPurple],
                )
              : null,
          color: useGradient ? null : colorScheme.muted,
          borderRadius: BorderRadius.circular(12),
          border: useGradient ? null : Border.all(color: colorScheme.border),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: useGradient
              ? Colors.white
              : (iconColor ?? colorScheme.foreground),
        ),
      ),
    );
  }
}

// =============================================================================
// GRADIENT BUTTON
// =============================================================================

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final List<Color>? gradientColors;
  final double? height;
  final EdgeInsets? padding;

  const GradientButton({
    super.key,
    required this.text,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.gradientColors,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        gradientColors ?? [AppColors.primaryIndigo, AppColors.primaryPurple];

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: height,
        padding:
            padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: AppRadius.buttonRadius,
          boxShadow: AppShadows.glow(colors.first),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GLASS INPUT FIELD
// =============================================================================

class GlassInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final int maxLines;

  const GlassInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.keyboardType,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: colorScheme.muted,
            borderRadius: AppRadius.inputRadius,
            border: Border.all(
              color: errorText != null
                  ? AppColors.error.withValues(alpha: 0.5)
                  : colorScheme.border,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            enabled: enabled,
            maxLines: maxLines,
            style: theme.textTheme.p.copyWith(color: colorScheme.foreground),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.p.copyWith(
                color: colorScheme.mutedForeground,
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.small.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// GLASS SEARCH BAR
// =============================================================================

class GlassSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final double? height;

  const GlassSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onChanged,
    this.onClear,
    this.controller,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: height ?? 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.muted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryIndigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.search,
              size: 18,
              color: AppColors.primaryIndigo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.p.copyWith(color: colorScheme.foreground),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.p.copyWith(
                  color: colorScheme.mutedForeground,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (controller?.text.isNotEmpty ?? false)
            GestureDetector(
              onTap: () {
                controller?.clear();
                onClear?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// GRADIENT TEXT
// =============================================================================

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color>? colors;

  const GradientText(this.text, {super.key, this.style, this.colors});

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        colors ?? [AppColors.primaryIndigo, AppColors.primaryPurple];

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: gradientColors).createShader(bounds),
      child: Text(text, style: style),
    );
  }
}

// =============================================================================
// ICON CONTAINER
// =============================================================================

class IconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool withBorder;
  final bool withGlow;

  const IconContainer({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize = 20,
    this.withBorder = true,
    this.withGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.iconContainer(color),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: withBorder ? AppBorders.accent(color) : null,
        boxShadow: withGlow
            ? AppShadows.glow(color, blur: 12, offset: const Offset(0, 4))
            : null,
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

// =============================================================================
// GLASS TOGGLE SWITCH
// =============================================================================

class GlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  const GlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 52,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value ? AppGradients.primary : null,
          color: value ? null : colorScheme.muted,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: value
              ? AppShadows.glow(
                  AppColors.primaryIndigo,
                  blur: 8,
                  offset: const Offset(0, 2),
                )
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 6,
            height: height - 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.soft,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BADGE / PILL
// =============================================================================

class GlassBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool isGradient;
  final List<Color>? gradientColors;

  const GlassBadge({
    super.key,
    required this.text,
    this.color,
    this.icon,
    this.isGradient = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppColors.primaryIndigo;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: isGradient
            ? LinearGradient(
                colors:
                    gradientColors ??
                    [badgeColor, badgeColor.withValues(alpha: 0.8)],
              )
            : LinearGradient(
                colors: [
                  badgeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  badgeColor.withValues(alpha: isDark ? 0.15 : 0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(8),
        border: isGradient
            ? null
            : Border.all(color: badgeColor.withValues(alpha: 0.3)),
        boxShadow: isGradient
            ? AppShadows.glow(badgeColor, blur: 8, offset: const Offset(0, 2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isGradient ? Colors.white : badgeColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGradient ? Colors.white : badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class GlassSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const GlassSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconContainer(
            icon: icon,
            color: color,
            size: 32,
            iconSize: 16,
            withBorder: false,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.p.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOADING INDICATOR
// =============================================================================

class GlassLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const GlassLoadingIndicator({super.key, this.size = 60, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.33),
      decoration: BoxDecoration(
        gradient: AppGradients.iconContainer(color ?? AppColors.primaryIndigo),
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: SizedBox(
        width: size * 0.4,
        height: size * 0.4,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color ?? AppColors.primaryIndigo,
        ),
      ),
    );
  }
}

// =============================================================================
// AVATAR WITH GRADIENT RING
// =============================================================================

class GradientAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final List<Color>? ringColors;
  final double ringWidth;

  const GradientAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 60,
    this.ringColors,
    this.ringWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = ShadTheme.of(context).colorScheme;
    final colors =
        ringColors ??
        [
          AppColors.primaryIndigo,
          AppColors.primaryPurple,
          AppColors.primaryPink,
        ];

    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        boxShadow: AppShadows.glow(
          colors.first,
          blur: 16,
          offset: const Offset(0, 6),
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.muted,
          border: Border.all(
            color: isDark ? Colors.black : Colors.white,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorWidget: (_, __, ___) => _buildInitials(context),
                )
              : _buildInitials(context),
        ),
      ),
    );
  }

  Widget _buildInitials(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    return Center(
      child: Text(
        initials ?? '??',
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORY FILTER PILL
// =============================================================================

class CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  const CategoryPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.primary : null,
          color: isSelected ? null : colorScheme.muted,
          borderRadius: AppRadius.inputRadius,
          border: isSelected ? null : Border.all(color: colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : colorScheme.foreground,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.primaryIndigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
