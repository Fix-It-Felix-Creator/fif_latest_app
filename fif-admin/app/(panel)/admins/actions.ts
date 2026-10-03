'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { ADMIN_ROLES, can, type AdminRole } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Who gets in, and as what.
 *
 * `admin_roles` is keyed by `auth.users.id`, so granting access means finding
 * an existing account — there is no invite flow and deliberately so. Staff sign
 * in with a real Fix It Felix account; creating logins from here would mean the
 * panel minting credentials for a production auth pool.
 *
 * Revoking sets `is_active = false` rather than deleting the row. The audit log
 * references it, and "this person used to be a verifier" is exactly the thing
 * someone reviewing an old entry needs to still be able to see.
 */

export type RosterResult =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

async function guard(): Promise<
  { ok: false; error: string } | { ok: true; actorId: string; actorEmail: string | null }
> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'manageAdmins')) {
    return { ok: false, error: 'Only a super admin can change the roster.' }
  }
  return { ok: true, actorId: actor.userId, actorEmail: actor.email }
}

/** The auth user behind an email address, or nothing. */
async function findUser(email: string): Promise<{ id: string; email: string } | null> {
  const db = supabaseAdmin()

  // `profiles` first: it is an ordinary table, indexed, and every account that
  // has ever opened either app has a row. Only fall through to paging the auth
  // list for the rare account that authenticated and never got a profile.
  const { data: profile } = await db
    .from('profiles')
    .select('id, email')
    .ilike('email', email)
    .maybeSingle()
  if (profile?.id) return { id: profile.id as string, email: (profile.email as string) ?? email }

  const { data } = await db.auth.admin.listUsers({ page: 1, perPage: 1000 })
  const match = data?.users.find((u) => (u.email ?? '').toLowerCase() === email.toLowerCase())
  return match ? { id: match.id, email: match.email ?? email } : null
}

export async function grantRole(formData: FormData): Promise<RosterResult> {
  const checked = await guard()
  if (!checked.ok) return checked

  const email = String(formData.get('email') ?? '').trim().toLowerCase()
  const role = String(formData.get('role') ?? '') as AdminRole
  const displayName = String(formData.get('display_name') ?? '').trim()

  if (!email) return { ok: false, error: 'An email address is needed.' }
  if (!ADMIN_ROLES.includes(role)) return { ok: false, error: `'${role}' is not a role.` }

  const user = await findUser(email)
  if (!user) {
    return {
      ok: false,
      error: `No account on this project uses ${email}. They have to sign up in one of the apps first — the panel does not create logins.`,
    }
  }

  const db = supabaseAdmin()
  const { data: existing } = await db
    .from('admin_roles')
    .select('role, is_active')
    .eq('user_id', user.id)
    .maybeSingle()

  const { error } = await db.from('admin_roles').upsert(
    {
      user_id: user.id,
      role,
      is_active: true,
      display_name: displayName || null,
      created_by: checked.actorId,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  )

  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId: checked.actorId,
    actorEmail: checked.actorEmail,
    action: existing ? 'admin_role_changed' : 'admin_role_granted',
    entity: 'admin_roles',
    entityId: user.id,
    diff: {
      email: user.email,
      from: existing ? { role: existing.role, is_active: existing.is_active } : null,
      to: { role, is_active: true },
    },
  })

  revalidatePath('/admins')
  return { ok: true, message: `${user.email} is now ${role} on this project.`, auditError }
}

export async function setActive(formData: FormData): Promise<RosterResult> {
  const checked = await guard()
  if (!checked.ok) return checked

  const userId = String(formData.get('user_id') ?? '')
  const active = String(formData.get('active') ?? '') === 'true'

  // A super admin who revokes themselves is locked out of the only screen that
  // could undo it, and on a one-super-admin project that is the end of the
  // roster. Refused rather than confirmed — there is no good version of this.
  if (userId === checked.actorId && !active) {
    return {
      ok: false,
      error: 'That is your own access. Have another super admin revoke it, or you lock yourself out of this page.',
    }
  }

  const db = supabaseAdmin()
  const { data: existing } = await db
    .from('admin_roles')
    .select('role, is_active, display_name')
    .eq('user_id', userId)
    .maybeSingle()
  if (!existing) return { ok: false, error: 'That person is not on the roster.' }

  const { error } = await db
    .from('admin_roles')
    .update({ is_active: active, updated_at: new Date().toISOString() })
    .eq('user_id', userId)

  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId: checked.actorId,
    actorEmail: checked.actorEmail,
    action: active ? 'admin_role_restored' : 'admin_role_revoked',
    entity: 'admin_roles',
    entityId: userId,
    diff: { role: existing.role, name: existing.display_name, is_active: active },
  })

  revalidatePath('/admins')
  return {
    ok: true,
    message: active ? 'Access restored.' : 'Access revoked. The row is kept so the audit log still reads.',
    auditError,
  }
}
