import { createServerClient } from '@supabase/ssr'
import { createClient } from '@supabase/supabase-js'
import { cookies } from 'next/headers'

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL!
const ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

/**
 * The signed-in admin, acting as themselves. Everything RLS says they may not
 * read, they may not read here either.
 */
export async function supabaseSession() {
  const store = await cookies()
  return createServerClient(URL, ANON, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (list) => {
        try {
          list.forEach(({ name, value, options }) => store.set(name, value, options))
        } catch {
          // Called from a Server Component, where cookies are read-only. The
          // middleware refreshes the session, so losing the write here is
          // nothing — swallowing it is the documented pattern.
        }
      },
    },
  })
}

/**
 * Past RLS, for reading other people's rows.
 *
 * The whole point of this panel is to see data that belongs to someone else,
 * and every policy in this schema is `auth.uid() = owner_id` — so no policy
 * grants it and the reads run as the service role. Three rules make that safe,
 * and they live in `lib/auth.ts` rather than here:
 *
 *   1. Nothing calls this without first resolving the caller's admin role from
 *      their own session cookie. `requireAdmin()` is the only intended door.
 *   2. This key is server-only. It has no NEXT_PUBLIC prefix, so importing
 *      this file into a client component is a build error rather than a leak.
 *   3. Exactly one project's key is ever loaded — see lib/env.ts. A staging
 *      deployment has no credential that reaches production.
 *
 * It is also the only client that can WRITE the server-owned columns:
 * `profiles_guard_server_columns` reserves verification_status, account_status
 * and the deletion timestamps for the service role, which is precisely the set
 * of things this panel exists to change.
 */
export function supabaseAdmin() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!key) {
    throw new Error(
      'SUPABASE_SERVICE_ROLE_KEY is not set — the panel cannot read across users without it. Copy .env.example to .env.local and fill it in.',
    )
  }
  return createClient(URL, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}
