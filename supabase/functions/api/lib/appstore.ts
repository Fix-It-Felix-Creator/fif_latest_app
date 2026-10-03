/**
 * App Store Server API client.
 *
 * Ported from functions/src/lib/appstore.ts. The only substantive change is
 * ES256 JWT signing: `jsonwebtoken` is a Node library, so the bearer token is
 * signed with Web Crypto instead. Everything else — the endpoints, the
 * environment fallback, the field normalisation — is unchanged.
 *
 * Secrets (set with `supabase secrets set`):
 *   APPSTORE_KEY_ID       the in-app-purchase key's Key ID
 *   APPSTORE_ISSUER_ID    Issuer ID from Users & Access -> Integrations
 *   APPSTORE_BUNDLE_ID    com.techkushx.fixitfelixpro
 *   APPSTORE_PRIVATE_KEY  the .p8 contents
 */

export type AppStoreEnv = 'Production' | 'Sandbox';

const HOST: Record<AppStoreEnv, string> = {
  Production: 'https://api.storekit.itunes.apple.com',
  Sandbox: 'https://api.storekit-sandbox.itunes.apple.com',
};

/** Decoded JWSTransaction fields we care about (Apple sends more). */
export interface AppleTransaction {
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  /** Subscription expiry, epoch ms. */
  expiresDate?: number;
  /** Purchase time, epoch ms. */
  purchaseDate?: number;
  type?: string;
  environment?: string;
  /** Set when refunded / revoked, epoch ms. */
  revocationDate?: number;
}

/** Decoded JWSRenewalInfo fields we care about. */
export interface AppleRenewal {
  /** 1 = will auto-renew, 0 = turned off. */
  autoRenewStatus?: number;
  expirationIntent?: number;
  gracePeriodExpiresDate?: number;
}

interface ApiError extends Error {
  status?: number;
  body?: string;
}

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing secret ${name}`);
  return v;
}

/** The environment the current build talks to first. */
function currentAppStoreEnv(): AppStoreEnv {
  return Deno.env.get('APPSTORE_ENV') === 'Sandbox' ? 'Sandbox' : 'Production';
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const enc = (s: string) => b64url(new TextEncoder().encode(s));

/** Base64url-decode the payload segment of a JWS without verification. */
export function decodeJwsPayload<T>(jws: string): T {
  const seg = jws.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
  const pad = seg + '='.repeat((4 - seg.length % 4) % 4);
  return JSON.parse(
    new TextDecoder().decode(
      Uint8Array.from(atob(pad), (c) => c.charCodeAt(0)),
    ),
  ) as T;
}

async function importEs256(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
}

/** Short-lived ES256 bearer token for the App Store Server API. */
async function bearerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = enc(JSON.stringify({
    alg: 'ES256',
    kid: env('APPSTORE_KEY_ID'),
    typ: 'JWT',
  }));
  const claim = enc(JSON.stringify({
    iss: env('APPSTORE_ISSUER_ID'),
    iat: now,
    exp: now + 60 * 20, // 20 min (Apple max is 60)
    aud: 'appstoreconnect-v1',
    bid: env('APPSTORE_BUNDLE_ID'),
  }));

  const key = await importEs256(env('APPSTORE_PRIVATE_KEY').replace(/\\n/g, '\n'));
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  );
  return `${header}.${claim}.${b64url(new Uint8Array(sig))}`;
}

async function apiGet(path: string, e: AppStoreEnv): Promise<unknown> {
  const res = await fetch(`${HOST[e]}${path}`, {
    headers: { Authorization: `Bearer ${await bearerToken()}` },
  });
  if (!res.ok) {
    const err: ApiError = new Error(`appstore_api_${res.status}`);
    err.status = res.status;
    try { err.body = await res.text(); } catch { /* ignore */ }
    throw err;
  }
  return res.json();
}

/**
 * Try the active environment first; on 404 or 401 retry the other once.
 * 404 is the classic "sandbox transaction queried against production" miss;
 * 401 is what Production returns for a bundle with no production presence yet
 * (pre-launch apps + TestFlight builds) — also the right cue to fall back.
 */
async function withEnvFallback<T>(
  fn: (e: AppStoreEnv) => Promise<T>,
): Promise<T> {
  const primary = currentAppStoreEnv();
  const secondary: AppStoreEnv = primary === 'Production'
    ? 'Sandbox'
    : 'Production';
  try {
    return await fn(primary);
  } catch (err) {
    const status = (err as ApiError)?.status;
    if (status === 404 || status === 401) {
      console.info(`App Store API ${status} — retrying ${secondary}`);
      return await fn(secondary);
    }
    throw err;
  }
}

function normalizeTransaction(raw: Record<string, unknown>): AppleTransaction {
  return {
    productId: String(raw.productId ?? ''),
    originalTransactionId: String(raw.originalTransactionId ?? ''),
    transactionId: String(raw.transactionId ?? ''),
    expiresDate: typeof raw.expiresDate === 'number' ? raw.expiresDate : undefined,
    purchaseDate: typeof raw.purchaseDate === 'number' ? raw.purchaseDate : undefined,
    type: typeof raw.type === 'string' ? raw.type : undefined,
    environment: typeof raw.environment === 'string' ? raw.environment : undefined,
    revocationDate: typeof raw.revocationDate === 'number' ? raw.revocationDate : undefined,
  };
}

function normalizeRenewal(raw: Record<string, unknown>): AppleRenewal {
  return {
    autoRenewStatus: typeof raw.autoRenewStatus === 'number' ? raw.autoRenewStatus : undefined,
    expirationIntent: typeof raw.expirationIntent === 'number' ? raw.expirationIntent : undefined,
    gracePeriodExpiresDate: typeof raw.gracePeriodExpiresDate === 'number'
      ? raw.gracePeriodExpiresDate
      : undefined,
  };
}

/** GET /inApps/v1/transactions/{transactionId} */
export function getTransaction(
  transactionId: string,
): Promise<AppleTransaction> {
  return withEnvFallback(async (e) => {
    const data = await apiGet(
      `/inApps/v1/transactions/${transactionId}`,
      e,
    ) as { signedTransactionInfo: string };
    return normalizeTransaction(
      decodeJwsPayload<Record<string, unknown>>(data.signedTransactionInfo),
    );
  });
}

interface SubStatusResponse {
  data?: Array<{
    lastTransactions?: Array<{
      signedTransactionInfo?: string;
      signedRenewalInfo?: string;
    }>;
  }>;
}

/**
 * GET /inApps/v1/subscriptions/{originalTransactionId}
 *
 * Returns the most recent transaction (highest expiry) plus its renewal info —
 * the authoritative current state. Null when Apple has no record.
 */
export function getSubscriptionState(
  originalTransactionId: string,
): Promise<{ tx: AppleTransaction; renewal: AppleRenewal } | null> {
  return withEnvFallback(async (e) => {
    const data = await apiGet(
      `/inApps/v1/subscriptions/${originalTransactionId}`,
      e,
    ) as SubStatusResponse;

    let best: { tx: AppleTransaction; renewal: AppleRenewal } | null = null;
    for (const group of data.data ?? []) {
      for (const lt of group.lastTransactions ?? []) {
        if (!lt.signedTransactionInfo) continue;
        const tx = normalizeTransaction(
          decodeJwsPayload<Record<string, unknown>>(lt.signedTransactionInfo),
        );
        const renewal = lt.signedRenewalInfo
          ? normalizeRenewal(
            decodeJwsPayload<Record<string, unknown>>(lt.signedRenewalInfo),
          )
          : {};
        if (!best || (tx.expiresDate ?? 0) > (best.tx.expiresDate ?? 0)) {
          best = { tx, renewal };
        }
      }
    }
    return best;
  });
}

/** True when an Apple transaction currently entitles the user. */
export function isActiveNow(tx: AppleTransaction): boolean {
  if (tx.revocationDate) return false; // refunded / revoked
  if (!tx.expiresDate) return true;
  return tx.expiresDate > Date.now();
}
