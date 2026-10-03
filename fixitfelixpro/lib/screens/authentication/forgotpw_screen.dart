import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/design_system/design_system.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/common_toasts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isSubmitted = false;
  String _submittedEmail = '';
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late FocusNode _emailFocusNode;
  late FocusNode _submitButtonFocusNode;

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _submitButtonFocusNode = FocusNode();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _submitButtonFocusNode.dispose();
    _animationController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _submitEmail() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;
      final email = (values?['email'] as String? ?? '').trim();

      setState(() => _submittedEmail = email);
      context.read<AuthBloc>().add(PasswordResetRequested(email: email));
    }
  }

  void _resendEmail() {
    if (!_canResend || _submittedEmail.isEmpty) return;
    context.read<AuthBloc>().add(
      PasswordResetRequested(email: _submittedEmail),
    );
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetSuccessState) {
          setState(() => _isSubmitted = true);
          _startCooldown();

          CommonToasts.success(
            context,
            'Password reset email has been sent. Check your inbox.',
            title: 'Email Sent',
          );
        }

        if (state is PasswordResetErrorState) {
          CommonToasts.error(
            context,
            state.errorMessage,
            title: 'Reset Failed',
          );
        }
      },
      child: Scaffold(
        body: Container(
          color: theme.colorScheme.background,
          child: SafeArea(
            child: Column(
              children: [
                // Modern AppBar
                _buildAppBar(theme, deviceInfo),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: _getResponsivePadding(deviceInfo),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _getMaxWidth(deviceInfo),
                        ),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: _isSubmitted
                                ? _buildSuccessView(theme, isDark, deviceInfo)
                                : _buildFormView(theme, isDark, deviceInfo),
                          ),
                        ),
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

  Widget _buildAppBar(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShadButton.ghost(
              width: deviceInfo.isTablet ? 48 : 44,
              height: deviceInfo.isTablet ? 48 : 44,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Icon(
                LucideIcons.chevronLeft,
                size: deviceInfo.isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Forgot Password',
            style:
                (deviceInfo.isTablet ? theme.textTheme.h2 : theme.textTheme.h3)
                    .copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  EdgeInsets _getResponsivePadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    if (deviceInfo.isTablet) {
      return const EdgeInsets.all(32);
    }
    return const EdgeInsets.all(24);
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) return 600;
    if (deviceInfo.isTablet) return 500;
    return 400;
  }

  Widget _buildFormView(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous is PasswordResetLoadingState !=
          (current is PasswordResetLoadingState),
      builder: (context, state) {
        final isLoading = state is PasswordResetLoadingState;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: deviceInfo.isTablet ? 32 : 24),

            // Icon Header
            _buildIconHeader(theme, deviceInfo),
            SizedBox(height: deviceInfo.isTablet ? 32 : 24),

            // Modern Card
            _buildModernCard(
              theme,
              isDark,
              deviceInfo,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset your password',
                    style:
                        (deviceInfo.isTablet
                                ? theme.textTheme.h2
                                : theme.textTheme.h3)
                            .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: theme.textTheme.muted,
                  ),
                  SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                  // Email Form
                  ShadForm(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildModernInputField(
                          theme,
                          deviceInfo,
                          id: 'email',
                          label: 'Email',
                          placeholder: 'Enter your email address',
                          icon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isLoading,
                          focusNode: _emailFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            _submitButtonFocusNode.requestFocus();
                            _submitEmail();
                          },
                          validator: (value) {
                            final email = value.trim();
                            if (email.isEmpty) return 'Email is required';
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(email)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                        // Submit Button
                        _buildPrimaryButton(
                          theme,
                          deviceInfo,
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submitEmail,
                          label: 'Send Reset Link',
                          loadingLabel: 'Sending...',
                          icon: LucideIcons.send,
                          focusNode: _submitButtonFocusNode,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                  // Back to sign in
                  _buildBackToSignIn(theme),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuccessView(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous is PasswordResetLoadingState !=
          (current is PasswordResetLoadingState),
      builder: (context, state) {
        final isLoading = state is PasswordResetLoadingState;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: deviceInfo.isTablet ? 32 : 24),

            // Animated Email Icon
            _EmailSentGraphic(
              theme: theme,
              size: deviceInfo.isTablet ? 200 : 160,
            ),
            SizedBox(height: deviceInfo.isTablet ? 40 : 32),

            // Modern Card
            _buildModernCard(
              theme,
              isDark,
              deviceInfo,
              Column(
                children: [
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.mailCheck,
                      size: 32,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: deviceInfo.isTablet ? 24 : 20),

                  // Title
                  Text(
                    'Check your inbox',
                    style:
                        (deviceInfo.isTablet
                                ? theme.textTheme.h2
                                : theme.textTheme.h3)
                            .copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text.rich(
                    TextSpan(
                      text: 'We\'ve sent a password reset link to ',
                      style: theme.textTheme.muted,
                      children: [
                        TextSpan(
                          text: _submittedEmail,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                  // Done Button
                  _buildPrimaryButton(
                    theme,
                    deviceInfo,
                    isLoading: false,
                    onPressed: () => Navigator.pop(context),
                    label: 'Back to Sign In',
                    loadingLabel: '',
                    icon: LucideIcons.chevronLeft,
                  ),
                  SizedBox(height: deviceInfo.isTablet ? 16 : 14),

                  // Resend Button
                  _buildOutlineButton(
                    theme,
                    deviceInfo,
                    isLoading: isLoading,
                    enabled: _canResend && !isLoading,
                    onPressed: _canResend && !isLoading ? _resendEmail : null,
                    label: isLoading ? 'Sending...' : 'Resend email',
                    icon: LucideIcons.refreshCw,
                  ),

                  // Countdown message
                  if (!_canResend && !isLoading) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                            'Wait $_resendCooldown seconds',
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: deviceInfo.isTablet ? 24 : 20),

                  // Helper text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 18,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Didn\'t receive the email? Check your spam folder.',
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconHeader(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(deviceInfo.isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          LucideIcons.keyRound,
          size: deviceInfo.isTablet ? 48 : 40,
          color: theme.colorScheme.primary,
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
            ? theme.colorScheme.card.withValues(alpha: 0.8)
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

  Widget _buildPrimaryButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
    required VoidCallback? onPressed,
    required String label,
    required String loadingLabel,
    IconData? icon,
    FocusNode? focusNode,
  }) {
    return ShadButton(
      width: double.infinity,
      size: ShadButtonSize.lg,
      enabled: !isLoading,
      focusNode: focusNode,
      onPressed: onPressed,
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(loadingLabel),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }

  Widget _buildOutlineButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
    required bool enabled,
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      height: deviceInfo.isTablet ? 52 : 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? theme.colorScheme.border
              : theme.colorScheme.border.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ShadButton.outline(
        width: double.infinity,
        height: deviceInfo.isTablet ? 52 : 48,
        enabled: enabled,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.foreground,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? theme.colorScheme.foreground
                    : theme.colorScheme.mutedForeground,
              ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: deviceInfo.isTablet ? 15 : 14,
                color: enabled
                    ? theme.colorScheme.foreground
                    : theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInputField(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required String id,
    required String label,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? Function(String)? validator,
  }) {
    return ShadInputFormField(
      id: id,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      label: Text(
        label,
        style: theme.textTheme.small.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.foreground,
        ),
      ),
      placeholder: Text(placeholder),
      keyboardType: keyboardType,
      enabled: enabled,
      enableInteractiveSelection: true,
      magnifierConfiguration: const TextMagnifierConfiguration(),
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          icon,
          size: deviceInfo.isTablet ? 20 : 18,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      // Add trailing spacer to match password field height
      trailing: const SizedBox(width: 32, height: 32),
      validator: validator,
    );
  }

  Widget _buildBackToSignIn(ShadThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text.rich(
            TextSpan(
              text: 'Remember your password? ',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
              children: [
                TextSpan(
                  text: 'Sign in',
                  style: theme.textTheme.p.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSentGraphic extends StatefulWidget {
  final ShadThemeData theme;
  final double size;

  const _EmailSentGraphic({required this.theme, this.size = 160});

  @override
  State<_EmailSentGraphic> createState() => _EmailSentGraphicState();
}

class _EmailSentGraphicState extends State<_EmailSentGraphic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing circle
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: widget.size * (0.8 + 0.2 * _controller.value),
                height: widget.size * (0.8 + 0.2 * _controller.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.theme.colorScheme.primary.withValues(
                    alpha: 0.1 * (1 - _controller.value),
                  ),
                ),
              );
            },
          ),

          // Middle circle
          Container(
            width: widget.size * 0.75,
            height: widget.size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.theme.colorScheme.secondary,
            ),
          ),

          // Inner circle with icon
          Container(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.theme.colorScheme.primary,
            ),
            child: Icon(
              LucideIcons.keyRound,
              size: widget.size * 0.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
