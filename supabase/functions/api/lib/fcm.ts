/**
 * Firebase Cloud Messaging HTTP v1 client.
 *
 * `firebase-admin` is a Node SDK and does not run on Deno, so the parts this
 * app actually used — mint an access token, send a message, recognise a dead
 * token — are implemented directly against the REST API.
 *
 * Needs one secret: FIREBASE_SERVICE_ACCOUNT, the service-account JSON for the
 * Firebase project that owns the FCM sender. Set it with
 *   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
 */

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let _sa: ServiceAccount | null = null;
let _token: { value: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount | null {
  if (_sa) return _sa;
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!raw) return null;
  try {
    _sa = JSON.parse(raw) as ServiceAccount;
    return _sa;
  } catch {
    console.error('FCM: FIREBASE_SERVICE_ACCOUNT is not valid JSON');
    return null;
  }
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function b64urlStr(s: string): string {
  return b64url(new TextEncoder().encode(s));
}

/** PEM (PKCS#8) -> CryptoKey for RS256 signing. */
async function importKey(pem: string): Promise<CryptoKey> {
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

/**
 * OAuth access token for the FCM scope, cached until shortly before expiry.
 *
 * Re-minting on every push would add a round trip to Google per notification;
 * the 60s safety margin avoids using a token that expires mid-flight.
 */
async function accessToken(): Promise<string | null> {
  const sa = serviceAccount();
  if (!sa) return null;

  const now = Math.floor(Date.now() / 1000);
  if (_token && _token.expiresAt > now + 60) return _token.value;

  const header = b64urlStr(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64urlStr(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  try {
    // The JSON escapes newlines in the PEM; restore them before parsing.
    const key = await importKey(sa.private_key.replace(/\\n/g, '\n'));
    const sig = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(`${header}.${claim}`),
    );
    const jwt = `${header}.${claim}.${b64url(new Uint8Array(sig))}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!res.ok) {
      console.error('FCM: token exchange failed', res.status, await res.text());
      return null;
    }

    const body = await res.json() as { access_token: string; expires_in: number };
    _token = { value: body.access_token, expiresAt: now + body.expires_in };
    return _token.value;
  } catch (e) {
    console.error('FCM: token mint failed', String(e));
    return null;
  }
}

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Sends to one token. Returns 'ok', 'dead' (token should be pruned) or
 * 'error' (transient — leave the token alone).
 *
 * Distinguishing dead from transient matters: treating a network blip as a
 * dead token would silently unregister a working device.
 */
export async function sendToToken(
  token: string,
  msg: PushMessage,
): Promise<'ok' | 'dead' | 'error'> {
  const sa = serviceAccount();
  const auth = await accessToken();
  if (!sa || !auth) return 'error';

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data ?? {},
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'default' },
          },
          apns: {
            payload: {
              aps: { sound: 'default', badge: 1, 'mutable-content': 1 },
            },
          },
        },
      }),
    },
  );

  if (res.ok) return 'ok';

  const text = await res.text();

  // UNREGISTERED / INVALID_ARGUMENT on the token field are the v1 equivalents
  // of the old messaging/registration-token-not-registered family.
  if (
    res.status === 404 ||
    text.includes('UNREGISTERED') ||
    text.includes('INVALID_ARGUMENT')
  ) {
    return 'dead';
  }

  console.warn('FCM: send failed', res.status, text.slice(0, 200));
  return 'error';
}

/** True when FCM is configured. Lets callers degrade instead of throwing. */
export function fcmConfigured(): boolean {
  return serviceAccount() !== null;
}
