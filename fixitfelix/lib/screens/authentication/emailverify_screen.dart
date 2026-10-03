import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/common_toasts.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _verificationCheckTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startVerificationCheck();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cooldownTimer?.cancel();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkEmailVerification(),
    );
  }

  Future<void> _checkEmailVerification() async {
    context.read<AuthBloc>().add(const AuthUserRefreshed());
  }

  void _resendEmail() {
    if (!_canResend) return;

    context.read<AuthBloc>().add(const SendVerificationEmailRequested());

    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onLogout() {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is VerificationEmailSentState) {
          CommonToasts.success(
            context,
            'Verification email has been resent.',
            title: 'Email Sent',
          );
        }

        if (state is VerificationEmailErrorState) {
          CommonToasts.error(context, state.errorMessage);
          setState(() {
            _canResend = true;
            _resendCooldown = 0;
          });
          _cooldownTimer?.cancel();
        }

        if (state.status == AuthStatus.authenticated && state.isEmailVerified) {
          _verificationCheckTimer?.cancel();
          context.read<AuthBloc>().add(const HandleAuthentication());
        }
      },
      child: Scaffold(
        body: Container(
          color: theme.colorScheme.background,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: _getContentPadding(deviceInfo),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _getMaxWidth(deviceInfo),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Email Icon
                      _EmailGraphic(
                        animationController: _animationController,
                        theme: theme,
                        deviceInfo: deviceInfo,
                      ),
                      SizedBox(height: deviceInfo.isTablet ? 48 : 40),

                      // Main Card
                      _buildModernCard(
                        theme,
                        isDark,
                        deviceInfo,
                        Column(
                          children: [
                            // Title
                            Text(
                              'Verify Your Email',
                              style:
                                  (deviceInfo.isTablet
                                          ? theme.textTheme.h1
                                          : theme.textTheme.h2)
                                      .copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: deviceInfo.isTablet ? 16 : 12),

                            // Email info
                            BlocBuilder<AuthBloc, AuthState>(
                              buildWhen: (previous, current) =>
                                  previous.user?.email != current.user?.email,
                              builder: (context, state) {
                                final email =
                                    state.user?.email ?? 'your email address';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.mail,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          email,
                                          style: theme.textTheme.p.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

                            // Description
                            Text(
                              "We've sent a verification link to your email address. "
                              "Please click the link to verify your account.",
                              style: theme.textTheme.muted,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                            // Status indicator
                            _buildStatusIndicator(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                            // Resend Button
                            BlocBuilder<AuthBloc, AuthState>(
                              buildWhen: (previous, current) =>
                                  previous is VerificationEmailLoadingState !=
                                  (current is VerificationEmailLoadingState),
                              builder: (context, state) {
                                final isLoading =
                                    state is VerificationEmailLoadingState;
                                return _buildResendButton(
                                  theme,
                                  deviceInfo,
                                  isLoading: isLoading,
                                );
                              },
                            ),

                            // Cooldown message
                            if (!_canResend) ...[
                              const SizedBox(height: 16),
                              _buildCooldownIndicator(theme),
                            ],
                            SizedBox(height: deviceInfo.isTablet ? 24 : 20),

                            // Helper info card
                            _buildHelperCard(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                            // Sign out link
                            _buildSignOutLink(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
    Widget child,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.85)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildStatusIndicator(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: deviceInfo.isTablet ? 24 : 20,
        vertical: deviceInfo.isTablet ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              'Waiting for verification...',
              style: theme.textTheme.p.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
  }) {
    final isEnabled = _canResend && !isLoading;

    return ShadButton(
      width: double.infinity,
      height: deviceInfo.isTablet ? 52 : 48,
      enabled: isEnabled,
      onPressed: isEnabled ? _resendEmail : null,
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primaryForeground,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sending...',
                  style: TextStyle(
                    color: theme.colorScheme.primaryForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: isEnabled
                      ? theme.colorScheme.primaryForeground
                      : theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Text(
                  'Resend Verification Email',
                  style: TextStyle(
                    color: isEnabled
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCooldownIndicator(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.clock,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Text(
            'Resend available in $_resendCooldown seconds',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperCard(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 18 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.lightbulb,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Didn\'t receive the email?',
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelperItem(theme, 'Check your spam or junk folder'),
          const SizedBox(height: 6),
          _buildHelperItem(theme, 'Make sure you entered the correct email'),
          const SizedBox(height: 6),
          _buildHelperItem(theme, 'Wait a few minutes before trying again'),
        ],
      ),
    );
  }

  Widget _buildHelperItem(ShadThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.mutedForeground,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutLink(ShadThemeData theme) {
    return GestureDetector(
      onTap: _onLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.destructive.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.logOut,
              size: 16,
              color: theme.colorScheme.destructive,
            ),
            const SizedBox(width: 8),
            Text(
              'Sign out and try a different account',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailGraphic extends StatelessWidget {
  final AnimationController animationController;
  final ShadThemeData theme;
  final DeviceInfo deviceInfo;

  const _EmailGraphic({
    required this.animationController,
    required this.theme,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final size = deviceInfo.isTablet ? 160.0 : 130.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                width: size * (0.75 + 0.25 * animationController.value),
                height: size * (0.75 + 0.25 * animationController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.15 * (1 - animationController.value),
                  ),
                ),
              );
            },
          ),

          // Solid outer circle
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
            child: Icon(
              LucideIcons.mailOpen,
              size: size * 0.22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
