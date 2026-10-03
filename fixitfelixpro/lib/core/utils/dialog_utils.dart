import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, OAuthProvider;

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../models/app_user.dart';
import '../services/supabase_service.dart';

/// Utility class for common dialog builders
/// Centralizes dialog code to avoid duplication across screens
/// Compact, discrete, user-friendly glassmorphism design
class DialogUtils {
  DialogUtils._();

  // Design system colors
  static const _primaryIndigo = Color(0xFF6366F1);
  static const _primaryPurple = Color(0xFF8B5CF6);
  static const _errorRed = Color(0xFFEF4444);
  static const _errorDarkRed = Color(0xFFDC2626);
  static const _infoBlue = Color(0xFF3B82F6);
  static const _infoDarkBlue = Color(0xFF2563EB);

  /// Returns gradient colors based on destructive flag
  static List<Color> _getAccentColors(bool isDestructive) {
    return isDestructive
        ? [_errorRed, _errorDarkRed]
        : [_primaryIndigo, _primaryPurple];
  }

  /// Builds compact container decoration
  static BoxDecoration _dialogDecoration(ShadColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: colorScheme.border),
    );
  }

  /// Builds compact icon with subtle background
  static Widget _buildCompactIcon({
    required IconData icon,
    required List<Color> colors,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: 0.15),
            colors.last.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.first.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: colors.first, size: 22),
    );
  }

  /// Builds compact primary button
  static Widget _buildCompactButton({
    required String text,
    required IconData? icon,
    required List<Color> colors,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLoading
                ? [
                    colors.first.withValues(alpha: 0.6),
                    colors.last.withValues(alpha: 0.6),
                  ]
                : colors,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds compact secondary button
  static Widget _buildCompactOutlineButton({
    required String text,
    required bool isDark,
    required Color foregroundColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: enabled
                  ? foregroundColor
                  : foregroundColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a compact styled confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    return showShadDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = ShadTheme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final accentColors = _getAccentColors(isDestructive);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: _dialogDecoration(colorScheme),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      _buildCompactIcon(
                        icon: icon,
                        colors: accentColors,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDestructive
                                ? accentColors.first
                                : colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Message
                  Text(
                    message,
                    style: theme.textTheme.small.copyWith(
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactOutlineButton(
                          text: cancelText,
                          isDark: isDark,
                          foregroundColor: colorScheme.foreground,
                          onTap: () => Navigator.pop(dialogContext, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactButton(
                          text: confirmText,
                          icon: null,
                          colors: accentColors,
                          onTap: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows compact logout confirmation dialog
  static Future<void> showLogoutDialog(BuildContext context) async {
    const accentColors = [_errorRed, _errorDarkRed];

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = ShadTheme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: _dialogDecoration(colorScheme),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      _buildCompactIcon(
                        icon: LucideIcons.logOut,
                        colors: accentColors,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log Out',
                              style: theme.textTheme.large.copyWith(
                                fontWeight: FontWeight.w700,
                                color: accentColors.first,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You can sign in again anytime',
                              style: theme.textTheme.small.copyWith(
                                color: colorScheme.mutedForeground,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Message
                  Text(
                    'Are you sure you want to log out of your account?',
                    style: theme.textTheme.small.copyWith(
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactOutlineButton(
                          text: 'Cancel',
                          isDark: isDark,
                          foregroundColor: colorScheme.foreground,
                          onTap: () => Navigator.pop(dialogContext, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactButton(
                          text: 'Log Out',
                          icon: LucideIcons.logOut,
                          colors: accentColors,
                          onTap: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  /// Check if the current user signed in with a password provider
  static bool _isPasswordUser() {
    final user = SupabaseService().auth.currentUser;
    if (user == null) return false;
    // Supabase names the password provider 'email' (Firebase used 'password').
    return AppUser.fromSupabase(user).isPasswordUser;
  }

  /// Shows compact delete account dialog
  /// - Password users: requires password confirmation
  /// - Google users: no password needed, reauthenticates via Google
  /// - Disables account instead of deleting
  static Future<void> showDeleteAccountDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isProcessing = false;
    String? errorMessage;
    const accentColors = [_errorRed, _errorDarkRed];
    final isPasswordProvider = _isPasswordUser();

    await showShadDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = ShadTheme.of(context);
            final colorScheme = theme.colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: _dialogDecoration(colorScheme),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            _buildCompactIcon(
                              icon: LucideIcons.triangleAlert,
                              colors: accentColors,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Delete Account',
                                style: theme.textTheme.large.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: accentColors.first,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Warning message
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _errorRed.withValues(
                              alpha: isDark ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _errorRed.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                color: _errorRed,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your account will be disabled and you will be signed out. Contact support to reactivate.',
                                  style: theme.textTheme.small.copyWith(
                                    color: _errorRed,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Password field only for password users
                        if (isPasswordProvider) ...[
                          Text(
                            'Confirm your password',
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.muted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: errorMessage != null
                                    ? _errorRed.withValues(alpha: 0.5)
                                    : colorScheme.border,
                              ),
                            ),
                            child: ShadInput(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              enabled: !isProcessing,
                              placeholder: Text(
                                'Enter password',
                                style: theme.textTheme.small.copyWith(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              style: theme.textTheme.small,
                              decoration: ShadDecoration(
                                border: ShadBorder.none,
                                focusedBorder: ShadBorder.none,
                                errorBorder: ShadBorder.none,
                                secondaryBorder: ShadBorder.none,
                                secondaryFocusedBorder: ShadBorder.none,
                                secondaryErrorBorder: ShadBorder.none,
                              ),
                              leading: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  LucideIcons.lock,
                                  size: 16,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              trailing: GestureDetector(
                                onTap: isProcessing
                                    ? null
                                    : () => setDialogState(
                                        () =>
                                            obscurePassword = !obscurePassword,
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    obscurePassword
                                        ? LucideIcons.eyeOff
                                        : LucideIcons.eye,
                                    size: 16,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Are you sure you want to delete your account?',
                            style: theme.textTheme.small.copyWith(
                              color: colorScheme.mutedForeground,
                              height: 1.4,
                            ),
                          ),
                        ],
                        // Error message
                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.circleX,
                                size: 12,
                                color: _errorRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: theme.textTheme.small.copyWith(
                                    color: _errorRed,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        // Buttons row
                        Row(
                          children: [
                            Expanded(
                              child: _buildCompactOutlineButton(
                                text: 'Cancel',
                                isDark: isDark,
                                foregroundColor: colorScheme.foreground,
                                enabled: !isProcessing,
                                onTap: () {
                                  passwordController.dispose();
                                  Navigator.pop(dialogContext);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCompactButton(
                                text: isProcessing
                                    ? 'Disabling...'
                                    : 'Delete',
                                icon: isProcessing
                                    ? null
                                    : LucideIcons.trash2,
                                colors: accentColors,
                                isLoading: isProcessing,
                                onTap: () async {
                                  // Validate password for password users
                                  if (isPasswordProvider &&
                                      passwordController.text.isEmpty) {
                                    setDialogState(
                                      () => errorMessage =
                                          'Password is required',
                                    );
                                    return;
                                  }

                                  setDialogState(() {
                                    isProcessing = true;
                                    errorMessage = null;
                                  });

                                  final navigator =
                                      Navigator.of(dialogContext);
                                  final authBloc = context.read<AuthBloc>();

                                  try {
                                    final auth = SupabaseService().auth;
                                    final user = auth.currentUser;
                                    if (user == null) {
                                      setDialogState(() {
                                        isProcessing = false;
                                        errorMessage =
                                            'No user is currently signed in';
                                      });
                                      return;
                                    }

                                    // Reauthenticate based on provider.
                                    //
                                    // Supabase has no
                                    // reauthenticateWithCredential(). For a
                                    // password account, re-signing in with the
                                    // supplied password proves identity and
                                    // fails with the same invalid-credentials
                                    // error if it is wrong. For OAuth, running
                                    // the provider flow again is the proof.
                                    if (isPasswordProvider) {
                                      final email = user.email;
                                      if (email == null) {
                                        setDialogState(() {
                                          isProcessing = false;
                                          errorMessage =
                                              'Unable to verify user email';
                                        });
                                        return;
                                      }
                                      await auth.signInWithPassword(
                                        email: email,
                                        password: passwordController.text,
                                      );
                                    } else {
                                      final googleSignIn = GoogleSignIn();
                                      final googleUser =
                                          await googleSignIn.signIn();
                                      if (googleUser == null) {
                                        setDialogState(() {
                                          isProcessing = false;
                                          errorMessage =
                                              'Google sign-in was cancelled';
                                        });
                                        return;
                                      }
                                      final googleAuth =
                                          await googleUser.authentication;
                                      final idToken = googleAuth.idToken;
                                      if (idToken == null) {
                                        setDialogState(() {
                                          isProcessing = false;
                                          errorMessage =
                                              'Google sign-in failed';
                                        });
                                        return;
                                      }
                                      await auth.signInWithIdToken(
                                        provider: OAuthProvider.google,
                                        idToken: idToken,
                                        accessToken: googleAuth.accessToken,
                                      );
                                    }

                                    // Disable the account. `account_status` is
                                    // server-owned — the
                                    // profiles_guard_server_columns trigger
                                    // rejects a client write — so this goes
                                    // through an Edge Function running as the
                                    // service role.
                                    await SupabaseService()
                                        .client
                                        .functions
                                        .invoke('account-disable');

                                    passwordController.dispose();
                                    navigator.pop();
                                    authBloc.add(
                                      const AuthLogoutRequested(),
                                    );
                                  } on AuthException catch (e) {
                                    final code =
                                        (e.code ?? '').toLowerCase();
                                    final msg = e.message.toLowerCase();
                                    String message;
                                    if (code == 'invalid_credentials' ||
                                        msg.contains(
                                          'invalid login credentials',
                                        )) {
                                      message = 'Incorrect password';
                                    } else if (code ==
                                            'over_request_rate_limit' ||
                                        e.statusCode == '429' ||
                                        msg.contains('rate limit')) {
                                      message =
                                          'Too many attempts. Try again later';
                                    } else if (msg.contains('session')) {
                                      message =
                                          'Please sign out and sign in again';
                                    } else {
                                      message = e.message;
                                    }
                                    setDialogState(() {
                                      isProcessing = false;
                                      errorMessage = message;
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isProcessing = false;
                                      errorMessage =
                                          'An unexpected error occurred';
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Shows compact info dialog
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = LucideIcons.info,
    String buttonText = 'OK',
  }) async {
    await showShadDialog(
      context: context,
      builder: (dialogContext) {
        final theme = ShadTheme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const accentColors = [_infoBlue, _infoDarkBlue];

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: _dialogDecoration(colorScheme),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      _buildCompactIcon(
                        icon: icon,
                        colors: accentColors,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Message
                  Text(
                    message,
                    style: theme.textTheme.small.copyWith(
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Button
                  _buildCompactButton(
                    text: buttonText,
                    icon: LucideIcons.check,
                    colors: accentColors,
                    onTap: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows an error toast
  static void showErrorToast(BuildContext context, String message) {
    ShadToaster.of(context).show(
      ShadToast.destructive(
        title: const Text('Error'),
        description: Text(message),
      ),
    );
  }

  /// Shows a success toast
  static void showSuccessToast(BuildContext context, String message) {
    ShadToaster.of(
      context,
    ).show(ShadToast(title: const Text('Success'), description: Text(message)));
  }
}
