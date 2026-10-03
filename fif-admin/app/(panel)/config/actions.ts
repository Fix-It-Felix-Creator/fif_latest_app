'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Editing what both apps read at launch.
 *
 * `app_config` is publicly readable and service-role writable, which is why
 * this is a server action rather than anything the browser does directly. It
 * is also the highest-blast-radius screen in the panel: a bad
 * `prod_maintenance` locks every installed copy of both apps out at once, and
 * a bad `force_app_update` does the same with no way back except another edit
 * here. Hence superAdmin only, and hence the before/after in the audit row.
 */

export type ConfigResult =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

export async function saveConfig(key: string, raw: string): Promise<ConfigResult> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'writeConfig')) {
    return { ok: false, error: 'Only a super admin can change what the apps read.' }
  }

  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch (e) {
    return { ok: false, error: `That is not valid JSON: ${e instanceof Error ? e.message : String(e)}` }
  }
  // Every row in this table is a jsonb OBJECT — ConfigService reads named
  // fields off it, and a bare string or array would parse as nothing and take
  // the value's defaults with it.
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return { ok: false, error: 'The value has to be a JSON object — the apps read named fields off it.' }
  }

  const db = supabaseAdmin()
  // Read first, so the audit row can carry what it was. Without the before,
  // the log says a change happened but not what it undid.
  const { data: existing } = await db.from('app_config').select('value').eq('key', key).maybeSingle()

  const { error } = await db
    .from('app_config')
    .upsert({ key, value: value as never }, { onConflict: 'key' })

  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: existing ? 'config_updated' : 'config_created',
    entity: 'app_config',
    entityId: key,
    diff: { before: existing?.value ?? null, after: value },
  })

  revalidatePath('/config')
  return {
    ok: true,
    message: `Saved. Installed apps pick this up on their next launch, or sooner if their cache refreshes.`,
    auditError,
  }
}
