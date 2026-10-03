'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Approving or rejecting a tradesperson for live leads.
 *
 * A server action is a public endpoint. "The button only rendered for a
 * verifier" is not a check, so the caller's permission is resolved from their
 * own session cookie here, before anything is written.
 *
 * Neither function writes the row directly. `decide_lead_application` does
 * both halves of an approval — this one becomes live, any older one stands
 * down — in a single statement, because two statements from here would leave a
 * window with two live approvals, and the partial unique index would turn that
 * race into a 500 rather than into correct behaviour.
 */

export type Result =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

async function decide(
  applicationId: string,
  approve: boolean,
  reason: string,
): Promise<Result> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'reviewLeadApplications')) {
    return { ok: false, error: 'Your role does not allow that.' }
  }
  if (!applicationId) return { ok: false, error: 'No application was named.' }

  // Said here as well as in the database. The constraint is what makes it
  // true; this is what makes it a sentence instead of a 400.
  if (!approve && reason.length === 0) {
    return { ok: false, error: 'A rejection needs a reason — the applicant is shown it.' }
  }

  const db = supabaseAdmin()

  const { data, error } = await db.rpc('decide_lead_application', {
    in_application_id: applicationId,
    in_approve: approve,
    in_reviewer_id: actor.userId,
    in_reason: approve ? null : reason,
  })

  if (error) return { ok: false, error: error.message }

  const row = Array.isArray(data) ? data[0] : data
  const ownerId = (row?.owner_id as string) ?? null

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: approve ? 'lead_application.approve' : 'lead_application.reject',
    entity: 'lead_applications',
    entityId: applicationId,
    diff: { ownerId, approve, reason: approve ? null : reason },
  })

  revalidatePath('/approvals')
  if (ownerId) revalidatePath(`/tradespeople/${ownerId}`)

  return {
    ok: true,
    message: approve
      ? 'Approved. They have been notified and will start receiving leads.'
      : 'Rejected. They have been notified with your reason.',
    auditError,
  }
}

export async function approveLeadApplication(formData: FormData): Promise<Result> {
  return decide(String(formData.get('application_id') ?? ''), true, '')
}

export async function rejectLeadApplication(formData: FormData): Promise<Result> {
  return decide(
    String(formData.get('application_id') ?? ''),
    false,
    String(formData.get('reason') ?? '').trim(),
  )
}
