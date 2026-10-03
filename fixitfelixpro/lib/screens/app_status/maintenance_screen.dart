import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/config/config_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/responsive/responsive.dart';

/// Maintenance Screen
///
/// Displayed when the app is under maintenance.
/// Uses remote config: dev_maintenance (DEVELOPMENT) or prod_maintenance (PRODUCTION)
class MaintenanceScreen extends StatefulWidget {
  final VoidCallback? onBypass;
  final VoidCallback? onRetry;

  const MaintenanceScreen({super.key, this.onBypass, this.onRetry});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with TickerProviderStateMixin {
  final ConfigService _configService = ConfigService();
  bool _isRefreshing = false;

  late AnimationController _fadeController;
  late AnimationController _gearController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _gearController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _gearController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _configService.refresh();

      if (!_configService.isUnderMaintenance) {
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final deviceInfo = context.deviceInfo;
    final config = _configService.maintenanceConfig;

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

                    // Animated Maintenance Icon
                    _buildAnimatedIcon(),

                    SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                    // Title
                    Text(
                      config.title.isNotEmpty
                          ? config.title
                          : 'Under Maintenance',
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.h1
                                  : theme.textTheme.h2)
                              .copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.accentOrange,
                              ),
                    ),

                    SizedBox(height: deviceInfo.isTablet ? 20 : 16),

                    // Message
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: deviceInfo.isTablet ? 40 : 20,
                      ),
                      child: Text(
                        config.message.isNotEmpty
                            ? config.message
                            : 'We are currently performing scheduled maintenance. Please try again later.',
                        style: theme.textTheme.p.copyWith(
                          color: colorScheme.mutedForeground,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Estimated End Time
                    if (config.estimatedEndTime != null &&
                        config.estimatedEndTime!.isNotEmpty) ...[
                      SizedBox(height: deviceInfo.isTablet ? 32 : 24),
                      _buildEstimatedTimeCard(theme, colorScheme, config),
                    ],

                    const Spacer(),

                    // Action Buttons
                    _buildActionButtons(theme, colorScheme, deviceInfo, config),

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

  Widget _buildAnimatedIcon() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating gear
          AnimatedBuilder(
            animation: _gearController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _gearController.value * 2 * math.pi,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentOrange.withValues(alpha: 0.2),
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  ),
                  child: Stack(
                    children: List.generate(8, (index) {
                      final angle = (index * 45) * math.pi / 180;
                      return Positioned(
                        left: 75 + 65 * math.cos(angle) - 6,
                        top: 75 + 65 * math.sin(angle) - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          // Inner counter-rotating gear
          AnimatedBuilder(
            animation: _gearController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_gearController.value * 2 * math.pi * 0.7,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          // Center icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              LucideIcons.wrench,
              size: 56,
              color: AppColors.accentOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatedTimeCard(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
    dynamic config,
  ) {
    return ShadCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconContainer(
            icon: LucideIcons.clock,
            color: AppColors.accentOrange,
            size: 44,
            iconSize: 20,
            withBorder: true,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Completion',
                style: theme.textTheme.small.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.estimatedEndTime!,
                style: theme.textTheme.p.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    ShadThemeData theme,
    ShadColorScheme colorScheme,
    DeviceInfo deviceInfo,
    dynamic config,
  ) {
    return Column(
      children: [
        // Primary Retry Button
        ShadButton(
          width: double.infinity,
          size: ShadButtonSize.lg,
          enabled: !_isRefreshing,
          onPressed: _isRefreshing ? null : _handleRetry,
          child: _isRefreshing
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
                    const Text('Checking...'),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 18),
                    SizedBox(width: 8),
                    Text('Try Again'),
                  ],
                ),
        ),

        // Bypass Button
        if (config.allowBypass && widget.onBypass != null) ...[
          SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            child: OutlinedButton(
              onPressed: widget.onBypass,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonRadius,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: colorScheme.foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Continue Anyway',
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
