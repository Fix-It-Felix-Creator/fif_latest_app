'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin, sessionAccessToken } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { API_SEND_ROLES, can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Sending a notification.
 *
 * The panel does NOT write the rows itself. `POST /notifications/send` on the
 * `api` edge function already does the whole job — the in-app records, the FCM
 * fan-out, and the cleanup of tokens the push gateway reports as dead — and it
 * holds the service account that makes the push possible. Reimplementing that
 * here would be a second fan-out drifting away from the one the apps rely on,
 * and it still could not send a push.
 *
 * So this resolves the caller, decides whether their role may send THIS shape
 * of message, forwards the request with their own JWT, and records what
 * happened. The edge function re-checks `admin_roles` itself, which is what
 * makes forwarding safe: the panel is not vouching for anybody.
 */

export type SendResult =
  | { ok: true; sent: number; pushSent: number; pushFailed: number; auditError: string | null }
  | { ok: false; error: string }

type Payload = {
  title: string
  body: string
  type: string
  toAll: boolean
  recipients: string[]
}

export async function sendNotification(input: Payload): Promise<SendResult> {
  const actor = await currentAdmin()
  if (!actor) return { ok: false, error: 'Your session has expired. Sign in again.' }

  const permission = input.toAll ? 'broadcastNotification' : 'sendNotification'
  if (!can(actor.role, permission)) {
    return {
      ok: false,
      error: input.toAll
        ? 'Your role can message named recipients, but not everyone at once.'
        : 'Your role does not allow sending notifications.',
    }
  }
  // The edge function keeps its own, narrower list. Saying so here turns an
  // opaque 403 into a sentence that names the fix.
  if (!API_SEND_ROLES.includes(actor.role)) {
    return {
      ok: false,
      error: `The api function only accepts ${API_SEND_ROLES.join(', ')}. Your ${actor.role} role is recognised by this panel but not by it.`,
    }
  }

  const title = input.title.trim()
  const body = input.body.trim()
  if (!title || !body) return { ok: false, error: 'A title and a body are both required.' }
  if (!input.toAll && input.recipients.length === 0) {
    return { ok: false, error: 'Name at least one recipient, or choose everyone.' }
  }

  const base = process.env.FIF_API_BASE_URL
  if (!base) {
    return {
      ok: false,
      error: 'FIF_API_BASE_URL is not set, so there is nowhere to send this. See .env.example.',
    }
  }

  const token = await sessionAccessToken()
  if (!token) return { ok: false, error: 'No access token on this session. Sign in again.' }

  let response: Response
  try {
    response = await fetch(`${base}/notifications/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({
        title,
        body,
        type: input.type || 'system',
        ...(input.toAll ? { toAll: true } : { toUserIds: input.recipients }),
      }),
    })
  } catch (e) {
    return {
      ok: false,
      error: `Could not reach the api function: ${e instanceof Error ? e.message : String(e)}`,
    }
  }

  const text = await response.text()
  let parsed: { success?: boolean; message?: string; sent?: number; pushSent?: number; pushFailed?: number } = {}
  try {
    parsed = JSON.parse(text)
  } catch {
    // A non-JSON body is what a gateway error looks like. Passing the first
    // line of it back beats "something went wrong".
  }

  if (!response.ok || parsed.success === false) {
    return {
      ok: false,
      error: parsed.message ?? `The api function answered ${response.status}: ${text.slice(0, 200)}`,
    }
  }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: input.toAll ? 'notification_broadcast' : 'notification_sent',
    entity: 'notifications',
    entityId: null,
    diff: {
      title,
      body,
      type: input.type || 'system',
      to_all: input.toAll,
      // The ids, not just the count: a year later "who got this" is the only
      // question worth asking about a send, and nothing else records it.
      recipients: input.toAll ? null : input.recipients,
      sent: parsed.sent ?? null,
      push_sent: parsed.pushSent ?? null,
      push_failed: parsed.pushFailed ?? null,
    },
  })

  revalidatePath('/notifications')
  return {
    ok: true,
    sent: parsed.sent ?? 0,
    pushSent: parsed.pushSent ?? 0,
    pushFailed: parsed.pushFailed ?? 0,
    auditError,
  }
}

/** How many accounts a broadcast would actually reach, before anyone clicks. */
export async function broadcastReach(): Promise<{ profiles: number; tokens: number }> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'sendNotification')) return { profiles: 0, tokens: 0 }

  const db = supabaseAdmin()
  const [profiles, tokens] = await Promise.all([
    db.from('profiles').select('*', { count: 'exact', head: true }),
    db.from('fcm_tokens').select('*', { count: 'exact', head: true }),
  ])
  return { profiles: profiles.count ?? 0, tokens: tokens.count ?? 0 }
}

/**
 * People to send to, by name.
 *
 * Deliberately not a free-text uuid box: an admin sending to the wrong uuid
 * has no way to notice, whereas picking a name they searched for is checkable.
 */
export async function findRecipients(
  query: string,
): Promise<Array<{ id: string; label: string; accountType: string }>> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'sendNotification')) return []

  const safe = query.replace(/[,()]/g, ' ').trim()
  if (safe.length < 2) return []

  const { data } = await supabaseAdmin()
    .from('profiles')
    .select('id, first_name, last_name, company_name, email, account_type')
    .or(
      [
        `email.ilike.%${safe}%`,
        `first_name.ilike.%${safe}%`,
        `last_name.ilike.%${safe}%`,
        `company_name.ilike.%${safe}%`,
      ].join(','),
    )
    .limit(20)

  return (data ?? []).map((r) => {
    const name =
      [r.first_name, r.last_name].filter(Boolean).join(' ').trim() ||
      (r.company_name as string | null) ||
      null
    return {
      id: r.id as string,
      label: name ? `${name} · ${r.email ?? ''}`.trim() : ((r.email as string) ?? (r.id as string)),
      accountType: (r.account_type as string) ?? 'tradesman',
    }
  })
}
