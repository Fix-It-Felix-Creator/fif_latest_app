'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { can, type Permission } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'
import { appConfig } from '@/lib/queries'

/**
 * Everything the panel can change about a person, and the guards around it.
 *
 * A server action is a public endpoint. "The button only rendered for a super
 * admin" is not a check — so every function here resolves the caller's
 * permission from their own session cookie, exactly as the page did, before
 * touching a row.
 *
 * All four columns these write (`verification_status`, `account_status` and
 * the two deletion timestamps) are reserved for the service role by
 * `profiles_guard_server_columns`. That trigger is why this panel exists as a
 * server app at all: no client, however privileged its UI, can set them.
 */

export type Result =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

type Target = {
  id: string
  email: string | null
  first_name: string | null
  last_name: string | null
  account_type: string
  account_status: string
  verification_status: string | null
}

const TARGET_COLUMNS =
  'id, email, first_name, last_name, account_type, account_status, verification_status'

async function guard(
  permission: Permission,
  userId: string,
): Promise<
  | { ok: false; error: string }
  | { ok: true; actorId: string; actorEmail: string | null; target: Target }
> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, permission)) {
    return { ok: false, error: 'Your role does not allow that.' }
  }
  if (!userId) return { ok: false, error: 'No account was named.' }

  const { data, error } = await supabaseAdmin()
    .from('profiles')
    .select(TARGET_COLUMNS)
    .eq('id', userId)
    .maybeSingle()

  if (error) return { ok: false, error: `Could not read that profile: ${error.message}` }
  if (!data) return { ok: false, error: 'No such account — it may already be gone.' }

  return { ok: true, actorId: actor.userId, actorEmail: actor.email, target: data as Target }
}

function nameOf(t: Target): string {
  return [t.first_name, t.last_name].filter(Boolean).join(' ').trim() || t.email || t.id
}

function paths(t: Target): string[] {
  return t.account_type === 'customer'
    ? ['/customers', `/customers/${t.id}`]
    : ['/tradespeople', `/tradespeople/${t.id}`]
}

// ============================================================
// Verification
// ============================================================

/**
 * The four values `profiles_verification_status_check` permits.
 *
 * Worth stating in one place, because the app's own
 * `tradesman-verification` edge function writes `'pending'`, which this
 * constraint rejects — the panel uses the vocabulary the database actually
 * accepts rather than the one that function assumes.
 */
const VERIFICATION_VALUES = ['waiting', 'verified', 'unverified', 'rejected'] as const
type VerificationValue = (typeof VERIFICATION_VALUES)[number]

export async function setVerification(formData: FormData): Promise<Result> {
  const userId = String(formData.get('user_id') ?? '')
  const status = String(formData.get('status') ?? '') as VerificationValue
  const reason = String(formData.get('reason') ?? '').trim()

  if (!VERIFICATION_VALUES.includes(status)) {
    return { ok: false, error: `'${status}' is not a verification status this schema accepts.` }
  }
  // A rejection with no reason is the one outcome a person has to act on and
  // cannot, so it is refused here rather than half-saved.
  if (status === 'rejected' && !reason) {
    return { ok: false, error: 'Say why. The reason is shown to them in the app.' }
  }

  const checked = await guard('reviewVerification', userId)
  if (!checked.ok) return checked
  const { actorId, actorEmail, target } = checked

  const { error } = await supabaseAdmin()
    .from('profiles')
    .update({
      verification_status: status,
      // Cleared on anything but a rejection: a stale reason left behind an
      // approval reads, in the app, as a reason they were turned down.
      rejection_reason: status === 'rejected' ? reason : null,
    })
    .eq('id', userId)

  if (error) return { ok: false, error: `The update was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId,
    actorEmail,
    action: `verification_${status}`,
    entity: 'profiles',
    entityId: userId,
    diff: {
      email: target.email,
      from: target.verification_status,
      to: status,
      reason: reason || null,
    },
  })

  // Arrow, not a point-free `forEach(revalidatePath)`: forEach passes the
  // index as the second argument, which revalidatePath reads as its `type`.
  paths(target).forEach((path) => revalidatePath(path))
  revalidatePath('/approvals')
  return {
    ok: true,
    message: `${nameOf(target)} is now ${status}.`,
    auditError,
  }
}

// ============================================================
// Account status
// ============================================================

export async function setAccountStatus(formData: FormData): Promise<Result> {
  const userId = String(formData.get('user_id') ?? '')
  const next = String(formData.get('status') ?? '')

  if (next !== 'active' && next !== 'disabled') {
    return { ok: false, error: 'An account can only be made active or disabled here.' }
  }

  const checked = await guard('manageAccount', userId)
  if (!checked.ok) return checked
  const { actorId, actorEmail, target } = checked

  if (target.account_status === 'deletion_pending') {
    return {
      ok: false,
      error:
        'This account is mid-deletion. Recover it first — flipping the status alone would leave the deletion timestamps in place and it would be purged anyway.',
    }
  }

  // Staff cannot lock themselves, or each other, out of the panel from the
  // people pages. Revoking a colleague is what Admin roles is for, and doing
  // it here would take their app account with it.
  const roster = await supabaseAdmin()
    .from('admin_roles')
    .select('role')
    .eq('user_id', userId)
    .maybeSingle()
  if (roster.data && next === 'disabled') {
    return {
      ok: false,
      error: `That account holds the ${roster.data.role} staff role. Revoke it on Admin roles first.`,
    }
  }

  const { error } = await supabaseAdmin()
    .from('profiles')
    .update({ account_status: next })
    .eq('id', userId)

  if (error) return { ok: false, error: `The update was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId,
    actorEmail,
    action: next === 'disabled' ? 'account_disabled' : 'account_enabled',
    entity: 'profiles',
    entityId: userId,
    diff: { email: target.email, from: target.account_status, to: next },
  })

  // Arrow, not a point-free `forEach(revalidatePath)`: forEach passes the
  // index as the second argument, which revalidatePath reads as its `type`.
  paths(target).forEach((path) => revalidatePath(path))
  return {
    ok: true,
    message:
      next === 'disabled'
        ? `${nameOf(target)} is disabled. They stay signed in until their token expires.`
        : `${nameOf(target)} can use the app again.`,
    auditError,
  }
}

// ============================================================
// Deletion and recovery
// ============================================================

const DAY_MS = 24 * 60 * 60 * 1000

/**
 * Starts the deletion clock on someone's behalf.
 *
 * Deliberately the same shape as the user's own request — `deletion_pending`,
 * a recovery deadline and a retention deadline — rather than a hard delete.
 * The app routes a deletion_pending account to its recovery screen, so this
 * stays reversible by the person it happened to, which is what a support agent
 * acting on a phone call actually needs.
 *
 * Nothing here removes the auth user. That is not an omission: the recovery
 * window only works if they can still sign in, and a hard delete belongs in
 * the purge job the spec (§5.10) says nobody has written yet.
 */
export async function startDeletion(formData: FormData): Promise<Result> {
  const userId = String(formData.get('user_id') ?? '')
  const confirm = String(formData.get('confirm') ?? '').trim().toLowerCase()

  const checked = await guard('manageAccount', userId)
  if (!checked.ok) return checked
  const { actorId, actorEmail, target } = checked

  const actor = await currentAdmin()
  if (actor?.userId === userId) {
    return { ok: false, error: 'That is your own account. Use another admin, or the app itself.' }
  }

  // Typed confirmation, matched against the row just read rather than against
  // anything else the form carried. A form that supplies both the target and
  // the confirmation confirms nothing.
  const expected = (target.email ?? target.id).toLowerCase()
  if (confirm !== expected) {
    return { ok: false, error: `Type ${target.email ?? target.id} exactly to confirm.` }
  }

  const config = (await appConfig('accountDeletion')) ?? {}
  const recoveryDays = Number(config.recoveryWaitDays ?? 14)
  const retentionDays = Number(config.personalDataRetentionDays ?? 90)
  const now = new Date()
  const recoveryEnds = new Date(now.getTime() + recoveryDays * DAY_MS)
  const retainedUntil = new Date(now.getTime() + retentionDays * DAY_MS)

  const { error } = await supabaseAdmin()
    .from('profiles')
    .update({
      account_status: 'deletion_pending',
      deletion_requested_at: now.toISOString(),
      deletion_scheduled_at: recoveryEnds.toISOString(),
      recovery_window_ends_at: recoveryEnds.toISOString(),
      personal_data_retained_until: retainedUntil.toISOString(),
    })
    .eq('id', userId)

  if (error) return { ok: false, error: `The update was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId,
    actorEmail,
    action: 'deletion_started',
    entity: 'profiles',
    entityId: userId,
    diff: {
      email: target.email,
      recovery_days: recoveryDays,
      retention_days: retentionDays,
      recovery_window_ends_at: recoveryEnds.toISOString(),
      personal_data_retained_until: retainedUntil.toISOString(),
    },
  })

  // Arrow, not a point-free `forEach(revalidatePath)`: forEach passes the
  // index as the second argument, which revalidatePath reads as its `type`.
  paths(target).forEach((path) => revalidatePath(path))
  revalidatePath('/deletions')
  return {
    ok: true,
    message: `${nameOf(target)} can recover until ${recoveryEnds.toLocaleDateString('en-GB')}.`,
    auditError,
  }
}

export async function recoverAccount(formData: FormData): Promise<Result> {
  const userId = String(formData.get('user_id') ?? '')

  const checked = await guard('manageAccount', userId)
  if (!checked.ok) return checked
  const { actorId, actorEmail, target } = checked

  const { error } = await supabaseAdmin()
    .from('profiles')
    .update({
      account_status: 'active',
      deletion_requested_at: null,
      deletion_scheduled_at: null,
      recovery_window_ends_at: null,
      personal_data_retained_until: null,
    })
    .eq('id', userId)

  if (error) return { ok: false, error: `The update was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId,
    actorEmail,
    action: 'deletion_cancelled',
    entity: 'profiles',
    entityId: userId,
    diff: { email: target.email, from: target.account_status },
  })

  // Arrow, not a point-free `forEach(revalidatePath)`: forEach passes the
  // index as the second argument, which revalidatePath reads as its `type`.
  paths(target).forEach((path) => revalidatePath(path))
  revalidatePath('/deletions')
  return { ok: true, message: `${nameOf(target)} is active again.`, auditError }
}
