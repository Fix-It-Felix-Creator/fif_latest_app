import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/leads/lead_application_bloc.dart';
import '../../core/config/config_service.dart';
import '../../core/config/support_config.dart';
import '../../core/enum.dart';
import '../leads/leads_journey.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/member_subscription_model.dart';
import '../subscription/choose_plan_screen.dart';
import '../../models/notification_preferences_model.dart';
import '../../repositories/authentication/authentication_repository.dart';
import '../../services/iap_service.dart';
import '../../widgets/banners/learn_banner.dart';
import '../../widgets/common/current_plan_card.dart';
import '../../widgets/common/settings_menu_item.dart';
import 'support/contact_support_sheet.dart';

/// Thin wrapper kept around so the existing `/settings` route (used by
/// the owner-home gear icon) still works. The actual UI lives in
/// [SettingsBody] so the tradesman Profile tab can host the same
/// content without duplication.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        title: const Text('Settings'),
      ),
      body: const SettingsBody(),
    );
  }
}

/// All the iOS-style account/notifications/support tiles + the
/// destructive footer (Sign out / Delete account). Self-contained —
/// drops cleanly into either the `/settings` route or any tab body.
class SettingsBody extends StatefulWidget {
  const SettingsBody({super.key});

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  bool _isSigningOut = false;

  /// Own the scroll controller so we don't fight with the surrounding
  /// `PrimaryScrollController` — when this body is hosted inside a
  /// tab subtree (Profile tab), the default `primary: true` would
  /// attach a second `ScrollPosition` to the inherited controller and
  /// blow up the Scrollbar painter.
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// The App Store / Play Store own subscription cancellation — deep-link
  /// to the system subscription manager. (Reached only for paid IAP subs;
  /// the trial has nothing to cancel.) See [ChoosePlanScreen] for the same
  /// flow.
  Future<void> _onCancelSubscription(MemberSubscriptionModel member) async {
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Manage Subscription',
      message:
          'To cancel your ${member.name} plan, open your store '
          'subscriptions. You will keep access until the end of the '
          'current period.',
      icon: LucideIcons.circleAlert,
      yesText: 'Open Subscriptions',
      noText: 'Not Now',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    try {
      final uri = Uri.parse(IapService.manageSubscriptionsUrl());
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        CommonToasts.error(
          context,
          'Couldn\'t open subscriptions. Manage it from your device\'s '
          'store subscription settings.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      CommonToasts.error(
        context,
        'Couldn\'t open subscriptions. Manage it from your device\'s '
        'store subscription settings.',
      );
    }
  }

  void _openSubscriptionScreen(AccountCategoryType? accountType) {
    final route = accountType == AccountCategoryType.business
        ? '/businessSubscription'
        : '/tradesmanSubscription';
    // `fromSettings: true` flips the screen into the back-button /
    // no-sign-out variant so the user returns to settings on success
    // instead of getting kicked to home with the stack cleared.
    Navigator.of(context).pushNamed(
      route,
      arguments: const ChoosePlanArgs(fromSettings: true),
    );
  }

  Future<void> _onSignOut() async {
    if (_isSigningOut) return;
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
            message: '$e',
          );
        }
      },
    );
  }

  void _updateNotificationPref({
    bool? push,
    bool? email,
    bool? sms,
  }) {
    final current =
        context.read<AuthBloc>().state.userDetails?.notificationPreferences ??
        const NotificationPreferencesModel();
    final updated = current.copyWith(
      pushEnabled: push,
      emailEnabled: email,
      smsEnabled: sms,
    );
    context.read<AuthBloc>().add(
      UpdateUserDetailsRequested(
        updates: {'notificationPreferences': updated.toJson()},
      ),
    );
  }

  Future<void> _openUrl(String url, {required String title}) async {
    Navigator.of(context).pushNamed(
      '/settings/webPage',
      arguments: {'title': title, 'url': url},
    );
  }

  Future<void> _rateApp() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: kAppStoreId);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not open app rating: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not open app rating');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.userDetails;
        final member = user?.subscription?.member;
        final prefs =
            user?.notificationPreferences ??
            const NotificationPreferencesModel();

        return SingleChildScrollView(
          controller: _scrollCtrl,
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Current subscription plan ----
              if (member != null)
                CurrentPlanCard(
                  member: member,
                  isCancelling: false,
                  onCancel: () => _onCancelSubscription(member),
                  onTap: () => _openSubscriptionScreen(user?.accountType),
                  showCancelButton: false,
                )
              else
                _NoPlanCard(
                  onTap: () => _openSubscriptionScreen(user?.accountType),
                ),

              const SizedBox(height: 16),

              // ---- Community banner ----
              LearnBanner(
                imageAsset: 'assets/images/banner/facebook_group.jpg',
                title: 'Fix It Felix Community',
                body: 'Connect with tradespeople, share knowledge, learn '
                    'business tips, discover new tools, and grow your '
                    'trade business together using Fix It Felix.',
                url: ConfigService().facebookGroupUrl,
                webviewTitle: 'Facebook',
              ),

              const SizedBox(height: 24),

              // ---- Verification ----
              //
              // The same journey the home card offers, not a second one. It is
              // here as well because Settings is where somebody looks for
              // "the state of my account", and because a card on the home tab
              // is easy to scroll past and never think about again.
              _SectionHeader(title: 'Verification'),
              BlocBuilder<LeadApplicationBloc, LeadApplicationState>(
                buildWhen: (a, b) =>
                    a.application?.status != b.application?.status,
                builder: (context, leads) {
                  final verification = user?.verificationStatus;
                  return SettingsMenuItem(
                    item: SettingsItemData(
                      icon: LucideIcons.badgeCheck,
                      title: 'Verify your account',
                      subtitle: LeadsJourney.subtitle(leads, verification),
                      iconColor: LeadsJourney.tint(leads, verification),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LeadsJourney.destination(
                            leads,
                            verification,
                            // The row says "Verify your account". The screen
                            // says the same.
                            title: 'Verification',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // ---- Account ----
              _SectionHeader(title: 'Account'),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.userRound,
                  title: 'Personal Information',
                  subtitle: 'First name, last name, phone, email',
                  iconColor: _SettingsPalette.indigo,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/settings/personalInfo'),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.building2,
                  title: 'Company Details',
                  subtitle: user?.companyDetails?.companyName.isNotEmpty == true
                      ? user!.companyDetails!.companyName
                      : 'Logo, name, VAT, business address',
                  iconColor: _SettingsPalette.teal,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/settings/company'),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.landmark,
                  title: 'Bank Details',
                  subtitle: user?.companyDetails?.bankDetails?.isNotEmpty ==
                          true
                      ? user!.companyDetails!.bankDetails!.bankName
                      : 'Payment details for quotes and invoices',
                  iconColor: _SettingsPalette.emerald,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/settings/bank'),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.mapPin,
                  title: 'Address Details',
                  subtitle: user?.address.isValid == true
                      ? user!.address.formatted
                      : 'Set your address',
                  iconColor: _SettingsPalette.rose,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/settings/address'),
                ),
              ),

              const SizedBox(height: 8),
              _SectionHeader(title: 'Notifications'),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.bell,
                  title: 'Push Notifications',
                  subtitle: 'Alerts on this device',
                  iconColor: _SettingsPalette.red,
                  showChevron: false,
                  trailing: SettingsToggle(
                    value: prefs.pushEnabled,
                    onChanged: (v) => _updateNotificationPref(push: v),
                  ),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.mail,
                  title: 'Email Notifications',
                  subtitle: 'Updates sent to your email',
                  iconColor: _SettingsPalette.sky,
                  showChevron: false,
                  trailing: SettingsToggle(
                    value: prefs.emailEnabled,
                    onChanged: (v) => _updateNotificationPref(email: v),
                  ),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.messageSquare,
                  title: 'SMS Notifications',
                  subtitle: 'Text messages for important alerts',
                  iconColor: _SettingsPalette.green,
                  showChevron: false,
                  trailing: SettingsToggle(
                    value: prefs.smsEnabled,
                    onChanged: (v) => _updateNotificationPref(sms: v),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              _SectionHeader(title: 'Support'),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.circleQuestionMark,
                  title: 'Help Center',
                  iconColor: _SettingsPalette.cyan,
                  onTap: () => _openUrl(
                    resolveHelpCenterUrl(),
                    title: 'Help Center',
                  ),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.headset,
                  title: 'Contact Support',
                  iconColor: _SettingsPalette.violet,
                  onTap: () => showContactSupportSheet(context),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.scrollText,
                  title: 'Terms and Conditions',
                  iconColor: _SettingsPalette.slate,
                  onTap: () => _openUrl(
                    resolveTermsUrl(),
                    title: 'Terms and Conditions',
                  ),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.shield,
                  title: 'Privacy Policy',
                  iconColor: _SettingsPalette.zinc,
                  onTap: () => _openUrl(
                    resolvePrivacyPolicyUrl(),
                    title: 'Privacy Policy',
                  ),
                ),
              ),
              SettingsMenuItem(
                item: SettingsItemData(
                  icon: LucideIcons.star,
                  title: 'Rate Us',
                  iconColor: _SettingsPalette.amber,
                  onTap: _rateApp,
                ),
              ),

              const SizedBox(height: 24),

              // ---- Destructive actions ----
              ShadButton.outline(
                enabled: !_isSigningOut,
                onPressed: _onSignOut,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSigningOut)
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(LucideIcons.logOut, size: 16),
                    const SizedBox(width: 8),
                    Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ShadButton.destructive(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/deleteAccount'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.trash2, size: 16),
                    SizedBox(width: 8),
                    Text('Delete my account'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// iOS Settings–style per-row tile palette. Keeps a consistent saturation
/// and darkness so rows read as a coherent group even though each tile is
/// a different hue.
class _SettingsPalette {
  _SettingsPalette._();

  static const indigo = Color(0xFF6366F1);
  static const teal = Color(0xFF14B8A6);
  static const emerald = Color(0xFF10B981);
  static const green = Color(0xFF22C55E);
  static const sky = Color(0xFF0EA5E9);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const rose = Color(0xFFF43F5E);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const slate = Color(0xFF64748B);
  static const zinc = Color(0xFF71717A);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
      child: Text(
        title,
        style: theme.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.mutedForeground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.crown,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No active plan',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to choose a subscription',
                      style: theme.textTheme.small.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
