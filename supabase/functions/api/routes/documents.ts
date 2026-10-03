import { admin, json } from '../lib/context.ts';
import type { Caller } from '../lib/context.ts';

/**
 * Authenticated quote/invoice routes: share-link minting and deletion.
 *
 * Both are owner-scoped: the service-role client bypasses RLS, so every query
 * here filters on `owner_id` explicitly. That is the whole safety boundary —
 * dropping one of those filters would let any signed-in user act on anyone's
 * document.
 */

/** Base for public share URLs. */
function publicBaseUrl(): string {
  // Configurable so the URL can move to a custom domain without a code change.
  // Falls back to this project's own function URL.
  const explicit = Deno.env.get('PUBLIC_SHARE_BASE_URL');
  if (explicit) return explicit.replace(/\/+$/, '');
  return `${Deno.env.get('SUPABASE_URL')}/functions/v1/api`;
}

/** URL-safe token, same shape and entropy as the Node `randomBytes(16).base64url`. */
function mintToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Guard for paid value-add endpoints (send email, mint share link).
 *
 * "Active" means a subscription row exists, its status is active or trial,
 * and either there is no end date or it is still in the future. Kept separate
 * from authentication: that answers who you are, this answers whether you've
 * paid.
 */
async function requireActiveSubscription(uid: string): Promise<Response | null> {
  const { data } = await admin()
    .from('subscriptions')
    .select('status, current_period_end')
    .eq('owner_id', uid)
    .maybeSingle();

  const fail = (message: string) =>
    json({ success: false, code: 'subscription_required', message }, 402);

  if (!data) return fail('An active subscription is required.');

  const status = String(data.status ?? '');
  if (status !== 'active' && status !== 'trial') {
    return fail('An active subscription is required.');
  }

  const end = data.current_period_end
    ? new Date(String(data.current_period_end)).getTime()
    : null;
  if (end !== null && end < Date.now()) {
    return fail('Your subscription has expired.');
  }

  return null;
}

type Kind = 'quote' | 'invoice';

const TABLE: Record<Kind, string> = { quote: 'quotes', invoice: 'invoices' };
const ID_COL: Record<Kind, string> = {
  quote: 'quote_id',
  invoice: 'invoice_id',
};
const PATH: Record<Kind, string> = { quote: 'q', invoice: 'i' };

/**
 * POST /quotes/share-link, POST /invoices/share-link
 *
 * Returns (and lazily mints) the public share token + URL for a document the
 * caller owns. Idempotent: an existing token is returned unchanged.
 */
export async function getShareLink(
  req: Request,
  caller: Caller,
  kind: Kind,
): Promise<Response> {
  const gate = await requireActiveSubscription(caller.uid);
  if (gate) return gate;

  let id: string | undefined;
  try {
    const body = await req.json() as Record<string, string>;
    id = body.quoteId ?? body.invoiceId;
  } catch { /* validated below */ }

  if (!id) {
    return json(
      { success: false, message: `${kind}Id is required` },
      400,
    );
  }

  const { data: doc } = await admin()
    .from(TABLE[kind])
    .select('id, share_token')
    .eq('id', id)
    .eq('owner_id', caller.uid)
    .maybeSingle();

  if (!doc) {
    return json({ success: false, message: 'Not found' }, 404);
  }

  let token = doc.share_token as string | null;

  if (!token) {
    token = mintToken();
    // The share row and the document's token must not diverge. Insert the
    // share first: a token pointing at a document is harmless, whereas a
    // document naming a token with no share row would 404 for the customer.
    const { error } = await admin().from('document_shares').insert({
      token,
      owner_id: caller.uid,
      [ID_COL[kind]]: id,
    });
    if (error) {
      return json({ success: false, message: error.message }, 500);
    }
    await admin()
      .from(TABLE[kind])
      .update({ share_token: token })
      .eq('id', id)
      .eq('owner_id', caller.uid);
  }

  return json({
    success: true,
    token,
    url: `${publicBaseUrl()}/${PATH[kind]}/${token}`,
  });
}

/**
 * POST /quotes/delete, POST /invoices/delete
 *
 * Deletes the document and TOMBSTONES its shares rather than removing them,
 * so a customer who already has the link sees "withdrawn by the tradesperson"
 * instead of a bare 404.
 */
export async function deleteDocument(
  req: Request,
  caller: Caller,
  kind: Kind,
): Promise<Response> {
  let id: string | undefined;
  try {
    const body = await req.json() as Record<string, string>;
    id = body.quoteId ?? body.invoiceId;
  } catch { /* validated below */ }

  if (!id) {
    return json({ success: false, message: `${kind}Id is required` }, 400);
  }

  const { data: doc } = await admin()
    .from(TABLE[kind])
    .select('id')
    .eq('id', id)
    .eq('owner_id', caller.uid)
    .maybeSingle();

  if (!doc) {
    // Already gone — treat as success so retries are idempotent.
    return json({ success: true, alreadyDeleted: true });
  }

  // Tombstone every share pointing at this document.
  //
  // The RTDB version had to union the document's own `shareToken` with an
  // index scan, because older client builds wiped the token on save. Here
  // `document_shares` is queryable by document id directly, so one statement
  // covers every share regardless of what the document currently says.
  const now = new Date().toISOString();
  const { data: tombstoned } = await admin()
    .from('document_shares')
    .update({ deleted_at: now })
    .eq('owner_id', caller.uid)
    .eq(ID_COL[kind], id)
    .is('deleted_at', null)
    .select('token');

  // Child rows go with it via ON DELETE CASCADE.
  const { error } = await admin()
    .from(TABLE[kind])
    .delete()
    .eq('id', id)
    .eq('owner_id', caller.uid);

  if (error) return json({ success: false, message: error.message }, 500);

  return json({
    success: true,
    sharesTombstoned: (tombstoned ?? []).length,
  });
}
