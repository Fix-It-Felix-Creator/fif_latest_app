import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../repositories/account/account_repository.dart';

/// Lets a signed-in user request account deletion, download their data,
/// and understand the grace periods first. The actual deletion is a
/// server-side soft-delete:
///   • Store (App Store / Play) subscriptions are NOT cancelled — the
///     user manages those in their store account.
///   • Account is flagged `deletion_pending` in RTDB.
///   • User keeps the ability to sign in during the recovery window —
///     they're routed to the recovery screen when they do.
///   • After `personalDataRetentionDays`, a background job purges data.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _repo = AccountRepository();
  bool _isDownloading = false;
  bool _isDeleting = false;

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

    // Open the system share sheet — user picks Files, Mail, Drive, etc.
    // The file is in the OS temp dir and gets cleaned up automatically.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.filePath!, mimeType: 'application/json')],
        subject: 'Your FixItFelix account data',
        text:
            'This JSON export contains a copy of your profile, subscription '
            'history and payment method info.',
      ),
    );
    if (!mounted) return;
    CommonToasts.info(
      context,
      'Pick where to save or send the file.',
      title: 'Share Your Data',
    );
  }

  Future<void> _onConfirmDelete() async {
    if (_isDeleting) return;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete Account?',
      message:
          'This cancels any active subscription immediately and freezes your '
          'account. You have 14 days to sign back in and recover it before '
          'your data is deleted.',
      icon: LucideIcons.circleAlert,
      yesText: 'Yes, Delete Account',
      noText: 'Cancel',
      onConfirm: _executeDelete,
    );
  }

  Future<void> _executeDelete() async {
    if (!mounted) return;
    setState(() => _isDeleting = true);
    final result = await _repo.requestDeletion();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (!result.success) {
      await CommonDialogs.showErrorDialog(
        context,
        title: 'Deletion Failed',
        message: result.errorMessage ?? 'Could not delete your account.',
      );
      return;
    }

    // Trigger auth re-routing. handleAuthentication picks up the new
    // accountStatus and navigates to the recovery screen.
    if (!mounted) return;
    context.read<AuthBloc>().add(const HandleAuthentication());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.foreground,
        elevation: 0,
        title: const Text('Delete Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoBanner(theme: theme, colorScheme: colorScheme),
            const SizedBox(height: 16),
            _DataRow(
              theme: theme,
              colorScheme: colorScheme,
              isDownloading: _isDownloading,
              onDownload: _onDownload,
            ),
            const SizedBox(height: 24),
            _WhatHappens(theme: theme, colorScheme: colorScheme),
            const SizedBox(height: 28),
            ShadButton.destructive(
              height: 48,
              enabled: !_isDeleting,
              onPressed: _onConfirmDelete,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDeleting)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.destructiveForeground,
                      ),
                    )
                  else
                    Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: colorScheme.destructiveForeground,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isDeleting ? 'Deleting...' : 'Delete my account',
                    style: TextStyle(
                      color: colorScheme.destructiveForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.theme, required this.colorScheme});
  final ShadThemeData theme;
  final ShadColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.destructive.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 18,
            color: colorScheme.destructive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Deleting your account freezes it immediately and cancels any '
              'active subscription. We keep your personal data for 90 days '
              'before permanently deleting it.',
              style: theme.textTheme.small.copyWith(
                color: colorScheme.destructive,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.theme,
    required this.colorScheme,
    required this.isDownloading,
    required this.onDownload,
  });

  final ShadThemeData theme;
  final ShadColorScheme colorScheme;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(
                LucideIcons.share2,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Download your data',
                style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Grab a JSON copy of everything we have on you — profile, '
            'subscription history, payment methods. Pick where to save '
            'it (Files, Drive, Mail, AirDrop, …) via the share sheet.',
            style: theme.textTheme.small.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          ShadButton.outline(
            width: double.infinity,
            enabled: !isDownloading,
            onPressed: onDownload,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDownloading)
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    LucideIcons.share2,
                    size: 16,
                    color: colorScheme.foreground,
                  ),
                const SizedBox(width: 8),
                Text(
                  isDownloading ? 'Preparing...' : 'Share data (JSON)',
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
    );
  }
}

class _WhatHappens extends StatelessWidget {
  const _WhatHappens({required this.theme, required this.colorScheme});
  final ShadThemeData theme;
  final ShadColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String text})>[
      (
        icon: LucideIcons.circleX,
        text: 'Manage or cancel your subscription in your App Store account '
            '— store subscriptions aren\'t cancelled automatically.'
      ),
      (
        icon: LucideIcons.lock,
        text: 'Your account is frozen — you can\'t use the app after this.'
      ),
      (
        icon: LucideIcons.rotateCcw,
        text:
            'You have 14 days to sign back in and recover before we start deleting data.'
      ),
      (
        icon: LucideIcons.trash2,
        text:
            'After 90 days your personal data is permanently removed — this cannot be undone.'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What happens next',
          style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.text,
                    style: theme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
