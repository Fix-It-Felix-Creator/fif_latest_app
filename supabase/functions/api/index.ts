import { admin, json, verifyToken } from './lib/context.ts';
import {
  respondToShare,
  viewSharedInvoice,
  viewSharedQuote,
} from './routes/shares.ts';
import { deleteDocument, getShareLink } from './routes/documents.ts';
import {
  activateTrial,
  exportData,
  recoverAccount,
  requestDeletion,
} from './routes/account.ts';
import {
  appleNotifications,
  googleNotifications,
  validateApple,
  validateGoogle,
} from './routes/iap.ts';
import { sendNotification } from './routes/notifications.ts';
import { sharedAsset } from './routes/assets.ts';
import { authBridge } from './routes/auth_bridge.ts';
import { sendDocumentEmail } from './routes/email.ts';

/**
 * The app's backend API, ported from the Firebase Cloud Functions Express app
 * (functions/src/index.ts).
 *
 * Paths are preserved EXACTLY. `/q/:token` and `/i/:token` are already sitting
 * in customers' inboxes, and the app's ConfigService points at a configurable
 * base URL, so keeping the shapes identical means neither has to change.
 *
 * Routing is hand-rolled rather than pulled from a framework: there are ~17
 * routes with simple shapes, and a dependency-free router keeps the deployed
 * bundle small and the behaviour obvious.
 *
 * Auth mirrors the original middleware order:
 *   - public:     the share routes and the store webhooks (which carry their
 *                 own signed payloads)
 *   - everything else: requires a valid Supabase access token
 */

interface Route {
  method: string;
  // Path segments; ':name' captures.
  pattern: string[];
  public?: boolean;
  /**
   * Refuse unless `profiles.verification_status = 'verified'`.
   *
   * For anything a member of the public ends up seeing. Hiding the button in
   * the app is a courtesy to the user, not a control: this endpoint is
   * reachable with nothing but a valid access token and curl, so the check
   * that counts is the one here.
   */
  requiresVerification?: boolean;
  handler: (
    req: Request,
    params: Record<string, string>,
    caller?: { uid: string; email?: string },
  ) => Promise<Response>;
}

/**
 * Whether this account may be seen by a member of the public.
 *
 * Asks the database rather than deciding here, so the app, this function and
 * any future policy all get the same answer from the same place — two gates
 * that can disagree are worse than one.
 *
 * Fails CLOSED. A lookup that errors returns false, because the alternative is
 * an outage in the profiles table quietly turning verification off for
 * everybody.
 */
async function isVerified(uid: string): Promise<boolean> {
  try {
    const { data, error } = await admin().rpc('is_verified', {
      in_owner: uid,
    });
    if (error) {
      console.error('isVerified failed', error.message);
      return false;
    }
    return data === true;
  } catch (e) {
    console.error('isVerified threw', e);
    return false;
  }
}

const routes: Route[] = [
  // ---------------------------------------------------------------------
  // Public — token is the authorisation
  // ---------------------------------------------------------------------
  {
    method: 'GET',
    pattern: ['q', ':token'],
    public: true,
    handler: (req, p) => viewSharedQuote(req, p.token),
  },
  {
    method: 'POST',
    pattern: ['q', ':token', 'respond'],
    public: true,
    handler: (req, p) => respondToShare(req, p.token),
  },
  {
    method: 'GET',
    pattern: ['i', ':token'],
    public: true,
    handler: (req, p) => viewSharedInvoice(req, p.token),
  },
  {
    method: 'GET',
    pattern: ['q', ':token', ':mode', ':kind', ':id'],
    public: true,
    handler: (req, p) =>
      sharedAsset(req, p.token, p.mode, p.kind, p.id, 'quote'),
  },
  {
    method: 'GET',
    pattern: ['i', ':token', ':mode', ':kind', ':id'],
    public: true,
    handler: (req, p) =>
      sharedAsset(req, p.token, p.mode, p.kind, p.id, 'invoice'),
  },

  // ---------------------------------------------------------------------
  // Documents — authenticated, owner-scoped
  // ---------------------------------------------------------------------
  {
    method: 'POST',
    pattern: ['quotes', 'share-link'],
    requiresVerification: true,
    handler: (req, _p, caller) => getShareLink(req, caller!, 'quote'),
  },
  {
    method: 'POST',
    pattern: ['quotes', 'send-email'],
    requiresVerification: true,
    handler: (req, _p, caller) => sendDocumentEmail(req, caller!, 'quote'),
  },
  {
    method: 'POST',
    pattern: ['invoices', 'send-email'],
    requiresVerification: true,
    handler: (req, _p, caller) => sendDocumentEmail(req, caller!, 'invoice'),
  },
  {
    method: 'POST',
    pattern: ['quotes', 'delete'],
    handler: (req, _p, caller) => deleteDocument(req, caller!, 'quote'),
  },
  {
    method: 'POST',
    pattern: ['invoices', 'share-link'],
    requiresVerification: true,
    handler: (req, _p, caller) => getShareLink(req, caller!, 'invoice'),
  },
  {
    method: 'POST',
    pattern: ['invoices', 'delete'],
    handler: (req, _p, caller) => deleteDocument(req, caller!, 'invoice'),
  },

  // ---------------------------------------------------------------------
  // Account + subscription
  // ---------------------------------------------------------------------
  {
    method: 'POST',
    pattern: ['account', 'request-deletion'],
    handler: (req, _p, caller) => requestDeletion(req, caller!),
  },
  {
    method: 'POST',
    pattern: ['account', 'recover'],
    handler: (req, _p, caller) => recoverAccount(req, caller!),
  },
  {
    method: 'GET',
    pattern: ['account', 'export-data'],
    handler: (req, _p, caller) => exportData(req, caller!),
  },
  {
    method: 'POST',
    pattern: ['subscriptions', 'activate-trial'],
    handler: (req, _p, caller) => activateTrial(req, caller!),
  },

  // ---------------------------------------------------------------------
  // In-app purchases
  //
  // The webhooks are public because they carry only a store identifier and
  // the entitlement is re-derived from Apple's / Google's own API — there is
  // nothing to forge. They are declared BEFORE the authenticated validate
  // routes for the same reason the Express app mounted them before its auth
  // middleware.
  // ---------------------------------------------------------------------
  {
    method: 'POST',
    pattern: ['iap', 'apple', 'notifications'],
    public: true,
    handler: (req) => appleNotifications(req),
  },
  {
    method: 'POST',
    pattern: ['iap', 'google', 'notifications'],
    public: true,
    handler: (req) => googleNotifications(req),
  },
  {
    method: 'POST',
    pattern: ['iap', 'apple', 'validate'],
    handler: (req, _p, caller) => validateApple(req, caller!),
  },
  {
    method: 'POST',
    pattern: ['iap', 'google', 'validate'],
    handler: (req, _p, caller) => validateGoogle(req, caller!),
  },

  // ---------------------------------------------------------------------
  // Notifications (admin)
  // ---------------------------------------------------------------------
  {
    method: 'POST',
    pattern: ['notifications', 'send'],
    handler: (req, _p, caller) => sendNotification(req, caller!),
  },

  // ---------------------------------------------------------------------
  // Auth bridge — public by necessity: the caller has no session yet.
  // Rate-limited by IP and by email; see routes/auth_bridge.ts.
  // ---------------------------------------------------------------------
  {
    method: 'POST',
    pattern: ['auth', 'bridge'],
    public: true,
    handler: (req) => authBridge(req),
  },

  // ---------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------
  {
    method: 'GET',
    pattern: ['ping'],
    public: true,
    handler: () => Promise.resolve(json({ ok: true, ts: Date.now() })),
  },
];

/** Matches a path against a route pattern, extracting ':' captures. */
function match(
  pattern: string[],
  segments: string[],
): Record<string, string> | null {
  if (pattern.length !== segments.length) return null;
  const params: Record<string, string> = {};
  for (let i = 0; i < pattern.length; i++) {
    const p = pattern[i];
    if (p.startsWith(':')) {
      params[p.slice(1)] = decodeURIComponent(segments[i]);
    } else if (p !== segments[i]) {
      return null;
    }
  }
  return params;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  // Supabase routes to this function under `/functions/v1/api/…` from the
  // outside but hands the handler `/api/…`, and a custom domain may strip the
  // name entirely. Drop whichever prefix is present so the route patterns stay
  // identical to the Express originals rather than depending on how the
  // request arrived.
  const segments = url.pathname.split('/').filter((s) => s.length > 0);
  while (
    segments.length > 0 &&
    (segments[0] === 'functions' || segments[0] === 'v1' ||
      segments[0] === 'api')
  ) {
    segments.shift();
  }

  for (const route of routes) {
    if (route.method !== req.method) continue;
    const params = match(route.pattern, segments);
    if (!params) continue;

    if (route.public) {
      return route.handler(req, params);
    }

    const caller = await verifyToken(req);
    if (!caller) {
      return json({ message: 'Unauthorized: Invalid token' }, 401);
    }

    if (route.requiresVerification && !(await isVerified(caller.uid))) {
      // 403, not 401: the token is fine, the account simply is not allowed to
      // do this yet. A 401 would send the app off to re-authenticate and it
      // would come back to the same wall.
      return json(
        {
          message:
            'Your account needs to be verified before you can send this to a customer.',
          code: 'verification_required',
        },
        403,
      );
    }

    return route.handler(req, params, caller);
  }

  return json({ message: 'Not found' }, 404);
});
