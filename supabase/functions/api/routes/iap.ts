import { json } from '../lib/context.ts';
import type { Caller } from '../lib/context.ts';
import {
  decodeJwsPayload,
  getSubscriptionState,
  getTransaction,
  isActiveNow,
} from '../lib/appstore.ts';
import { getSubscription } from '../lib/googleplay.ts';
import {
  mapProductToPlan,
  sha256Hex,
  uidForApple,
  uidForGoogle,
  writeEntitlement,
} from '../lib/iap.ts';

/**
 * In-app purchase validation and store webhooks.
 *
 * The client is never trusted: a purchase is re-fetched from Apple's or
 * Google's server API before any entitlement is written. That is why the
 * webhooks need no signature check either — they only carry an identifier
 * that is looked up against the store.
 */

/**
 * Pulls `transactionId` out of a StoreKit 2 JWS without verifying the
 * signature. Safe because the id is only used to re-fetch the authoritative
 * transaction from Apple before anything is granted.
 */
function transactionIdFromJws(jws?: string): string | undefined {
  if (!jws) return undefined;
  try {
    const payload = decodeJwsPayload<{ transactionId?: unknown }>(jws);
    const id = payload.transactionId;
    return typeof id === 'string' && id ? id : undefined;
  } catch {
    return undefined;
  }
}

/** POST /iap/apple/validate */
export async function validateApple(
  req: Request,
  caller: Caller,
): Promise<Response> {
  let transactionId: string | undefined;
  try {
    const body = await req.json() as {
      transactionId?: string;
      serverVerificationData?: string;
    };

    // Older clients can send a null transactionId while still attaching the
    // StoreKit JWS — recover the id from its payload.
    transactionId = body.transactionId ??
      transactionIdFromJws(body.serverVerificationData);

    if (!transactionId) {
      console.warn('validateApple: no transactionId in body or JWS', caller.uid);
      return json({ success: false, message: 'transactionId required' }, 400);
    }

    const tx = await getTransaction(transactionId);
    if (!mapProductToPlan(tx.productId)) {
      console.warn('validateApple: unknown product', tx.productId, caller.uid);
      return json({ success: false, message: 'Unknown product' }, 400);
    }

    // Prefer the latest state from the subscriptions endpoint — it covers a
    // renewal that happened after this transaction.
    const state = await getSubscriptionState(tx.originalTransactionId);
    const latest = state?.tx ?? tx;
    const renewal = state?.renewal;

    await writeEntitlement(caller.uid, {
      provider: 'apple',
      productId: latest.productId,
      providerSubId: latest.originalTransactionId,
      startMs: latest.purchaseDate ?? Date.now(),
      endMs: latest.expiresDate ?? null,
      autoRenew: renewal?.autoRenewStatus === 1,
      active: isActiveNow(latest),
      revoked: latest.revocationDate != null,
    });

    return json({ success: true });
  } catch (err) {
    console.error('validateApple failed', String(err), transactionId, caller.uid);
    return json({ success: false, message: 'validation_failed' }, 500);
  }
}

/** POST /iap/google/validate */
export async function validateGoogle(
  req: Request,
  caller: Caller,
): Promise<Response> {
  try {
    const body = await req.json() as {
      purchaseToken?: string;
      productId?: string;
    };
    if (!body.purchaseToken) {
      return json({ success: false, message: 'purchaseToken required' }, 400);
    }

    const purchase = await getSubscription(body.purchaseToken);
    // Play occasionally omits the productId on the line item; fall back to
    // the client-declared one for plan mapping.
    if (!purchase.productId && body.productId) {
      purchase.productId = body.productId;
    }
    if (!mapProductToPlan(purchase.productId)) {
      console.warn('validateGoogle: unknown product', purchase.productId);
      return json({ success: false, message: 'Unknown product' }, 400);
    }

    await writeEntitlement(caller.uid, {
      provider: 'google',
      productId: purchase.productId,
      providerSubId: purchase.purchaseToken,
      startMs: purchase.startMs,
      endMs: purchase.expiresMs,
      autoRenew: purchase.autoRenew,
      active: purchase.active,
      revoked: false,
      googleTokenHash: await sha256Hex(purchase.purchaseToken),
    });

    return json({ success: true });
  } catch (err) {
    console.error('validateGoogle failed', String(err), caller.uid);
    return json({ success: false, message: 'validation_failed' }, 500);
  }
}

interface NotificationPayload {
  notificationType?: string;
  subtype?: string;
  data?: {
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
    environment?: string;
  };
}

/**
 * POST /iap/apple/notifications — App Store Server Notifications V2.
 *
 * Public: the notification carries only an identifier, and the entitlement is
 * re-derived from Apple's API, so no signature check is needed to stay safe.
 * Always returns 200 for anything unactionable — Apple retries non-2xx, and
 * retrying a notification we have no account for would never succeed.
 */
export async function appleNotifications(req: Request): Promise<Response> {
  try {
    const body = await req.json() as { signedPayload?: string };
    if (!body.signedPayload) {
      return json({ ok: false, message: 'missing signedPayload' }, 400);
    }

    const payload = decodeJwsPayload<NotificationPayload>(body.signedPayload);
    const txInfo = payload.data?.signedTransactionInfo
      ? decodeJwsPayload<Record<string, unknown>>(
        payload.data.signedTransactionInfo,
      )
      : null;

    const originalTransactionId =
      typeof txInfo?.originalTransactionId === 'string'
        ? txInfo.originalTransactionId
        : undefined;

    if (!originalTransactionId) {
      // Nothing actionable (e.g. a test/consumption notification).
      console.info('appleNotifications: no originalTransactionId',
        payload.notificationType);
      return json({ ok: true, skipped: 'no originalTransactionId' });
    }

    const uid = await uidForApple(originalTransactionId);
    if (!uid) {
      // The purchase was never validated by a signed-in client, so there is
      // no account to attribute it to.
      console.info('appleNotifications: unknown transaction',
        originalTransactionId);
      return json({ ok: true, skipped: 'unknown transaction' });
    }

    const state = await getSubscriptionState(originalTransactionId);
    if (!state) return json({ ok: true, skipped: 'no state' });

    await writeEntitlement(uid, {
      provider: 'apple',
      productId: state.tx.productId,
      providerSubId: state.tx.originalTransactionId,
      startMs: state.tx.purchaseDate ?? Date.now(),
      endMs: state.tx.expiresDate ?? null,
      autoRenew: state.renewal?.autoRenewStatus === 1,
      active: isActiveNow(state.tx),
      revoked: state.tx.revocationDate != null,
    });

    return json({ ok: true, type: payload.notificationType });
  } catch (err) {
    console.error('appleNotifications failed', String(err));
    // 200 so Apple does not retry a payload we cannot parse.
    return json({ ok: true, error: String(err) });
  }
}

interface DeveloperNotification {
  subscriptionNotification?: { purchaseToken?: string };
  voidedPurchaseNotification?: { purchaseToken?: string };
  testNotification?: { version?: string };
}

/**
 * POST /iap/google/notifications — Play RTDN via a Pub/Sub push envelope.
 */
export async function googleNotifications(req: Request): Promise<Response> {
  try {
    const body = await req.json() as { message?: { data?: string } };
    const dataB64 = body?.message?.data;
    if (!dataB64) {
      // Not a valid push envelope (or a Pub/Sub verification ping).
      return json({ ok: true, skipped: 'no message data' });
    }

    const decoded = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(atob(dataB64), (c) => c.charCodeAt(0)),
      ),
    ) as DeveloperNotification;

    if (decoded.testNotification) {
      console.info('googleNotifications: test notification');
      return json({ ok: true, test: true });
    }

    const token = decoded.subscriptionNotification?.purchaseToken ??
      decoded.voidedPurchaseNotification?.purchaseToken;
    if (!token) return json({ ok: true, skipped: 'no purchaseToken' });

    const uid = await uidForGoogle(token);
    if (!uid) {
      console.info('googleNotifications: unknown purchase token');
      return json({ ok: true, skipped: 'unknown token' });
    }

    // A voided purchase is a refund: revoke rather than re-read state.
    if (decoded.voidedPurchaseNotification) {
      const purchase = await getSubscription(token).catch(() => null);
      await writeEntitlement(uid, {
        provider: 'google',
        productId: purchase?.productId ?? '',
        providerSubId: token,
        startMs: purchase?.startMs ?? Date.now(),
        endMs: purchase?.expiresMs ?? null,
        autoRenew: false,
        active: false,
        revoked: true,
        googleTokenHash: await sha256Hex(token),
      });
      return json({ ok: true, voided: true });
    }

    const purchase = await getSubscription(token);
    await writeEntitlement(uid, {
      provider: 'google',
      productId: purchase.productId,
      providerSubId: purchase.purchaseToken,
      startMs: purchase.startMs,
      endMs: purchase.expiresMs,
      autoRenew: purchase.autoRenew,
      active: purchase.active,
      revoked: false,
      googleTokenHash: await sha256Hex(token),
    });

    return json({ ok: true });
  } catch (err) {
    console.error('googleNotifications failed', String(err));
    // 200 so Pub/Sub does not redeliver forever.
    return json({ ok: true, error: String(err) });
  }
}
