import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/enum.dart';
import '../../models/member_subscription_model.dart';

/// Card showing the current member subscription plan.
/// Tapping the card (via [onTap]) navigates to the upgrade/cancel flow.
class CurrentPlanCard extends StatelessWidget {
  const CurrentPlanCard({
    super.key,
    required this.member,
    this.isCancelling = false,
    this.onCancel,
    this.onTap,
    this.showCancelButton = true,
  });

  final MemberSubscriptionModel member;
  final bool isCancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;
  final bool showCancelButton;

  /// True when this subscription is the free trial — the cloud function
  /// `activateTrial` writes no provider transaction id, whereas a paid
  /// IAP/Stripe sub does. `isPaid` is the canonical discriminator
  /// (status is still 'active' with a 30-day window during the trial).
  bool get _isTrial => !member.isPaid;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = member.status == SubscriptionStatus.active;
    final isCancelled = member.status == SubscriptionStatus.cancelled;
    final isYearly = member.billingCycle == BillingCycle.yearly;
    final isTrial = _isTrial;
    // Same blue used for the card border / cancel-notice — keeps every
    // accent on the plan card in one cool palette so the brand orange
    // can stay reserved for primary CTAs elsewhere.
    final accent = Colors.blue.shade600;
    final statusColor = isTrial
        ? accent
        : isActive
        ? Colors.green.shade600
        : isCancelled
        ? colorScheme.mutedForeground
        : Colors.orange.shade600;

    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      isTrial ? 'Free Trial' : member.name,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTrial
                          ? 'No payment required'
                          : isYearly
                              ? 'Billed yearly'
                              : 'Billed monthly',
                      style: theme.textTheme.small.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isTrial)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${member.price.toStringAsFixed(2)}',
                      style: theme.textTheme.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      isYearly ? '/year' : '/month',
                      style: theme.textTheme.small.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isTrial ? 'Trial active' : _statusLabel(member.status),
                style: theme.textTheme.small.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isTrial && member.endDate != null)
                Text(
                  'Ends ${_formatShortDate(member.endDate!)}',
                  style: theme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                )
              else if (member.autoRenew && isActive && _renewLabel(member) != null)
                Text(
                  _renewLabel(member)!,
                  style: theme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
            ],
          ),
          if (isActive && !member.autoRenew) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.circleAlert,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cancelNotice(member),
                      style: theme.textTheme.small.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showCancelButton &&
              isActive &&
              member.autoRenew &&
              onCancel != null) ...[
            const SizedBox(height: 16),
            ShadButton.outline(
              width: double.infinity,
              enabled: !isCancelling,
              onPressed: onCancel,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCancelling)
                    SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.destructive,
                      ),
                    )
                  else
                    Icon(
                      LucideIcons.circleX,
                      size: 16,
                      color: colorScheme.destructive,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isCancelling ? 'Cancelling...' : 'Cancel Subscription',
                    style: TextStyle(
                      color: colorScheme.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }

  static String? _renewLabel(MemberSubscriptionModel m) {
    final end = m.endDate;
    if (end == null) return 'Auto-renews';
    return 'Renews ${_formatShortDate(end)}';
  }

  static String _cancelNotice(MemberSubscriptionModel m) {
    final end = m.endDate;
    if (end == null) {
      return 'Your plan will end at the end of the current period.';
    }
    return 'Cancels on ${_formatShortDate(end)}';
  }

  static String _formatShortDate(DateTime d) {
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
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _statusLabel(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.trial:
        return 'Trial';
    }
  }
}
