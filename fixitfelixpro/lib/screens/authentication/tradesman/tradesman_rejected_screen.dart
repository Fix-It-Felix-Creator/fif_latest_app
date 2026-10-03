import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../repositories/authentication/authentication_repository.dart';

class TradesmanRejectedScreen extends StatefulWidget {
  final String? rejectionReason;

  const TradesmanRejectedScreen({super.key, this.rejectionReason});

  @override
  State<TradesmanRejectedScreen> createState() =>
      _TradesmanRejectedScreenState();
}

class _TradesmanRejectedScreenState extends State<TradesmanRejectedScreen> {
  bool _isResetting = false;
  bool _isSigningOut = false;

  bool get _busy => _isResetting || _isSigningOut;

  Future<void> _onTryAgain() async {
    if (_busy) return;
    setState(() => _isResetting = true);

    try {
      final authRepository = context.read<AuthRepository>();
      await authRepository.deleteUserDetails();

      if (!mounted) return;
      context.read<AuthBloc>().add(const HandleAuthentication());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResetting = false);
      await CommonDialogs.showErrorDialog(
        context,
        title: 'Reset Failed',
        message: 'Failed to reset application: $e',
      );
    }
  }

  Future<void> _onSignOut() async {
    if (_busy) return;
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
    final hasReason = widget.rejectionReason != null &&
        widget.rejectionReason!.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: _getContentPadding(deviceInfo),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _getMaxWidth(deviceInfo),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.circleX,
                            color: theme.colorScheme.destructive,
                            size: deviceInfo.isTablet ? 56 : 48,
                          ),
                          SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                          Text(
                            'Application Rejected',
                            style: (deviceInfo.isTablet
                                    ? theme.textTheme.h2
                                    : theme.textTheme.h3)
                                .copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your tradesman application was not approved.',
                            style: theme.textTheme.muted,
                            textAlign: TextAlign.center,
                          ),
                          if (hasReason) ...[
                            SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                            Divider(
                              color: theme.colorScheme.border
                                  .withValues(alpha: 0.5),
                              height: 1,
                            ),
                            SizedBox(height: deviceInfo.isTablet ? 16 : 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Reason',
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.destructive,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.rejectionReason!,
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.foreground,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: _getContentPadding(deviceInfo),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShadButton(
                          width: double.infinity,
                          height: deviceInfo.isTablet ? 52 : 48,
                          enabled: !_busy,
                          onPressed: _onTryAgain,
                          child: _isResetting
                              ? _ButtonLoading(
                                  color: theme.colorScheme.primaryForeground,
                                  label: 'Resetting...',
                                  isTablet: deviceInfo.isTablet,
                                )
                              : Text(
                                  'Try Again',
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.primaryForeground,
                                    fontWeight: FontWeight.w600,
                                    fontSize: deviceInfo.isTablet ? 16 : 15,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        ShadButton.ghost(
                          width: double.infinity,
                          height: 44,
                          enabled: !_busy,
                          onPressed: _onSignOut,
                          child: _isSigningOut
                              ? _ButtonLoading(
                                  color: theme.colorScheme.mutedForeground,
                                  label: 'Signing out...',
                                  isTablet: deviceInfo.isTablet,
                                )
                              : Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: theme.colorScheme.mutedForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
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
    );
  }
}

class _ButtonLoading extends StatelessWidget {
  const _ButtonLoading({
    required this.color,
    required this.label,
    this.isTablet = false,
  });

  final Color color;
  final String label;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 16 : 15,
          ),
        ),
      ],
    );
  }
}
