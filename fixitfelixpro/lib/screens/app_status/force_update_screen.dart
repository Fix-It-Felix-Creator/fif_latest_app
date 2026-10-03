import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/config_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/responsive/responsive.dart';

/// Force Update Screen
///
/// Displayed when a force update is required.
/// Uses remote config: dev_force_app_update (DEVELOPMENT) or force_app_update (PRODUCTION)
/// Compares current app version with android_app_version or ios_app_version
class ForceUpdateScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const ForceUpdateScreen({super.key, this.onRetry});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen>
    with TickerProviderStateMixin {
  final ConfigService _configService = ConfigService();
  bool _isRefreshing = false;
  bool _isLaunchingStore = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _configService.refresh();

      if (!_configService.requiresForceUpdate) {
        widget.onRetry?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openStore() async {
    setState(() {
      _isLaunchingStore = true;
    });

    try {
      final storeLink = _configService.storeLink;

      if (storeLink != null && storeLink.isNotEmpty) {
        final uri = Uri.parse(storeLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError('Could not open store');
        }
      } else {
        String fallbackUrl;
        if (Platform.isAndroid) {
          fallbackUrl = 'https://play.google.com/store/apps';
        } else if (Platform.isIOS) {
          fallbackUrl = 'https://apps.apple.com';
        } else {
          _showError('Store not available for this platform');
          return;
        }

        final uri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _showError('Failed to open store');
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingStore = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      AppToast.error(context, title: 'Error', description: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        color: colorScheme.background,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 32 : 24),
                child: Column(
                  children: [
                    const Spacer(),

                    // Animated Update Icon
                    _buildAnimatedIcon(colorScheme),

                    SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                    // Title
                    Text(
                      'Update Required',
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h1
                                  : theme.textTheme.h2)
                              .copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.accentBlue,
                              ),
                    ),

                    SizedBox(height: deviceInfo.isTablet ? 20 : 16),

                    // Message
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: deviceInfo.isTablet ? 40 : 20,
                      ),
                      child: Text(
                        'A new version of the app is available. Please update to continue using the app.',
                        style: theme.textTheme.p.copyWith(
                          color: colorScheme.mutedForeground,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: deviceInfo.isTablet ? 32 : 24),

                    // Version Info Card
                    _buildVersionInfoCard(theme, colorScheme, isDark),

                    const Spacer(),

                    // Action Buttons
                    _buildActionButtons(theme, colorScheme, deviceInfo),

                    SizedBox(height: deviceInfo.isTablet ? 32 : 24),

                    // Environment Indicator
                    if (_configService.isDebugMode)
                      _buildEnvironmentBadge(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(ShadColorScheme colorScheme) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 160 * (0.7 + 0.3 * _pulseAnimation.value),
                height: 160 * (0.7 + 0.3 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentBlue.withValues(
                      alpha: 0.2 * (1 - _pulseAnimation.value),
                    ),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Middle ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final delayed = (_pulseAnimation.value + 0.5) % 1.0;
              return Container(
                width: 160 * (0.6 + 0.25 * delayed),
                height: 160 * (0.6 + 0.25 * delayed),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryIndigo.withValues(
                      alpha: 0.15 * (1 - delayed),
                    ),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentBlue.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              LucideIcons.download,
              size: 56,
              color: AppColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfoCard(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
    bool isDark,
  ) {
    return ShadCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _buildVersionRow(
            theme,
            colorScheme,
            'Platform',
            _configService.currentPlatform,
            Platform.isIOS ? LucideIcons.apple : LucideIcons.smartphone,
            AppColors.primaryIndigo,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(
              color: colorScheme.border.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
          _buildVersionRow(
            theme,
            colorScheme,
            'Current Version',
            _configService.currentAppVersion,
            LucideIcons.info,
            const Color(0xFF71717A),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(
              color: colorScheme.border.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
          _buildVersionRow(
            theme,
            colorScheme,
            'Required Version',
            _configService.minRequiredVersion,
            LucideIcons.sparkles,
            AppColors.accentGreen,
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionRow(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
    String label,
    String version,
    IconData icon,
    Color iconColor, {
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        IconContainer(
          icon: icon,
          color: iconColor,
          size: 40,
          iconSize: 18,
          withBorder: true,
          withGlow: isHighlighted,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.small.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                version,
                style: theme.textTheme.p.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? AppColors.accentGreen
                      : colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
        if (isHighlighted)
          ShadBadge(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.chevronUp,
                  size: 12,
                  color: AppColors.accentGreen,
                ),
                const SizedBox(width: 4),
                Text('NEW', style: TextStyle(color: AppColors.accentGreen)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
    DeviceInfo deviceInfo,
  ) {
    return Column(
      children: [
        // Primary Update Button
        ShadButton(
          width: double.infinity,
          size: ShadButtonSize.lg,
          enabled: !_isLaunchingStore,
          onPressed: _isLaunchingStore ? null : _openStore,
          child: _isLaunchingStore
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Opening Store...'),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Platform.isIOS ? LucideIcons.apple : LucideIcons.play,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isIOS
                          ? 'Update on App Store'
                          : 'Update on Play Store',
                    ),
                  ],
                ),
        ),

        SizedBox(height: AppSpacing.md),

        // Secondary Check Again Button
        SizedBox(
          width: double.infinity,
          height: deviceInfo.isTablet ? 52 : 48,
          child: OutlinedButton(
            onPressed: _isRefreshing ? null : _handleRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.buttonRadius,
              ),
            ),
            child: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.foreground,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        size: 18,
                        color: colorScheme.foreground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Check Again',
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentBadge(ShadThemeData theme) {
    final isProduction = _configService.isProduction;
    final color = isProduction ? AppColors.error : AppColors.accentGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isProduction ? 'PRODUCTION' : 'DEVELOPMENT',
            style: theme.textTheme.small.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
