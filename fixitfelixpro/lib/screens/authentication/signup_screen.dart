import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/config/config_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/common_toasts.dart';
import '../../core/utils/dialog_utils.dart';
import '../../generated/assets.dart';
import '../shared/webview_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _password = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  late FocusNode _confirmPasswordFocusNode;
  late FocusNode _signUpButtonFocusNode;

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
    _signUpButtonFocusNode = FocusNode();
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
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _signUpButtonFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _onBackPressed() async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Discard Sign Up?',
      message:
          'Are you sure you want to go back? Any information you have entered will be lost.',
      icon: LucideIcons.trash2,
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    return confirmed == true;
  }

  void _onSignUp() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;
      if (values != null) {
        context.read<AuthBloc>().add(
          SignUpWithEmailRequested(
            email: (values['email'] as String).trim(),
            password: values['password'] as String,
          ),
        );
      }
    }
  }

  void _onGoogleSignUp() {
    context.read<AuthBloc>().add(const SignInWithGoogleRequested());
  }

  void _onAppleSignUp() {
    context.read<AuthBloc>().add(const SignInWithAppleRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthErrorState) {
          CommonToasts.error(
            context,
            state.errorMessage,
            title: 'Sign Up Failed',
          );
          context.read<AuthBloc>().add(const AuthErrorCleared());
        }

        if (state.status == AuthStatus.authenticated) {
          CommonToasts.success(
            context,
            'Please check your email to verify your account.',
            title: 'Account Created',
          );
          context.read<AuthBloc>().add(const HandleAuthentication());
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await _onBackPressed();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          body: Container(
            color: theme.colorScheme.background,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: _getResponsivePadding(deviceInfo),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _getMaxWidth(deviceInfo),
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildContent(
                            context,
                            theme,
                            isDark,
                            deviceInfo,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _getResponsivePadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return const EdgeInsets.all(48);
    }
    if (deviceInfo.isTablet) {
      return EdgeInsets.symmetric(
        horizontal: deviceInfo.isLandscape ? 48 : 32,
        vertical: deviceInfo.isLandscape ? 24 : 32,
      );
    }
    return EdgeInsets.symmetric(
      horizontal: deviceInfo.isLandscape ? 32 : 24,
      vertical: deviceInfo.isLandscape ? 16 : 24,
    );
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) return 800;
    if (deviceInfo.isTablet) return 500;
    return 400;
  }

  Widget _buildContent(
    BuildContext context,
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final logo = Image.asset(
      Assets.logoWithText,
      height: deviceInfo.isTablet ? 48 : 40,
    );

    // Tablet landscape: side-by-side layout
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogoContainer(theme, logo, deviceInfo),
                  const SizedBox(height: 32),
                  Text(
                    'Create Account',
                    style: theme.textTheme.h1.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Join FixItFelix Pro and start your journey',
                    style: theme.textTheme.muted.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: _buildModernCard(
              theme,
              isDark,
              deviceInfo,
              _buildForm(context, theme, deviceInfo),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoContainer(theme, logo, deviceInfo),
        SizedBox(height: deviceInfo.isTablet ? 40 : 32),
        _buildModernCard(
          theme,
          isDark,
          deviceInfo,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign Up',
                style:
                    (deviceInfo.isTablet
                            ? theme.textTheme.h1
                            : theme.textTheme.h2)
                        .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an account to get started',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 28),
              _buildForm(context, theme, deviceInfo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoContainer(
    ShadThemeData theme,
    Widget logo,
    DeviceInfo deviceInfo,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: logo,
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

  Widget _buildForm(
    BuildContext context,
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    return ShadForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email field
          _buildModernInputField(
            theme,
            deviceInfo,
            id: 'email',
            label: 'Email',
            placeholder: 'Enter your email',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            validator: (value) {
              final email = value.trim();
              if (email.isEmpty) return 'Email is required';
              if (!email.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Password field
          _buildPasswordInputField(
            theme,
            deviceInfo,
            id: 'password',
            label: 'Password',
            placeholder: 'Create a password',
            obscureText: _obscurePassword,
            onToggleVisibility: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onChanged: (value) => _password = value,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            validator: (value) {
              if (value.isEmpty) return 'Password is required';
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Confirm Password field
          _buildPasswordInputField(
            theme,
            deviceInfo,
            id: 'confirmPassword',
            label: 'Confirm Password',
            placeholder: 'Confirm your password',
            obscureText: _obscureConfirmPassword,
            icon: LucideIcons.lockKeyhole,
            onToggleVisibility: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            focusNode: _confirmPasswordFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              _signUpButtonFocusNode.requestFocus();
              _onSignUp();
            },
            validator: (value) {
              if (value.isEmpty) return 'Please confirm your password';
              if (value != _password) return 'Passwords do not match';
              return null;
            },
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Terms checkbox
          _buildTermsCheckbox(context, theme, deviceInfo),
          SizedBox(height: deviceInfo.isTablet ? 24 : 20),

          // Sign up button
          BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (previous, current) =>
                previous.isLoading != current.isLoading ||
                previous is AuthLoadingState != (current is AuthLoadingState),
            builder: (context, state) {
              final isLoading = state.isLoading || state is AuthLoadingState;

              return _buildPrimaryButton(
                theme,
                deviceInfo,
                isLoading: isLoading,
                onPressed: isLoading ? null : _onSignUp,
                label: 'Sign Up',
                loadingLabel: 'Creating Account...',
                focusNode: _signUpButtonFocusNode,
              );
            },
          ),
          SizedBox(height: deviceInfo.isTablet ? 28 : 24),

          // Divider
          _buildDivider(theme),
          SizedBox(height: deviceInfo.isTablet ? 28 : 24),

          // Google sign up button
          BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (previous, current) =>
                previous.isLoading != current.isLoading ||
                previous is AuthLoadingState != (current is AuthLoadingState),
            builder: (context, state) {
              final isLoading = state.isLoading || state is AuthLoadingState;

              return _buildGoogleButton(
                theme,
                deviceInfo,
                isLoading: isLoading,
                onPressed: isLoading ? null : _onGoogleSignUp,
              );
            },
          ),
          if (Platform.isIOS) ...[
            SizedBox(height: deviceInfo.isTablet ? 16 : 12),
            BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (previous, current) =>
                  previous.isLoading != current.isLoading ||
                  previous is AuthLoadingState !=
                      (current is AuthLoadingState),
              builder: (context, state) {
                final isLoading = state.isLoading || state is AuthLoadingState;
                return _buildAppleButton(
                  theme,
                  deviceInfo,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onAppleSignUp,
                );
              },
            ),
          ],
          SizedBox(height: deviceInfo.isTablet ? 28 : 24),

          // Sign in link
          _buildSignInLink(context, theme),
        ],
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

  Widget _buildPasswordInputField(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required String id,
    required String label,
    required String placeholder,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    IconData icon = LucideIcons.lock,
    ValueChanged<String>? onChanged,
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
      obscureText: obscureText,
      onChanged: onChanged,
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
      trailing: ShadButton.ghost(
        width: 32,
        height: 32,
        padding: EdgeInsets.zero,
        onPressed: onToggleVisibility,
        child: Icon(
          obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 18,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildTermsCheckbox(
    BuildContext context,
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    return Padding(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 0),
      child: ShadCheckboxFormField(
        id: 'terms',
        initialValue: false,
        color: theme.colorScheme.foreground,
        decoration: ShadDecoration(
          border: ShadBorder.all(
            color: theme.colorScheme.mutedForeground,
            width: 1,
            radius: BorderRadius.circular(4),
          ),
        ),
        inputLabel: Text.rich(
          TextSpan(
            text: 'I agree to the ',
            style: theme.textTheme.small,
            children: [
              TextSpan(
                text: 'Terms of Service',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    final url = ConfigService().termsAndConditionsUrl;
                    if (url.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewScreen(
                            url: url,
                            title: 'Terms of Service',
                          ),
                        ),
                      );
                    }
                  },
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    final url = ConfigService().privacyPolicyUrl;
                    if (url.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WebViewScreen(url: url, title: 'Privacy Policy'),
                        ),
                      );
                    }
                  },
              ),
            ],
          ),
        ),
        validator: (value) {
          if (value != true) {
            return 'You must accept the terms and conditions';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPrimaryButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
    required VoidCallback? onPressed,
    required String label,
    required String loadingLabel,
    FocusNode? focusNode,
  }) {
    return ShadButton(
      width: double.infinity,
      size: ShadButtonSize.lg,
      focusNode: focusNode,
      enabled: !isLoading,
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
                Text(
                  loadingLabel,
                  style: const TextStyle(height: 1.1),
                ),
              ],
            )
          : Text(
              label,
              style: const TextStyle(height: 1.1),
            ),
    );
  }

  Widget _buildDivider(ShadThemeData theme) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: theme.colorScheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Or',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: theme.colorScheme.border)),
      ],
    );
  }

  Widget _buildGoogleButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return ShadButton.outline(
      width: double.infinity,
      size: ShadButtonSize.lg,
      enabled: !isLoading,
      onPressed: onPressed,
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: theme.colorScheme.border,
          width: 1.5,
          radius: BorderRadius.circular(12),
        ),
      ),
      leading: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.foreground,
              ),
            )
          : SvgPicture.asset(
              'assets/google_logo.svg',
              height: 20,
              width: 20,
            ),
      child: Text(
        isLoading ? 'Signing up...' : 'Continue with Google',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: deviceInfo.isTablet ? 15 : 14,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildAppleButton(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white : Colors.black;
    final fg = isDark ? Colors.black : Colors.white;
    return ShadButton(
      width: double.infinity,
      size: ShadButtonSize.lg,
      enabled: !isLoading,
      onPressed: onPressed,
      backgroundColor: bg,
      hoverBackgroundColor: bg,
      foregroundColor: fg,
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: bg,
          width: 1.5,
          radius: BorderRadius.circular(12),
        ),
      ),
      leading: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Icon(Icons.apple, size: 22, color: fg),
      child: Text(
        isLoading ? 'Signing up...' : 'Continue with Apple',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: deviceInfo.isTablet ? 15 : 14,
          height: 1.1,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildSignInLink(BuildContext context, ShadThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text.rich(
            TextSpan(
              text: 'Already have an account? ',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
              children: [
                TextSpan(
                  text: 'Sign In',
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
