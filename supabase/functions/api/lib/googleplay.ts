/**
 * Google Play Developer API client (subscriptionsv2).
 *
 * Ported from functions/src/lib/googleplay.ts. Only the RS256 signing changed
 * — `jsonwebtoken` is Node-only, so the OAuth assertion is signed with Web
 * Crypto. Endpoints, state mapping and normalisation are unchanged.
 *
 * Secrets:
 *   GOOGLE_PLAY_SA_JSON   full service-account JSON
 *   ANDROID_PACKAGE_NAME  com.techkushx.fixitfelixpro
 */

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

let tokenCache: { token: string; expMs: number } | null = null;

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing secret ${name}`);
  return v;
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const enc = (s: string) => b64url(new TextEncoder().encode(s));

async function importRs256(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/** Mint (and cache) an androidpublisher access token. */
async function accessToken(): Promise<string> {
  if (tokenCache && tokenCache.expMs > Date.now() + 60_000) {
    return tokenCache.token;
  }

  const sa = JSON.parse(env('GOOGLE_PLAY_SA_JSON')) as ServiceAccount;
  const tokenUri = sa.token_uri ?? 'https://oauth2.googleapis.com/token';
  const now = Math.floor(Date.now() / 1000);

  const header = enc(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = enc(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));

  const key = await importRs256(sa.private_key.replace(/\\n/g, '\n'));
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  );
  const assertion = `${header}.${claim}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`google_oauth_${res.status}: ${await res.text()}`);
  }

  const json = await res.json() as {
    access_token: string;
    expires_in: number;
  };
  tokenCache = {
    token: json.access_token,
    expMs: Date.now() + json.expires_in * 1000,
  };
  return json.access_token;
}

/** Normalized Play subscription state (provider-agnostic shape). */
export interface GooglePurchase {
  productId: string;
  purchaseToken: string;
  startMs: number;
  expiresMs: number | null;
  autoRenew: boolean;
  active: boolean;
  obfuscatedAccountId?: string;
}

interface LineItemV2 {
  productId?: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
}

interface SubscriptionPurchaseV2 {
  subscriptionState?: string;
  startTime?: string;
  lineItems?: LineItemV2[];
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
}

function rfc3339ToMs(s?: string): number | null {
  if (!s) return null;
  const ms = Date.parse(s);
  return Number.isFinite(ms) ? ms : null;
}

const ACTIVE_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

function normalize(
  purchaseToken: string,
  d: SubscriptionPurchaseV2,
): GooglePurchase {
  const li = d.lineItems?.[0] ?? {};
  const expiresMs = rfc3339ToMs(li.expiryTime);
  const startMs = rfc3339ToMs(d.startTime) ?? Date.now();
  const state = d.subscriptionState ?? '';
  const autoRenew = li.autoRenewingPlan?.autoRenewEnabled ?? false;
  // A cancelled-but-not-yet-expired sub still entitles the user until the
  // period ends (matches the Apple soft-cancel behaviour).
  const active = ACTIVE_STATES.has(state) ||
    (state === 'SUBSCRIPTION_STATE_CANCELED' &&
      expiresMs != null && expiresMs > Date.now());

  return {
    productId: li.productId ?? '',
    purchaseToken,
    startMs,
    expiresMs,
    autoRenew,
    active,
    obfuscatedAccountId:
      d.externalAccountIdentifiers?.obfuscatedExternalAccountId,
  };
}

interface ApiError extends Error {
  status?: number;
  body?: string;
}

/**
 * GET subscriptionsv2 for a purchase token. Throws ApiError (with `status`)
 * on non-2xx so callers can distinguish 404s.
 */
export async function getSubscription(
  purchaseToken: string,
): Promise<GooglePurchase> {
  const pkg = env('ANDROID_PACKAGE_NAME');
  const url = 'https://androidpublisher.googleapis.com/androidpublisher/v3' +
    `/applications/${pkg}/purchases/subscriptionsv2/tokens/` +
    encodeURIComponent(purchaseToken);

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${await accessToken()}` },
  });

  if (!res.ok) {
    const err: ApiError = new Error(`androidpublisher_${res.status}`);
    err.status = res.status;
    try { err.body = await res.text(); } catch { /* ignore */ }
    console.warn('Play API error', res.status, err.body?.slice(0, 200));
    throw err;
  }

  return normalize(purchaseToken, await res.json() as SubscriptionPurchaseV2);
}
