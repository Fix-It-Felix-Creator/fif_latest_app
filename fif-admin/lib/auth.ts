import { redirect } from 'next/navigation'
import { cache } from 'react'
import { supabaseAdmin, supabaseSession } from '@/lib/supabase/server'
import { can, type AdminRole, type Permission } from '@/lib/roles'

export type AdminIdentity = {
  userId: string
  email: string | null
  role: AdminRole
  name: string | null
}

/**
 * Who is asking, and as what.
 *
 * The session says who they are; `admin_roles` says whether they are anyone
 * here. Both are needed: a valid Fix It Felix app login is not admin access,
 * and the roster row is what a super admin can revoke.
 *
 * `admin_roles` has RLS on with zero policies, which denies everyone — so this
 * read has to be the service role. That is also the honest shape of the
 * question: asking as the user would answer "are you an admin" with "only if
 * you already are one".
 *
 * Cached per request because nearly every page asks — React's `cache` keys on
 * the request, so two calls in one render are one round trip and the next
 * request still re-checks. A revoked admin must not keep their access because
 * a value was memoised.
 */
export const currentAdmin = cache(async (): Promise<AdminIdentity | null> => {
  const supabase = await supabaseSession()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  // `select('*')` rather than naming columns. `display_name` arrives with the
  // Phase 9 migration, and PostgREST fails the WHOLE select on one unknown
  // column — which would make "the migration is not applied yet" look
  // identical to "you are not staff", on the one screen where that distinction
  // is the entire question. The roster is one row; there is nothing to save by
  // narrowing it.
  const { data, error } = await supabaseAdmin()
    .from('admin_roles')
    .select('*')
    .eq('user_id', user.id)
    .maybeSingle()

  if (error) {
    // Not swallowed. A roster read that fails is a misconfiguration — a wrong
    // key, a missing table — and returning null would report it to the person
    // signing in as a rejection they cannot act on.
    throw new Error(
      `Could not read admin_roles: ${error.message}. Check SUPABASE_SERVICE_ROLE_KEY, and that this project has the admin_roles table.`,
    )
  }
  if (!data || !data.is_active) return null

  return {
    userId: user.id,
    email: user.email ?? null,
    role: data.role as AdminRole,
    name: (data.display_name as string | null) ?? null,
  }
})

/** Every page starts here. No role, no page. */
export async function requireAdmin(): Promise<AdminIdentity> {
  const admin = await currentAdmin()
  if (!admin) redirect('/login')
  return admin
}

/**
 * A page that needs more than a pulse.
 *
 * Sends the unauthorised somewhere they CAN go rather than to a dead end — a
 * verifier following a stale link to the invoice ledger should land on the
 * dashboard, not on a wall.
 */
export async function requirePermission(permission: Permission): Promise<AdminIdentity> {
  const admin = await requireAdmin()
  if (!can(admin.role, permission)) redirect('/?denied=' + permission)
  return admin
}

/**
 * The caller's own access token, for the one thing the panel delegates.
 *
 * Push notifications are sent by the `api` edge function, which holds the FCM
 * service account. It authenticates the caller itself and re-checks
 * `admin_roles` — so it gets the admin's real JWT, not the service-role key.
 * Handing it the service key would turn a route that verifies who is asking
 * into one that cannot.
 */
export async function sessionAccessToken(): Promise<string | null> {
  const supabase = await supabaseSession()
  const {
    data: { session },
  } = await supabase.auth.getSession()
  return session?.access_token ?? null
}
