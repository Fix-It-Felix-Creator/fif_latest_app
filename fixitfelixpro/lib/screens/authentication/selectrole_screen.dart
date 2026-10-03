import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../core/enum.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/common_toasts.dart';
import '../../repositories/authentication/authentication_repository.dart';
import 'business/user_details_screen.dart';
import 'tradesman/user_details_screen.dart';

class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

  void _showExitDialog(BuildContext context) {
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
                  color: Colors.orange.withValues(alpha: 0.1),
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
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.doorOpen,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Leave Account Setup?',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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
                      'You have started creating an account. What would you like to do?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 24),
                    _buildDialogButton(
                      theme,
                      label: 'Keep Account',
                      icon: LucideIcons.userCheck,
                      isPrimary: true,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    const SizedBox(height: 12),
                    _buildDialogButton(
                      theme,
                      label: 'Delete Account',
                      icon: LucideIcons.trash2,
                      isDestructive: true,
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await _deleteAccountAndNavigate(context);
                      },
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

  Widget _buildDialogButton(
    ShadThemeData theme, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    if (isPrimary) {
      return ShadButton(
        width: double.infinity,
        height: 48,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primaryForeground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive
              ? theme.colorScheme.destructive.withValues(alpha: 0.3)
              : theme.colorScheme.border,
          width: 1.5,
        ),
      ),
      child: ShadButton.outline(
        width: double.infinity,
        height: 48,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive
                  ? theme.colorScheme.destructive
                  : theme.colorScheme.foreground,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? theme.colorScheme.destructive
                    : theme.colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccountAndNavigate(BuildContext context) async {
    final authRepository = context.read<AuthRepository>();
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showShadDialog(
      context: context,
      builder: (loadingContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorScheme.destructive.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.destructive,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Deleting Account',
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we delete your account...',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await authRepository.deleteAccountCompletely();
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        CommonToasts.info(
          context,
          'Your account has been removed.',
          title: 'Account Deleted',
        );
      }
      if (context.mounted) {
        context.read<AuthBloc>().add(const HandleAuthentication());
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        CommonToasts.error(context, 'Failed to delete account: $e');
      }
    }
  }

  void _onRoleSelected(BuildContext context, AccountCategoryType accountType) {
    final Map<String, dynamic> userData = {
      'accountCategoryType': accountType.name,
    };

    final Widget screen = switch (accountType) {
      AccountCategoryType.tradesman => TradesmanUserDetailsScreen(
        userData: userData,
      ),
      AccountCategoryType.business => BusinessUserDetailsScreen(
        userData: userData,
      ),
      AccountCategoryType.customer => const SizedBox.shrink(),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        color: theme.colorScheme.background,
        child: SafeArea(
          child: Column(
            children: [
              // Modern AppBar
              _buildAppBar(theme, deviceInfo),

              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: _getResponsivePadding(deviceInfo),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _getMaxWidth(deviceInfo),
                        ),
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
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShadButton.ghost(
              width: deviceInfo.isTablet ? 48 : 44,
              height: deviceInfo.isTablet ? 48 : 44,
              padding: EdgeInsets.zero,
              onPressed: () => _showExitDialog(context),
              child: Icon(
                LucideIcons.chevronLeft,
                size: deviceInfo.isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Create Account',
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
    if (deviceInfo.isTablet && deviceInfo.isLandscape) return 900;
    if (deviceInfo.isTablet) return 600;
    return 500;
  }

  Widget _buildContent(
    BuildContext context,
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final roleCards = [
      _ModernRoleCard(
        index: 0,
        icon: LucideIcons.wrench,
        title: 'Tradesman',
        description:
            'Showcase your skills and connect with customers looking for your services',
        accentColor: Colors.orange,
        isSelected: _selectedIndex == 0,
        onTap: () {
          setState(() => _selectedIndex = 0);
          Future.delayed(const Duration(milliseconds: 200), () {
            _onRoleSelected(context, AccountCategoryType.tradesman);
          });
        },
        isTablet: deviceInfo.isTablet,
        isDark: isDark,
      ),
      _ModernRoleCard(
        index: 1,
        icon: LucideIcons.building2,
        title: 'Business',
        description:
            'Manage your trade business, team members, and grow your client base',
        accentColor: Colors.purple,
        isSelected: _selectedIndex == 1,
        onTap: () {
          setState(() => _selectedIndex = 1);
          Future.delayed(const Duration(milliseconds: 200), () {
            _onRoleSelected(context, AccountCategoryType.business);
          });
        },
        isTablet: deviceInfo.isTablet,
        isDark: isDark,
      ),
    ];

    // Tablet landscape: grid layout
    if (deviceInfo.isTablet && deviceInfo.isLandscape) {
      return Column(
        children: [
          // Header icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              LucideIcons.userPlus,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'What type of account do you want?',
            style: theme.textTheme.h2.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Choose the account type that best describes how you will use FixItFelix Pro.',
            style: theme.textTheme.muted.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: roleCards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: card,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    // Portrait: vertical list
    return Column(
      children: [
        // Header icon
        Container(
          padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            LucideIcons.userPlus,
            size: deviceInfo.isTablet ? 40 : 32,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 32 : 24),
        Text(
          'What type of account do you want?',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Choose the account type that best describes how you will use FixItFelix Pro.',
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 40 : 32),
        ...roleCards.map(
          (card) =>
              Padding(padding: const EdgeInsets.only(bottom: 16), child: card),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ModernRoleCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isTablet;
  final bool isDark;

  const _ModernRoleCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    this.isTablet = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final deviceInfo = context.deviceInfo;
    final isLandscapeTablet = deviceInfo.isTablet && deviceInfo.isLandscape;

    // Landscape tablet: vertical card (compact)
    if (isLandscapeTablet) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.card.withValues(alpha: 0.8)
              : theme.colorScheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : theme.colorScheme.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(icon, size: 26, color: accentColor),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select',
                          style: theme.textTheme.small.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Portrait / Mobile: horizontal card (compact)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? accentColor
              : theme.colorScheme.border.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 14 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 48 : 42,
                  height: isTablet ? 48 : 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 22 : 20,
                    color: accentColor,
                  ),
                ),
                SizedBox(width: isTablet ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.p
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                          height: 1.3,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: isTablet ? 18 : 16,
                    color: accentColor,
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
