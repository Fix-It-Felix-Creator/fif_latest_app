import 'server-only'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Writing to the audit log.
 *
 * The actor is passed in from the session that `requireAdmin()` already
 * resolved, not taken from `auth.uid()`: the panel's cross-user client is the
 * SERVICE ROLE, for which `auth.uid()` is null. A security-definer function
 * that derived the actor that way would record every action as nobody.
 *
 * Auditing must never be the thing that fails an action. A disable that
 * succeeded and went unrecorded is bad; a disable that half-happened because
 * the log write threw is worse. So this returns the problem rather than
 * raising it, and the caller reports it beside the result.
 */
export async function recordAdminAction(input: {
  actorId: string
  actorEmail: string | null
  action: string
  entity: string
  entityId?: string | null
  diff?: unknown
}): Promise<string | null> {
  const { error } = await supabaseAdmin()
    .from('admin_audit_log')
    .insert({
      actor_id: input.actorId,
      actor_email: input.actorEmail,
      action: input.action,
      entity: input.entity,
      entity_id: input.entityId ?? null,
      // The environment is a property of the deployment, not of the row being
      // changed — but the two environments have separate databases, so an
      // entry can only ever describe its own. Recorded anyway so an exported
      // log still says which project it came from.
      env: process.env.NEXT_PUBLIC_FIF_ENV === 'production' ? 'production' : 'staging',
      diff: (input.diff ?? null) as never,
    })
  return error ? error.message : null
}
