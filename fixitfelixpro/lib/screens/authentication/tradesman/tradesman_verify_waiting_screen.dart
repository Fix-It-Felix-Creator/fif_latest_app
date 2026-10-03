import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../core/enum.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../models/trade_requirement.dart';
import '../../../repositories/authentication/authentication_repository.dart';
import '../../../repositories/tradesman/tradesman_repository.dart';

class TradesmanVerifyWaitingScreen extends StatefulWidget {
  const TradesmanVerifyWaitingScreen({super.key});

  @override
  State<TradesmanVerifyWaitingScreen> createState() =>
      _TradesmanVerifyWaitingScreenState();
}

class _TradesmanVerifyWaitingScreenState
    extends State<TradesmanVerifyWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRefreshing = false;
  bool _isSigningOut = false;

  int _totalQualifications = 0;
  int _reviewedQualifications = 0;
  int _verifiedCount = 0;
  int _rejectedCount = 0;
  StreamSubscription<List<TradeQualificationDoc>>? _qualSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startQualificationStream();
  }

  void _startQualificationStream() {
    try {
      final tradesmanRepo = context.read<TradesmanRepository>();
      _qualSubscription = tradesmanRepo.streamTradeQualifications().listen(
        (qualifications) {
          if (mounted) {
            setState(() {
              _totalQualifications = qualifications.length;
              _verifiedCount = qualifications
                  .where((q) =>
                      q.verificationStatus == DocVerificationStatus.verified)
                  .length;
              _rejectedCount = qualifications
                  .where((q) =>
                      q.verificationStatus == DocVerificationStatus.rejected)
                  .length;
              _reviewedQualifications = _verifiedCount + _rejectedCount;
            });
          }
        },
        onError: (e) {
          debugPrint('Error streaming qualifications: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not start qualification stream: $e');
    }
  }

  @override
  void dispose() {
    _qualSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onRefreshStatus() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      context.read<AuthBloc>().add(const HandleAuthentication());
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _onSignOut() async {
    if (_isSigningOut) return;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      icon: LucideIcons.logOut,
      yesText: 'Yes, Sign Out',
      noText: 'No',
      onConfirm: () async {
        if (!mounted) return;
        setState(() => _isSigningOut = true);
        try {
          await context.read<AuthRepository>().signOut();
        } catch (e) {
          if (!mounted) return;
          setState(() => _isSigningOut = false);
          await CommonDialogs.showErrorDialog(
            context,
            title: 'Sign Out Failed',
            message: 'Failed to sign out: $e',
          );
        }
      },
    );
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 500;
    if (deviceInfo.isTablet) return 480;
    return 400;
  }

  EdgeInsets _getContentPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(40);
    if (deviceInfo.isTablet) return const EdgeInsets.all(32);
    return const EdgeInsets.all(24);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final deviceInfo = context.deviceInfo;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.userDetails?.verificationStatus !=
          current.userDetails?.verificationStatus,
      listener: (context, state) {
        final status = state.userDetails?.verificationStatus;
        if (status == VerificationStatus.verified ||
            status == VerificationStatus.rejected) {
          // Auto-advance: routing decision lives in AuthRepository.handleAuthentication().
          context.read<AuthBloc>().add(const HandleAuthentication());
        }
      },
      child: Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: _getContentPadding(deviceInfo),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight -
                            _getContentPadding(deviceInfo).vertical,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _getMaxWidth(deviceInfo),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated Icon
                              _WaitingGraphic(
                                animationController: _animationController,
                                theme: theme,
                                deviceInfo: deviceInfo,
                              ),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Title
                              Text(
                                'Verification in Progress',
                                style: (deviceInfo.isTablet
                                        ? theme.textTheme.h1
                                        : theme.textTheme.h2)
                                    .copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),

                              // Description
                              Text(
                                'Your application is being reviewed. This usually takes 1-2 business days.',
                                style: theme.textTheme.muted,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Qualification progress
                              if (_totalQualifications > 0) ...[
                                SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                                _buildQualificationProgress(theme, deviceInfo),
                              ],

                              SizedBox(height: deviceInfo.isTablet ? 24 : 20),

                              // Email note
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.mail,
                                    size: 14,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'You\'ll receive an email once verified.',
                                      style: theme.textTheme.small.copyWith(
                                        color: theme.colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom buttons
              Padding(
                padding: _getContentPadding(deviceInfo),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShadButton(
                          width: double.infinity,
                          height: deviceInfo.isTablet ? 52 : 48,
                          enabled: !_isRefreshing,
                          onPressed: _isRefreshing ? null : _onRefreshStatus,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isRefreshing)
                                SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                )
                              else
                                Icon(
                                  LucideIcons.refreshCw,
                                  size: 16,
                                  color: theme.colorScheme.primaryForeground,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                _isRefreshing ? 'Checking...' : 'Check Status',
                                style: TextStyle(
                                  color: _isRefreshing
                                      ? theme.colorScheme.mutedForeground
                                      : theme.colorScheme.primaryForeground,
                                  fontWeight: FontWeight.w600,
                                  fontSize: deviceInfo.isTablet ? 16 : 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ShadButton.ghost(
                          width: double.infinity,
                          height: 44,
                          enabled: !_isSigningOut && !_isRefreshing,
                          onPressed: _onSignOut,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSigningOut)
                                SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                )
                              else
                                Icon(
                                  LucideIcons.logOut,
                                  size: 16,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                _isSigningOut ? 'Signing out...' : 'Sign Out',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildQualificationProgress(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    final progress = _totalQualifications > 0
        ? _reviewedQualifications / _totalQualifications
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Document Review',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$_reviewedQualifications / $_totalQualifications',
              style: theme.textTheme.small.copyWith(
                color: progress >= 1.0
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.muted,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0
                  ? const Color(0xFF10B981)
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        if (_verifiedCount > 0 || _rejectedCount > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_verifiedCount > 0) ...[
                Icon(
                  LucideIcons.circleCheck,
                  size: 12,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_verifiedCount approved',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_rejectedCount > 0) ...[
                Icon(
                  LucideIcons.circleX,
                  size: 12,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_rejectedCount needs update',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _WaitingGraphic extends StatelessWidget {
  final AnimationController animationController;
  final ShadThemeData theme;
  final DeviceInfo deviceInfo;

  const _WaitingGraphic({
    required this.animationController,
    required this.theme,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final size = deviceInfo.isTablet ? 120.0 : 100.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                width: size * (0.8 + 0.2 * animationController.value),
                height: size * (0.8 + 0.2 * animationController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.1 * (1 - animationController.value),
                  ),
                ),
              );
            },
          ),

          // Outer circle
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.secondary,
            ),
          ),

          // Inner circle with icon
          Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
            child: AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: animationController.value * 2 * 3.14159,
                  child: child,
                );
              },
              child: Icon(
                LucideIcons.clock,
                size: size * 0.22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
