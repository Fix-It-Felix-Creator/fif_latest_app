import { admin } from './context.ts';

/**
 * In-app purchase entitlement.
 *
 * Ported from functions/src/lib/iapEntitlement.ts. The product catalogue and
 * the resulting subscription shape are unchanged; only the destination moved
 * from `users/{uid}/subscription/member` to the `subscriptions` table.
 */

export interface PlanMapping {
  planType: string;
  accountType: string;
  billingCycle: string;
  name: string;
  price: number;
}

/**
 * Product id -> plan. Kept verbatim: these ids are configured in App Store
 * Connect and Play Console, so they are an external contract.
 */
const PRODUCT_PLANS: Record<string, PlanMapping> = {
  'fixitfelixpro.standard.monthly': {
    planType: 'standard',
    accountType: 'tradesman',
    billingCycle: 'monthly',
    name: 'Standard',
    price: 12.99,
  },
  'fixitfelixpro.standard.yearly': {
    planType: 'standard',
    accountType: 'tradesman',
    billingCycle: 'yearly',
    name: 'Standard',
    price: 129.99,
  },
};

export function mapProductToPlan(productId: string): PlanMapping | null {
  return PRODUCT_PLANS[productId] ?? null;
}

export interface EntitlementInput {
  provider: 'apple' | 'google';
  productId: string;
  /** Stable subscription id (Apple originalTransactionId / Play token). */
  providerSubId: string;
  startMs: number;
  endMs: number | null;
  autoRenew: boolean;
  active: boolean;
  revoked: boolean;
  /** sha256 of the Play purchase token, for webhook attribution. */
  googleTokenHash?: string;
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Persists the entitlement in the shape the Flutter model and auth gate
 * expect. `providerSubId` lands in `original_transaction_id`, which the app's
 * `isPaid` keys off for both stores.
 *
 * Upsert on `owner_id`: a user has exactly one member subscription, and a
 * renewal must update it rather than accumulate rows.
 */
export async function writeEntitlement(
  uid: string,
  input: EntitlementInput,
): Promise<void> {
  const plan = mapProductToPlan(input.productId);
  const status = input.revoked
    ? 'cancelled'
    : input.active
    ? 'active'
    : 'expired';

  const { data: current } = await admin()
    .from('subscriptions')
    .select('plan_type, billing_cycle, name, price')
    .eq('owner_id', uid)
    .maybeSingle();

  await admin().from('subscriptions').upsert({
    owner_id: uid,
    provider: input.provider,
    product_id: input.productId,
    original_transaction_id: input.providerSubId,
    status,
    auto_renew: input.autoRenew,
    cancel_at_period_end: input.active && !input.autoRenew,
    current_period_start: new Date(input.startMs).toISOString(),
    current_period_end: input.endMs != null
      ? new Date(input.endMs).toISOString()
      : null,
    // Fall back to whatever is already stored so a webhook for an unknown
    // product cannot blank a user's plan.
    plan_type: plan?.planType ?? current?.plan_type ?? 'standard',
    billing_cycle: plan?.billingCycle ?? current?.billing_cycle ?? 'monthly',
    name: plan?.name ?? current?.name ?? null,
    price: plan?.price ?? current?.price ?? null,
    ...(input.googleTokenHash
      ? { google_purchase_token_hash: input.googleTokenHash }
      : {}),
  }, { onConflict: 'owner_id' });
}

/**
 * Finds the account a store identifier belongs to.
 *
 * Store webhooks are unauthenticated, so this is the only way to attribute
 * one. Returns null when the purchase was never validated by a signed-in
 * client, in which case there is nothing to update.
 */
export async function uidForApple(
  originalTransactionId: string,
): Promise<string | null> {
  const { data } = await admin()
    .from('subscriptions')
    .select('owner_id')
    .eq('original_transaction_id', originalTransactionId)
    .maybeSingle();
  return (data?.owner_id as string) ?? null;
}

export async function uidForGoogle(
  purchaseToken: string,
): Promise<string | null> {
  const hash = await sha256Hex(purchaseToken);
  const { data } = await admin()
    .from('subscriptions')
    .select('owner_id')
    .eq('google_purchase_token_hash', hash)
    .maybeSingle();
  return (data?.owner_id as string) ?? null;
}
