import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Service-role client.
 *
 * These routes legitimately act on behalf of users and across users (public
 * share pages read a quote nobody is signed in for), so they run with the
 * service role and do their own authorisation — exactly as the Cloud
 * Functions did with firebase-admin. Every handler that touches user data
 * must therefore scope its own queries; RLS is NOT a safety net here.
 */
let _admin: SupabaseClient | null = null;

export function admin(): SupabaseClient {
  if (!_admin) {
    _admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );
  }
  return _admin;
}

export interface Caller {
  uid: string;
  email?: string;
}

/**
 * Verifies a Supabase access token from the Authorization header.
 *
 * Replaces `verifyFirebaseToken`. The token is verified by asking GoTrue, not
 * by decoding it locally — a locally-decoded JWT proves nothing without
 * signature verification, and getting that wrong is the classic auth bug.
 */
export async function verifyToken(req: Request): Promise<Caller | null> {
  const header = req.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;

  const token = header.slice('Bearer '.length).trim();
  if (!token) return null;

  const { data, error } = await admin().auth.getUser(token);
  if (error || !data.user) return null;

  return { uid: data.user.id, email: data.user.email ?? undefined };
}

/**
 * The roles this function accepts.
 *
 * `admin` and `superAdmin` are the original pair. `support` joins them because
 * answering a ticket routinely means messaging the person who raised it, and
 * the admin panel's spec (docs/admin-panel-dashboard-spec.md §4.2) gives that
 * role single-recipient sends.
 *
 * `verifier` and `analyst` are deliberately NOT here. A verifier reviews
 * identity documents and an analyst reads aggregates; neither has any reason
 * to be able to push a notification to somebody's phone, and a broadcast is
 * the one action in this codebase that cannot be undone.
 *
 * The panel keeps a finer matrix of its own (lib/roles.ts) that splits single
 * sends from broadcasts. This list is the floor underneath it: the panel
 * decides what to offer, and this decides what is allowed.
 */
const SENDING_ROLES = ['superAdmin', 'admin', 'support'];

/**
 * True when the caller is an active admin.
 *
 * Was RTDB `config/admin/systemRoles/{uid}`; now the `admin_roles` table,
 * which no client can read.
 */
export async function isAdmin(uid: string): Promise<boolean> {
  const { data, error } = await admin()
    .from('admin_roles')
    .select('role, is_active')
    .eq('user_id', uid)
    .maybeSingle();

  if (error || !data) return false;
  if (data.is_active !== true) return false;
  return SENDING_ROLES.includes(data.role);
}

/**
 * Fixed-window rate limit. Returns true when the caller may proceed.
 *
 * Fails OPEN on error: a database hiccup must not take down the public share
 * pages, which are customer-facing and already rate-limited upstream by
 * Supabase's own platform limits.
 */
export async function rateLimit(
  bucket: string,
  limit: number,
  windowSeconds = 60,
): Promise<boolean> {
  try {
    const { data, error } = await admin().rpc('rate_limit_check', {
      p_bucket: bucket,
      p_limit: limit,
      p_window_seconds: windowSeconds,
    });
    if (error) return true;
    return data !== false;
  } catch {
    return true;
  }
}

/** Client IP for rate-limit bucketing, behind Supabase's proxy. */
export function callerIp(req: Request): string {
  return (
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('cf-connecting-ip') ??
    'unknown'
  );
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export function html(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
