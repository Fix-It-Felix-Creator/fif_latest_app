import 'package:flutter_test/flutter_test.dart';
import 'package:fixitfelix/core/enum.dart';
import 'package:fixitfelix/models/user_subscription_container_model.dart';
import 'package:fixitfelix/repositories/subscription/subscription_mapper.dart';

/// A free-trial row exactly as `/subscriptions/activate-trial` writes it:
/// no provider, no transaction id, price 0, status 'active', 30-day window.
Map<String, dynamic> trialRow({DateTime? end}) => {
      'owner_id': 'bf637428-211d-4451-b4d3-dad124ae25f0',
      'status': 'active',
      'plan_type': 'standard',
      'billing_cycle': 'monthly',
      'provider': null,
      'name': 'Standard',
      'price': 0.00,
      'product_id': null,
      'original_transaction_id': null,
      'stripe_subscription_id': null,
      'stripe_customer_id': null,
      'auto_renew': true,
      'cancel_at_period_end': false,
      'current_period_start': '2026-08-23T22:51:35.088+00:00',
      'current_period_end':
          (end ?? DateTime.now().add(const Duration(days: 30)))
              .toIso8601String(),
      'metadata': null,
      'google_purchase_token_hash': null,
    };

void main() {
  group('SubscriptionMapper', () {
    test('a free-trial row grants access and reads as a trial', () {
      final container = UserSubscriptionContainerModel.fromJson(
        SubscriptionMapper.rowToContainerJson(trialRow())!,
      );

      final member = container.member;
      expect(member, isNotNull, reason: 'trial row must produce a member');

      // The auth gate (`_needsSubscription`) turns users away unless the
      // member is active/trial and unexpired. This is the assertion that
      // would have caught the trial being invisible to the gate.
      expect(member!.status, SubscriptionStatus.active);
      expect(member.grantsAccess, isTrue);

      // CurrentPlanCard shows "Free Trial" off `!isPaid` — a trial carries
      // no transaction id, unlike a paid IAP/Stripe sub.
      expect(member.isPaid, isFalse);

      expect(member.planType, PlanType.standard);
      expect(member.billingCycle, BillingCycle.monthly);
      expect(member.price, 0);
      expect(member.endDate, isNotNull);
    });

    test('an expired row does not grant access', () {
      final container = UserSubscriptionContainerModel.fromJson(
        SubscriptionMapper.rowToContainerJson(
          trialRow(end: DateTime.now().subtract(const Duration(days: 1))),
        )!,
      );

      expect(container.member!.grantsAccess, isFalse);
    });

    test('a paid IAP row is not mistaken for a trial', () {
      final row = trialRow()
        ..['provider'] = 'apple'
        ..['original_transaction_id'] = '1000000123456789'
        ..['price'] = 14.99;

      final member = UserSubscriptionContainerModel.fromJson(
        SubscriptionMapper.rowToContainerJson(row)!,
      ).member!;

      expect(member.isPaid, isTrue);
      expect(member.grantsAccess, isTrue);
      expect(member.price, 14.99);
    });

    test('no row means no plan, not an empty plan', () {
      // `getUserDetails` assigns this straight onto the user JSON, so a
      // missing subscription has to come back null rather than a container
      // holding a null member.
      expect(SubscriptionMapper.rowToContainerJson(null), isNull);
    });

    test('tool subscription stays null — no column backs it', () {
      final container = UserSubscriptionContainerModel.fromJson(
        SubscriptionMapper.rowToContainerJson(trialRow())!,
      );
      expect(container.tool, isNull);
    });
  });
}
