import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../repositories/account/account_repository.dart';

/// Lets a signed-in user delete their account, downloading their data first
/// if they want a copy.
///
/// This is a HARD delete and takes effect immediately. It goes through
/// AuthBloc → AuthRepository.deleteAccountCompletely(), which removes the
/// user's storage objects and then invokes the `account-delete` Edge
/// Function; that calls admin.auth.admin.deleteUser, and the auth row
/// cascades to `profiles` (FK ON DELETE CASCADE) and from there to every
/// owner_id-scoped table.
///
/// The pro app's soft delete — flag `deletion_pending`, keep the account
/// recoverable for 14 days, purge after 90 — is deliberately NOT used here.
/// It left the auth user in place, so the address stayed claimed and signing
/// up again with it failed as "already registered". Deleting means deleting.
///
/// Store (App Store / Play) subscriptions are still not cancelled by this —
/// those live in the user's store account, and a customer has none anyway.
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
          'This permanently deletes your account and all of your data right '
          'now. It cannot be undone and the account cannot be recovered. '
          'Download your data first if you want a copy.',
      icon: LucideIcons.circleAlert,
      yesText: 'Yes, Delete Account',
      noText: 'Cancel',
      onConfirm: _executeDelete,
    );
  }

  void _executeDelete() {
    if (!mounted) return;
    setState(() => _isDeleting = true);
    // DeleteAccountRequested runs the hard delete and, on success, re-runs
    // handleAuthentication — which finds no user and lands on sign in.
    // The BlocListener below reports failure.
    context.read<AuthBloc>().add(const DeleteAccountRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, current) =>
          current is DeleteAccountErrorState ||
          current is DeleteAccountSuccessState,
      listener: (context, state) async {
        if (!mounted) return;
        setState(() => _isDeleting = false);
        if (state is DeleteAccountErrorState) {
          await CommonDialogs.showErrorDialog(
            context,
            title: 'Deletion Failed',
            message: state.errorMessage,
          );
        }
        // On success the bloc re-runs handleAuthentication, which finds no
        // signed-in user and replaces the stack with sign in — so there is
        // nothing to do here but stop the spinner.
      },
      child: _buildScaffold(context, theme, colorScheme),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ShadThemeData theme,
    ShadColorScheme colorScheme,
  ) {
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
              'Deleting your account removes it and all of your data '
              'immediately. There is no recovery period — this cannot be '
              'undone.',
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
        icon: LucideIcons.trash2,
        text: 'Your account and all of your data are deleted immediately.'
      ),
      (
        icon: LucideIcons.circleX,
        text: 'There is no recovery period — this cannot be undone.'
      ),
      (
        icon: LucideIcons.download,
        text: 'Download your data first if you want to keep a copy.'
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
