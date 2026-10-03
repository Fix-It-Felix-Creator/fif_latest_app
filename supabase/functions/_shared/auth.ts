import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

/**
 * Resolves the caller from the Authorization header.
 *
 * Returns both the caller's id and a service-role client, because these
 * functions exist precisely to write columns the caller cannot:
 * `profiles_guard_server_columns` reserves account_status, verification_status
 * and the deletion timestamps for the service role.
 */
export async function requireUser(req: Request): Promise<{
  userId: string;
  admin: SupabaseClient;
}> {
  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  if (!token) throw new Response('Missing bearer token', { status: 401 });

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Verify the JWT with the anon client — never trust a user-supplied id.
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await caller.auth.getUser();
  if (error || !data.user) throw new Response('Invalid token', { status: 401 });

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  return { userId: data.user.id, admin };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
