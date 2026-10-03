import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/config/config_service.dart';
import '../../core/config/support_config.dart';
import '../../core/enum.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/member_subscription_model.dart';
import '../../repositories/authentication/authentication_repository.dart';
import '../../models/config/subscription_plan_config_model.dart';
import '../../services/iap_service.dart';
import '../../services/subscription_config_service.dart';
import '../../widgets/common/current_plan_card.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Route argument for [ChoosePlanScreen]. `fromSettings: true` flips
/// the screen into "managing my plan" mode — back-button on, sign-out
/// CTA off. The default is the forced auth-gate variant.
class ChoosePlanArgs {
  const ChoosePlanArgs({this.fromSettings = false});
  final bool fromSettings;
}

/// Single screen that replaces the legacy multi-tier subscription
/// flows. Shows two options for new users (free 30-day trial + paid
/// Standard plan) and falls back to a paid-only view once the user
/// has used (or had) any subscription record so the trial can't be
/// re-claimed.
///
/// Every word and number on the card comes from `subscription_plans`, via
/// the `app_config.subscriptions` document, so a price or a feature can be
/// changed from the admin panel without a release. [_fallbackPlan] is what
/// shows if that document has never been fetched on this device — a paywall
/// that renders blank because the network is down is worse than one showing
/// last week's copy.
///
/// The price is display copy either way: the store owns the transaction, so
/// this number has to be kept in step with App Store Connect by hand.
class ChoosePlanScreen extends StatefulWidget {
  const ChoosePlanScreen({super.key, this.fromSettings = false});

  /// `true` when pushed from the profile/settings card — adds a back
  /// button and hides the sign-out CTA so the user can return to
  /// settings cleanly. `false` (default) for the post-onboarding /
  /// post-signin gate where there's nowhere to go back to.
  final bool fromSettings;

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  bool _yearly = false;
  List<SubscriptionPlanConfigModel> _plans = const [_fallbackPlan];

  /// The tier a purchase actually goes to.
  ///
  /// Only one is sellable today, and the buy flow is wired to its store
  /// product ids — so the card that carries the button is whichever tier the
  /// config says can be bought, not whichever one is first.
  SubscriptionPlanConfigModel? get _sellablePlan {
    for (final plan in _plans) {
      if (plan.isPurchasable(yearly: _yearly)) return plan;
    }
    return null;
  }
  bool _activatingTrial = false;
  bool _subscribing = false;

  bool get _busy => _activatingTrial || _subscribing;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  /// Not awaited before the first frame on purpose: the fallback is already a
  /// complete, correct-looking card, so the paywall paints immediately and
  /// swaps in the live copy when it arrives. Gating the first frame on a
  /// network read is how a paywall shows a spinner on a cold start.
  Future<void> _loadPlan() async {
    final all = await SubscriptionConfigService().getAllPlanConfigs();
    final tiers = all.values
        .where((p) => p.accountType == AccountCategoryType.tradesman)
        .where((p) => p.isActive && p.availability != 'hidden')
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!mounted || tiers.isEmpty) return;
    setState(() => _plans = tiers);
  }

  Future<void> _activateTrial() async {
    if (_busy) return;
    setState(() => _activatingTrial = true);
    try {
      final session = SupabaseService().auth.currentSession;
      if (session == null) {
        if (!mounted) return;
        CommonToasts.error(context, 'Not signed in');
        return;
      }
      final token = session.accessToken;
      final base = ConfigService().stripeBackendUrl;
      if (token.isEmpty || base.isEmpty) {
        if (!mounted) return;
        CommonToasts.error(context, 'Backend not configured');
        return;
      }

      final res = await http.post(
        Uri.parse('$base/subscriptions/activate-trial'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'accountType': 'tradesman',
          'planType': 'standard',
          'billingCycle': 'monthly',
          'subscriptionId': 'tradesman_standard',
          'subscriptionName': 'Standard',
        }),
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        CommonToasts.error(
          context,
          'Could not start your trial. Try again.',
        );
        return;
      }
      // Refresh AuthBloc so the gate sees the new subscription doc on
      // the next route check.
      context.read<AuthBloc>().add(const AuthUserRefreshed());
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _navigateAfterSuccess();
    } catch (_) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not start your trial. Try again.');
    } finally {
      if (mounted) setState(() => _activatingTrial = false);
    }
  }

  Future<void> _subscribe() async {
    if (_busy) return;
    setState(() => _subscribing = true);
    try {
      final result = await IapService().buy(
        IapService.productIdFor(yearly: _yearly),
      );
      if (!mounted) return;
      if (result.cancelled) {
        // Silent — user dismissed the StoreKit sheet on purpose.
        return;
      }
      if (!result.success) {
        CommonToasts.error(
          context,
          result.errorMessage ?? 'Subscription failed',
        );
        return;
      }
      // The validate call already wrote the entitlement server-side
      // before returning success, so AuthBloc should pick it up almost
      // immediately. Still confirm before granting access — never
      // navigate off a raw client result, or a failed verification
      // would bypass the paywall.
      context.read<AuthBloc>().add(const AuthUserRefreshed());
      final confirmed = await _waitForPaidSubscription(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (!confirmed) {
        CommonToasts.error(
          context,
          'We couldn\'t confirm your subscription yet. If you completed '
          'it, it may take a moment — please check again shortly.',
        );
        return;
      }
      _navigateAfterSuccess();
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  /// Re-deliver and re-verify a past purchase (Apple requires a restore
  /// path). On success the entitlement is rewritten server-side and the
  /// auth gate lets the user through.
  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _subscribing = true);
    try {
      await IapService().restore();
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthUserRefreshed());
      final confirmed = await _waitForPaidSubscription(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (confirmed) {
        _navigateAfterSuccess();
      } else {
        CommonToasts.error(
          context,
          'No active subscription was found to restore.',
        );
      }
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  /// Poll the AuthBloc state stream until the user's member sub grants
  /// access (live status + unexpired period, same rule as the auth
  /// gate — a stale expired record with an old transaction id must NOT
  /// pass, or restore "succeeds" here and the gate bounces the user
  /// right back on next launch). Returns `true` if confirmed, `false`
  /// on timeout. The caller MUST NOT grant access on `false`.
  Future<bool> _waitForPaidSubscription({
    required Duration timeout,
  }) async {
    final bloc = context.read<AuthBloc>();
    bool live(AuthState s) =>
        s.userDetails?.subscription?.member?.grantsAccess ?? false;
    if (live(bloc.state)) return true;
    try {
      await bloc.stream.firstWhere(live).timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// After a successful trial activation or subscription, route in
  /// the right direction. Forced-gate variant: clear the stack and
  /// land on home. Settings variant: just pop back so the settings
  /// screen rebuilds with the new plan reflected.
  void _navigateAfterSuccess() {
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/tradesmanHome',
        (route) => false,
      );
    }
  }

  /// Store subscriptions are cancelled by the App Store / Play Store, not
  /// by us — apps may not cancel on the user's behalf. We deep-link to the
  /// system subscription manager. When the user turns off auto-renew there,
  /// the store sends a notification and our webhook flips
  /// `autoRenew=false` / `cancelAtPeriodEnd=true` in RTDB; at period end an
  /// expiry notification flips status to `cancelled` and the auth gate
  /// routes the user back to /choosePlan.
  Future<void> _confirmCancel(MemberSubscriptionModel member) async {
    if (_busy) return;
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Manage Subscription',
      message:
          'To cancel your ${member.name} plan, open your store '
          'subscriptions. You\'ll keep access until the end of the '
          'current billing period.',
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

  Future<void> _onSignOut() async {
    await CommonDialogs.showWarningBox(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      icon: LucideIcons.logOut,
      yesText: 'Yes, Sign Out',
      noText: 'No',
      onConfirm: () async {
        if (!mounted) return;
        try {
          await context.read<AuthRepository>().signOut();
        } catch (e) {
          if (!mounted) return;
          await CommonDialogs.showErrorDialog(
            context,
            title: 'Sign Out Failed',
            message: '$e',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) => p.userDetails != c.userDetails,
      builder: (context, state) {
        final member = state.userDetails?.subscription?.member;
        // Trial is one-shot. Anyone with a `subscription.member`
        // record (regardless of state) has already opted in once and
        // can't claim the free option again.
        final hasPreviousSubscription = member != null;
        // An active paid subscription gets the manage view (current
        // plan + cancel) instead of the picker. `isPaid` is the trial
        // discriminator — the free trial writes no provider transaction
        // id. A soft-cancel-pending sub (autoRenew=false, status still
        // active) STILL counts as active paid here — the user keeps
        // seeing their plan with the "Cancels on {date}" inline notice
        // until the period expires and the webhook flips status.
        final hasActivePaid = member != null &&
            member.status == SubscriptionStatus.active &&
            member.isPaid;
        return Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: _pageBg,
            foregroundColor: Colors.black,
            elevation: 0,
            // No back arrow on the forced gate variant — there's
            // nowhere meaningful to return to. Settings push enables
            // the system back button so the user can bail out.
            automaticallyImplyLeading: widget.fromSettings,
            title: const Text('Choose your plan'),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActivePaid
                            ? 'Your subscription'
                            : hasPreviousSubscription
                                ? 'Subscribe to keep using Fix It Felix Pro'
                                : 'Pick how you\'d like to start',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasActivePaid
                            ? 'You\'re on the Standard plan. Cancel '
                                'anytime — you\'ll keep access until '
                                'the current period ends.'
                            : hasPreviousSubscription
                                ? 'Your free trial has ended. Subscribe to '
                                    'unlock invoices, quotes and customer '
                                    'tracking.'
                                : 'Try it free for 30 days, or jump straight '
                                    'in with the Standard plan. You can '
                                    'cancel anytime.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Active paid path: full current-plan card + cancel
                // button. The picker is hidden because there's nothing
                // to pick — the user has the plan already.
                if (hasActivePaid) ...[
                  CurrentPlanCard(
                    member: member,
                    isCancelling: false,
                    onCancel: () => _confirmCancel(member),
                    showCancelButton: true,
                  ),
                ] else ...[

                if (!hasPreviousSubscription) ...[
                  _FreeTrialCard(
                    busy: _activatingTrial,
                    onTap: _busy ? null : _activateTrial,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                  // One toggle above the tiers rather than one per card: it
                  // is a single choice that reprices all of them, and three
                  // copies of it would read as three separate settings.
                  _BillingCycleToggle(
                    yearly: _yearly,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _yearly = v),
                  ),
                  const SizedBox(height: 14),
                  for (final plan in _plans) ...[
                    _PlanCard(
                      plan: plan,
                      yearly: _yearly,
                      busy: _subscribing && plan.id == _sellablePlan?.id,
                      onSubscribe: (_busy || !plan.isPurchasable(yearly: _yearly))
                          ? null
                          : _subscribe,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _restore,
                      child: Text(
                        'Restore purchases',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                // Sign-out escape hatch is only for the forced gate
                // variant — when pushed from settings, the back button
                // is the way out.
                if (!widget.fromSettings) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _onSignOut,
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],

                // Apple Guideline 3.1.2(c): auto-renewable subscription
                // screens must carry functional links to the Terms of
                // Use (EULA) and Privacy Policy.
                const SizedBox(height: 20),
                _LegalLinksFooter(onOpen: _openLegal),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not open $url');
    }
  }
}

class _FreeTrialCard extends StatelessWidget {
  const _FreeTrialCard({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Free 30-day trial',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'NO CARD NEEDED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Full access to invoices, quotes and customer tracking '
            'for 30 days. Subscribe before the trial ends to keep going.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: _brand,
                side: const BorderSide(color: _brand),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _brand,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Start free trial'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tier, as the campaign presents it.
///
/// Everything visible comes from the plan row: title, badge, price, tagline
/// and bullets. A tier the campaign lists as coming soon still renders — a
/// paywall that silently omits two of three tiers tells a tradesperson the
/// product is smaller than it is — but it carries no button, because no store
/// has anything to sell them yet.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.busy,
    required this.onSubscribe,
  });

  final SubscriptionPlanConfigModel plan;
  final bool yearly;
  final bool busy;

  /// Null when this tier cannot be bought: coming soon, or no store product.
  final VoidCallback? onSubscribe;

  bool get _sellable => onSubscribe != null || busy;

  @override
  Widget build(BuildContext context) {
    // The highlight follows the tier you can actually act on. Giving a
    // coming-soon tier the brand border would draw the eye to the one card
    // that cannot do anything.
    final highlighted = _sellable;
    final features = plan.features.isEmpty ? _fallbackPlan.features : plan.features;
    final saving = _yearlySaving(plan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? _brand : Colors.grey.shade300,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: highlighted ? Colors.black87 : Colors.grey.shade700,
                  ),
                ),
              ),
              if (plan.badge != null && plan.badge!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? _brand.withValues(alpha: 0.10)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: highlighted ? _brand : Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.priceLabel(yearly: yearly).replaceAll(RegExp(r'/(mo|yr)$'), ''),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? Colors.black87 : Colors.grey.shade700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              if (!plan.isFreePlan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    yearly ? '/ year' : '/ month',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (yearly && saving > 0) ...[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SAVE $saving%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (plan.tagline != null && plan.tagline!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.tagline!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          ...features.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: highlighted ? _brand : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: highlighted ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_sellable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Subscribe ${plan.priceLabel(yearly: yearly)}'),
              ),
            )
          else
            // Not a disabled button. A greyed-out button invites tapping and
            // then does nothing; a line of text says why there is nothing to
            // tap, which is the actual answer.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                plan.isComingSoon ? 'Coming soon' : 'Not available yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillingCycleToggle extends StatelessWidget {
  const _BillingCycleToggle({
    required this.yearly,
    required this.onChanged,
  });

  final bool yearly;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Monthly',
              selected: !yearly,
              enabled: onChanged != null,
              onTap: () => onChanged?.call(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Annually',
              selected: yearly,
              enabled: onChanged != null,
              onTap: () => onChanged?.call(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? _brand : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// Footer carrying the Terms of Use (EULA) and Privacy Policy links
/// that Apple requires on any auto-renewable subscription screen
/// (Guideline 3.1.2(c)). URLs come from [resolveTermsUrl] /
/// [resolvePrivacyPolicyUrl] (Remote Config with site fallback).
class _LegalLinksFooter extends StatelessWidget {
  const _LegalLinksFooter({required this.onOpen});

  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
      decoration: TextDecoration.underline,
    );
    final dotStyle = TextStyle(fontSize: 12, color: Colors.grey.shade400);

    return Column(
      children: [
        Text(
          'Subscriptions renew automatically unless cancelled at least '
          '24 hours before the end of the current period.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => onOpen(resolveTermsUrl()),
              child: Text('Terms of Use', style: linkStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('·', style: dotStyle),
            ),
            GestureDetector(
              onTap: () => onOpen(resolvePrivacyPolicyUrl()),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the paywall shows before the config document has ever been fetched.
///
/// Deliberately the campaign's Standard copy rather than a placeholder: on a
/// cold first launch with no network this IS the paywall, and it should be
/// right. Only one tier, because only one can be bought — a fallback listing
/// tiers nobody can reach would be worse than showing the one that works.
const _fallbackPlan = SubscriptionPlanConfigModel(
  id: 'tradesman_standard',
  name: 'Standard',
  description: 'Built for professionals who want to manage their business, '
      'not just their paperwork.',
  accountType: AccountCategoryType.tradesman,
  planType: PlanType.standard,
  monthlyPrice: 12.99,
  yearlyPrice: 100,
  trialDays: 30,
  badge: 'LIVE — 30-DAY FREE TRIAL',
  tagline: 'Start your 30-Day Standard Package Trial today',
  productIdMonthly: 'fixitfelixpro.standard.monthly',
  productIdYearly: 'fixitfelixpro.standard.yearly',
  features: [
    'Invoicing, quoting & scheduling',
    'Reviews & tradesmen calculators',
    'AI estimator & AI quote generator',
    '1 business location & service area',
    'Up to 2 staff members',
    'No transaction charges',
  ],
);

/// Whole percent saved by paying yearly, or 0 when there is nothing to claim.
///
/// Computed rather than written down: the old card said "SAVE 17%" beside a
/// pair of prices that had since changed, and at £12.99/£100 the real answer
/// is 36%.
int _yearlySaving(SubscriptionPlanConfigModel plan) {
  final monthlyTotal = plan.monthlyPrice * 12;
  if (monthlyTotal <= 0 || plan.yearlyPrice <= 0) return 0;
  if (plan.yearlyPrice >= monthlyTotal) return 0;
  return (((monthlyTotal - plan.yearlyPrice) / monthlyTotal) * 100).round();
}
