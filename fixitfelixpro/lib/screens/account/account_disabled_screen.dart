import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../repositories/account/account_repository.dart';
import '../../repositories/authentication/authentication_repository.dart';

/// Shown when a user with `accountStatus == "deletion_pending"` signs in.
/// They can:
///   • Recover (within the recovery window)
///   • Download their data
///   • Sign out
class AccountDisabledScreen extends StatefulWidget {
  const AccountDisabledScreen({
    super.key,
    this.recoveryWindowEndsAt,
    this.personalDataRetainedUntil,
  });

  /// Epoch millis when the recovery window closes.
  final int? recoveryWindowEndsAt;

  /// Epoch millis when the personal data is permanently purged.
  final int? personalDataRetainedUntil;

  @override
  State<AccountDisabledScreen> createState() => _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends State<AccountDisabledScreen> {
  final _repo = AccountRepository();
  bool _isDownloading = false;
  bool _isRecovering = false;
  bool _isSigningOut = false;

  Future<void> _onDownload() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final result = await _repo.downloadPersonalData();
    if (!mounted) return;
    setState(() => _isDownloading = false);

    if (!result.success || result.filePath == null) {
      await CommonDialogs.showErrorDialog(
        context,
        title: 'Download Failed',
        message: result.errorMessage ?? 'Could not download your data.',
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.filePath!, mimeType: 'application/json')],
        subject: 'Your FixItFelix account data',
        text:
            'A JSON export of your profile, subscriptions and payment method '
            'info. Save it wherever you like.',
      ),
    );
    if (!mounted) return;
    CommonToasts.info(
      context,
      'Pick where to save or send the file.',
      title: 'Share Your Data',
    );
  }

  Future<void> _onRecover() async {
    if (_isRecovering) return;
    await CommonDialogs.showInfoBox(
      context,
      title: 'Recover Account?',
      message:
          'Your account will be restored. You\'ll need to re-subscribe if '
          'you want a paid plan again.',
      icon: LucideIcons.rotateCcw,
      yesText: 'Yes, Recover',
      noText: 'Cancel',
      onConfirm: _executeRecover,
    );
  }

  Future<void> _executeRecover() async {
    if (!mounted) return;
    setState(() => _isRecovering = true);
    final result = await _repo.recoverAccount();
    if (!mounted) return;
    setState(() => _isRecovering = false);

    if (!result.success) {
      await CommonDialogs.showErrorDialog(
        context,
        title: 'Recovery Failed',
        message: result.errorMessage ?? 'Could not recover your account.',
      );
      return;
    }
    if (!mounted) return;
    CommonToasts.success(
      context,
      'Your account is active again.',
      title: 'Welcome Back',
    );
    context.read<AuthBloc>().add(const HandleAuthentication());
  }

  Future<void> _onSignOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await context.read<AuthRepository>().signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      await CommonDialogs.showErrorDialog(
        context,
        title: 'Sign Out Failed',
        message: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    final daysLeft = _daysUntil(widget.recoveryWindowEndsAt);
    final recoveryExpired = daysLeft != null && daysLeft <= 0;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: colorScheme.destructive
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.lock,
                            size: 44,
                            color: colorScheme.destructive,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Account Frozen',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.h3
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recoveryExpired
                            ? 'The recovery window has closed. Your personal '
                                'data will be deleted shortly.'
                            : 'You asked to delete this account. You can still '
                                'recover it or download your data.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.muted,
                      ),
                      const SizedBox(height: 24),
                      _Timeline(
                        theme: theme,
                        colorScheme: colorScheme,
                        daysLeft: daysLeft,
                        recoveryExpired: recoveryExpired,
                        retentionEnd: widget.personalDataRetainedUntil,
                      ),
                      const SizedBox(height: 20),
                      ShadButton.outline(
                        height: 48,
                        enabled: !_isDownloading,
                        onPressed: _onDownload,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isDownloading)
                              SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            else
                              Icon(
                                LucideIcons.download,
                                size: 16,
                                color: colorScheme.foreground,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isDownloading
                                  ? 'Preparing...'
                                  : 'Download your data',
                              style: TextStyle(
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!recoveryExpired)
                ShadButton(
                  width: double.infinity,
                  height: 48,
                  enabled: !_isRecovering,
                  onPressed: _onRecover,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRecovering)
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primaryForeground,
                          ),
                        )
                      else
                        Icon(
                          LucideIcons.rotateCcw,
                          size: 16,
                          color: colorScheme.primaryForeground,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecovering ? 'Recovering...' : 'Recover my account',
                        style: TextStyle(
                          color: colorScheme.primaryForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              ShadButton.ghost(
                width: double.infinity,
                height: 44,
                enabled: !_isSigningOut,
                onPressed: _onSignOut,
                child: Text(
                  _isSigningOut ? 'Signing out...' : 'Sign out',
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int? _daysUntil(int? epochMs) {
    if (epochMs == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = epochMs - now;
    if (diffMs <= 0) return 0;
    return (diffMs / (24 * 60 * 60 * 1000)).ceil();
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.theme,
    required this.colorScheme,
    required this.daysLeft,
    required this.recoveryExpired,
    required this.retentionEnd,
  });

  final ShadThemeData theme;
  final ShadColorScheme colorScheme;
  final int? daysLeft;
  final bool recoveryExpired;
  final int? retentionEnd;

  @override
  Widget build(BuildContext context) {
    final retentionDate = retentionEnd == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(retentionEnd!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            theme: theme,
            colorScheme: colorScheme,
            icon: recoveryExpired ? LucideIcons.circleX : LucideIcons.clock,
            color: recoveryExpired
                ? colorScheme.destructive
                : colorScheme.primary,
            title: recoveryExpired
                ? 'Recovery window closed'
                : daysLeft != null
                    ? '$daysLeft day${daysLeft == 1 ? '' : 's'} left to recover'
                    : 'You can still recover',
            subtitle: recoveryExpired
                ? null
                : 'Recover anytime within this window.',
          ),
          const SizedBox(height: 12),
          _Row(
            theme: theme,
            colorScheme: colorScheme,
            icon: LucideIcons.trash2,
            color: colorScheme.mutedForeground,
            title: retentionDate == null
                ? 'Data deletion pending'
                : 'Data deletion on ${_format(retentionDate)}',
            subtitle: 'Everything is removed after 90 days.',
          ),
        ],
      ),
    );
  }

  static String _format(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.colorScheme,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  final ShadThemeData theme;
  final ShadColorScheme colorScheme;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.small
                    .copyWith(fontWeight: FontWeight.w700),
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
      ],
    );
  }
}
