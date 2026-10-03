import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';

class TeamOnboardingScreen extends StatefulWidget {
  const TeamOnboardingScreen({super.key});

  @override
  State<TeamOnboardingScreen> createState() => _TeamOnboardingScreenState();
}

class _TeamOnboardingScreenState extends State<TeamOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Sample invitation data
  final List<InvitationItem> _invitations = [
    InvitationItem(
      id: '1',
      businessName: 'ABC Plumbing Services',
      ownerName: 'John Smith',
      ownerEmail: 'john@abcplumbing.com',
      role: 'Admin',
      invitedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    InvitationItem(
      id: '2',
      businessName: 'Quick Fix Electricians',
      ownerName: 'Sarah Johnson',
      ownerEmail: 'sarah@quickfix.com',
      role: 'Customer Support',
      invitedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    InvitationItem(
      id: '3',
      businessName: 'Home Renovations Ltd',
      ownerName: 'Mike Williams',
      ownerEmail: 'mike@homereno.com',
      role: 'Admin',
      invitedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onScanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      _handleScannedCode(result);
    }
  }

  void _handleScannedCode(String code) {
    debugPrint('Scanned QR Code: $code');
    CommonToasts.success(context, 'Code: $code', title: 'QR Code Scanned');
  }

  void _showAcceptDialog(InvitationItem invitation) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showShadDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.userCheck,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Accept Invitation?',
                      style: theme.textTheme.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'You will join "${invitation.businessName}" as ${invitation.role}. '
                      'You will be able to manage the app under ${invitation.ownerName}\'s supervision.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 24),
                    ShadButton(
                      width: double.infinity,
                      height: 48,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _acceptInvitation(invitation);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 18,
                            color: colorScheme.primaryForeground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accept',
                            style: TextStyle(
                              color: colorScheme.primaryForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ShadButton.outline(
                      width: double.infinity,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclineDialog(InvitationItem invitation) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showShadDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: colorScheme.destructive.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.destructive.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.userX,
                        color: colorScheme.destructive,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Decline Invitation?',
                      style: theme.textTheme.h4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.destructive,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Are you sure you want to decline the invitation from "${invitation.businessName}"? '
                      'This action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 24),
                    ShadButton.destructive(
                      width: double.infinity,
                      height: 48,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _declineInvitation(invitation);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.x,
                            size: 18,
                            color: colorScheme.destructiveForeground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Decline',
                            style: TextStyle(
                              color: colorScheme.destructiveForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ShadButton.outline(
                      width: double.infinity,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptInvitation(InvitationItem invitation) {
    setState(() {
      _invitations.removeWhere((i) => i.id == invitation.id);
    });

    CommonToasts.success(
      context,
      'You have joined ${invitation.businessName}',
      title: 'Invitation Accepted',
    );

    debugPrint('Accepted invitation: ${invitation.businessName}');
    debugPrint('Role: ${invitation.role}');
    debugPrint('Owner: ${invitation.ownerName}');
  }

  void _declineInvitation(InvitationItem invitation) {
    setState(() {
      _invitations.removeWhere((i) => i.id == invitation.id);
    });

    CommonToasts.info(
      context,
      'The invitation has been declined.',
      title: 'Invitation Declined',
    );

    debugPrint('Declined invitation: ${invitation.businessName}');
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 550;
    if (deviceInfo.isTablet) return 500;
    return 450;
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              // Modern AppBar
              _buildAppBar(theme, deviceInfo),

              // Scrollable content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: _getContentPadding(deviceInfo),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _getMaxWidth(deviceInfo),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section
                            _buildHeaderSection(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                            // QR Code Section
                            _buildQRCodeSection(theme, isDark, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                            // Divider
                            _buildDivider(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                            // Invitations Section
                            _buildInvitationsSection(theme, isDark, deviceInfo),
                          ],
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
    );
  }

  Widget _buildAppBar(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Center(
              child: Text(
                'Team Onboarding',
                style: (deviceInfo.isTablet
                        ? theme.textTheme.h2
                        : theme.textTheme.h3)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShadButton.ghost(
              width: 44,
              height: 44,
              padding: EdgeInsets.zero,
              onPressed: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
              child: Icon(
                LucideIcons.logOut,
                size: deviceInfo.isTablet ? 22 : 20,
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon
        Container(
          padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.userPlus,
            size: deviceInfo.isTablet ? 56 : 48,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 28 : 24),

        // Title
        Text(
          'Waiting for Onboarding',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: deviceInfo.isTablet ? 16 : 12),

        // Description
        Text(
          'As an Admin or Customer Support, you need to be added to a business team by the owner. '
          'Scan a QR code from the owner\'s app or wait for an email invitation.',
          style: theme.textTheme.muted,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQRCodeSection(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 28 : 24),
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
      child: Column(
        children: [
          // QR Icon
          Container(
            padding: EdgeInsets.all(deviceInfo.isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(
                deviceInfo.isTablet ? 20 : 18,
              ),
            ),
            child: Icon(
              LucideIcons.qrCode,
              size: deviceInfo.isTablet ? 72 : 64,
              color: theme.colorScheme.foreground,
            ),
          ),
          SizedBox(height: deviceInfo.isTablet ? 24 : 20),

          // Title
          Text(
            'Scan QR Code',
            style:
                (deviceInfo.isTablet ? theme.textTheme.h3 : theme.textTheme.h4)
                    .copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: deviceInfo.isTablet ? 10 : 8),

          // Description
          Text(
            'Ask the business owner to show their team QR code and scan it to join instantly.',
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: deviceInfo.isTablet ? 24 : 20),

          // Scan Button
          ShadButton(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            onPressed: _onScanQRCode,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.scanLine,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.primaryForeground,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: theme.colorScheme.primaryForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: theme.colorScheme.border)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: deviceInfo.isTablet ? 20 : 16,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Or', style: theme.textTheme.muted),
          ),
        ),
        Expanded(child: Container(height: 1, color: theme.colorScheme.border)),
      ],
    );
  }

  Widget _buildInvitationsSection(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Invitations',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.h3
                          : theme.textTheme.h4)
                      .copyWith(fontWeight: FontWeight.bold),
            ),
            if (_invitations.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: deviceInfo.isTablet ? 14 : 12,
                  vertical: deviceInfo.isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${_invitations.length}',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: deviceInfo.isTablet ? 10 : 8),
        Text(
          'Invitations sent to your email will appear here.',
          style: theme.textTheme.muted,
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),

        // Invitations List
        if (_invitations.isEmpty)
          _buildEmptyInvitations(theme, isDark, deviceInfo)
        else
          ..._invitations.map(
            (invitation) => Padding(
              padding: EdgeInsets.only(bottom: deviceInfo.isTablet ? 16 : 12),
              child: _buildInvitationCard(
                theme,
                isDark,
                deviceInfo,
                invitation,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyInvitations(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 40 : 32),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.5)
            : theme.colorScheme.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.inbox,
              size: deviceInfo.isTablet ? 48 : 40,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),
          Text(
            'No pending invitations',
            style:
                (deviceInfo.isTablet
                        ? theme.textTheme.large
                        : theme.textTheme.p)
                    .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: deviceInfo.isTablet ? 6 : 4),
          Text(
            'When a business owner invites you, it will appear here.',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
    InvitationItem invitation,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Avatar
              Container(
                width: deviceInfo.isTablet ? 56 : 48,
                height: deviceInfo.isTablet ? 56 : 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    deviceInfo.isTablet ? 16 : 14,
                  ),
                ),
                child: Center(
                  child: Text(
                    invitation.businessName[0].toUpperCase(),
                    style:
                        (deviceInfo.isTablet
                                ? theme.textTheme.h3
                                : theme.textTheme.h4)
                            .copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 16 : 12),

              // Business Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.businessName,
                      style:
                          (deviceInfo.isTablet
                                  ? theme.textTheme.large
                                  : theme.textTheme.p)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 4 : 2),
                    Text(
                      'Invited by ${invitation.ownerName}',
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              // Time ago
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTimeAgo(invitation.invitedAt),
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 16 : 12),

          // Role Badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: deviceInfo.isTablet ? 12 : 10,
                  vertical: deviceInfo.isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: invitation.role == 'Admin'
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(10),
                  border: invitation.role == 'Admin'
                      ? Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      invitation.role == 'Admin'
                          ? LucideIcons.userCog
                          : LucideIcons.headphones,
                      size: deviceInfo.isTablet ? 16 : 14,
                      color: invitation.role == 'Admin'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.foreground,
                    ),
                    SizedBox(width: deviceInfo.isTablet ? 8 : 6),
                    Text(
                      invitation.role,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: invitation.role == 'Admin'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 10 : 8),
              Icon(
                LucideIcons.mail,
                size: deviceInfo.isTablet ? 16 : 14,
                color: theme.colorScheme.mutedForeground,
              ),
              SizedBox(width: deviceInfo.isTablet ? 6 : 4),
              Expanded(
                child: Text(
                  invitation.ownerEmail,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  height: deviceInfo.isTablet ? 44 : 40,
                  onPressed: () => _showDeclineDialog(invitation),
                  child: const Text('Decline'),
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 16 : 12),
              Expanded(
                child: ShadButton(
                  width: double.infinity,
                  height: deviceInfo.isTablet ? 44 : 40,
                  onPressed: () => _showAcceptDialog(invitation),
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: theme.colorScheme.primaryForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvitationItem {
  final String id;
  final String businessName;
  final String ownerName;
  final String ownerEmail;
  final String role;
  final DateTime invitedAt;

  const InvitationItem({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.ownerEmail,
    required this.role,
    required this.invitedAt,
  });
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isScanned = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() {
        _isScanned = true;
      });

      final code = barcodes.first.rawValue!;
      Navigator.pop(context, code);
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  void _switchCamera() {
    _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return _buildErrorWidget(theme, error);
            },
          ),

          // Overlay
          _buildScannerOverlay(theme),

          // Top Bar
          _buildTopBar(theme),

          // Bottom Controls
          _buildBottomControls(theme),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ShadThemeData theme, MobileScannerException error) {
    String message;
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        message =
            'Camera permission denied.\nPlease enable camera access in settings.';
        break;
      case MobileScannerErrorCode.unsupported:
        message = 'Camera not supported on this device.';
        break;
      default:
        message = 'An error occurred while accessing the camera.';
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.destructive.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.cameraOff,
                  size: 56,
                  color: theme.colorScheme.destructive,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Access Required',
                style: theme.textTheme.h3.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.muted.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ShadButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(ShadThemeData theme) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ShadThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close Button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Scan QR Code',
                style: theme.textTheme.p.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Placeholder for symmetry
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ShadThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Point your camera at the QR code shown on the business owner\'s device',
                  style: theme.textTheme.small.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Torch Button
                  Container(
                    decoration: BoxDecoration(
                      color: _isTorchOn
                          ? theme.colorScheme.primary
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn ? LucideIcons.zapOff : LucideIcons.zap,
                        color: Colors.white,
                      ),
                      onPressed: _toggleTorch,
                    ),
                  ),
                  const SizedBox(width: 32),

                  // Switch Camera Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.switchCamera,
                        color: Colors.white,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
