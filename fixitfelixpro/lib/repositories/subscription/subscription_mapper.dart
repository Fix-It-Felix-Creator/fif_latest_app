/// Translates a `subscriptions` row (snake_case) into the camelCase JSON
/// `MemberSubscriptionModel.fromJson` already speaks.
///
/// Same approach as ProfileMapper/UsageMapper: adapt at the boundary so the
/// model and every screen reading it stay untouched.
///
/// RTDB nested the member subscription under `/users/{uid}/subscription/member`,
/// so it arrived as part of the user document. Postgres keeps it in its own
/// `subscriptions` table (one row per owner, `owner_id` PK), which means every
/// caller that used to get it for free from the user record now has to fetch
/// it. Both readers — the realtime listener and `getUserDetails()` — go
/// through here so the two can't drift apart.
class SubscriptionMapper {
  const SubscriptionMapper._();

  /// Table name, so callers don't repeat the string literal.
  static const String table = 'subscriptions';

  /// Primary key — `subscriptions` is one row per owner, so `owner_id` is the
  /// PK rather than a synthetic id. Realtime streams need it named explicitly.
  static const String primaryKey = 'owner_id';

  /// `subscriptions` row -> the JSON `MemberSubscriptionModel` expects.
  ///
  /// Columns with no model counterpart (`owner_id`, `google_purchase_token_hash`,
  /// `created_at`, `updated_at`) are dropped; model fields with no column
  /// (`subscriptionId`, `accountType`, `stripePriceId`) are simply absent and
  /// `fromJson` falls back to its defaults — it tolerates every one of them.
  static Map<String, dynamic> rowToMemberJson(Map<String, dynamic> row) => {
        'status': row['status'],
        'planType': row['plan_type'],
        'billingCycle': row['billing_cycle'],
        'provider': row['provider'],
        'name': row['name'],
        'price': row['price'],
        'productId': row['product_id'],
        'originalTransactionId': row['original_transaction_id'],
        'stripeSubscriptionId': row['stripe_subscription_id'],
        'stripeCustomerId': row['stripe_customer_id'],
        'autoRenew': row['auto_renew'] ?? true,
        'cancelAtPeriodEnd': row['cancel_at_period_end'] ?? false,
        'startDate': row['current_period_start'],
        'endDate': row['current_period_end'],
        'metadata': row['metadata'],
      };

  /// `subscriptions` row -> the `subscription` value on the user document,
  /// shaped the way `UserSubscriptionContainerModel.fromJson` expects.
  ///
  /// `tool` stays null: nothing in the app reads a tool subscription and the
  /// schema has no place to store one. If tool subscriptions are ever used
  /// they need their own table, not a second column here.
  ///
  /// Returns null for a missing row so callers can assign it straight onto
  /// the user JSON — a null `subscription` is what "no plan" looks like.
  static Map<String, dynamic>? rowToContainerJson(Map<String, dynamic>? row) {
    if (row == null) return null;
    return {'member': rowToMemberJson(row), 'tool': null};
  }
}
