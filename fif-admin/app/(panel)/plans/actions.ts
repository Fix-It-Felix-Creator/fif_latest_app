'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Editing a plan card.
 *
 * What this writes is what every installed copy of both apps shows on its
 * paywall. There is no staged version and no preview: the row changes, a
 * trigger republishes `app_config.subscriptions`, and the next app launch
 * reads it. So the guard is superAdmin, the before/after goes in the audit log,
 * and the price field says out loud that it does not charge anybody.
 */

export type PlanResult =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

export type PlanInput = {
  id: string
  name: string
  tagline: string
  description: string
  /** One per line, as typed. Blank lines are dropped. */
  featuresText: string
  monthlyPrice: string
  yearlyPrice: string
  availability: string
  badge: string
  isFeatured: boolean
  isActive: boolean
  sortOrder: string
  trialDays: string
  transactionFee: string
  productIdMonthly: string
  productIdYearly: string
  /** Raw JSON, validated before it is written. */
  limitsText: string
  scopedLimitsText: string
}

const AVAILABILITY = ['live', 'coming_soon', 'hidden']

/** A number field that is allowed to be empty, meaning "not set". */
function optionalNumber(value: string, label: string): number | null | Error {
  const trimmed = value.trim()
  if (!trimmed) return null
  const n = Number(trimmed)
  if (!Number.isFinite(n)) return new Error(`${label} is not a number.`)
  return n
}

function parseJsonObject(value: string, label: string): Record<string, unknown> | Error {
  const trimmed = value.trim()
  if (!trimmed) return {}
  let parsed: unknown
  try {
    parsed = JSON.parse(trimmed)
  } catch (e) {
    return new Error(`${label} is not valid JSON: ${e instanceof Error ? e.message : String(e)}`)
  }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return new Error(`${label} has to be a JSON object.`)
  }
  return parsed as Record<string, unknown>
}

export async function savePlan(input: PlanInput): Promise<PlanResult> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'editPlans')) {
    return { ok: false, error: 'Only a super admin can change what the apps show on their paywall.' }
  }

  const name = input.name.trim()
  if (!name) return { ok: false, error: 'A plan needs a name — it is the heading on the card.' }
  if (!AVAILABILITY.includes(input.availability)) {
    return { ok: false, error: `'${input.availability}' is not an availability this schema accepts.` }
  }

  const monthly = Number(input.monthlyPrice.trim() || '0')
  const yearly = Number(input.yearlyPrice.trim() || '0')
  if (!Number.isFinite(monthly) || monthly < 0) return { ok: false, error: 'Monthly price is not a number.' }
  if (!Number.isFinite(yearly) || yearly < 0) return { ok: false, error: 'Yearly price is not a number.' }

  const trialDays = optionalNumber(input.trialDays, 'Trial days')
  if (trialDays instanceof Error) return { ok: false, error: trialDays.message }
  const fee = optionalNumber(input.transactionFee, 'Transaction fee')
  if (fee instanceof Error) return { ok: false, error: fee.message }
  const sortOrder = optionalNumber(input.sortOrder, 'Sort order')
  if (sortOrder instanceof Error) return { ok: false, error: sortOrder.message }

  const limits = parseJsonObject(input.limitsText, 'Limits')
  if (limits instanceof Error) return { ok: false, error: limits.message }
  const scoped = parseJsonObject(input.scopedLimitsText, 'Per-app limits')
  if (scoped instanceof Error) return { ok: false, error: scoped.message }

  const features = input.featuresText
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)

  const db = supabaseAdmin()
  const { data: before, error: readError } = await db
    .from('subscription_plans')
    .select('*')
    .eq('id', input.id)
    .maybeSingle()
  if (readError) return { ok: false, error: `Could not read that plan: ${readError.message}` }
  if (!before) return { ok: false, error: 'No such plan. Plans are seeded by migration, not created here.' }

  // Which scoped-limits column this plan uses is decided by the row, not the
  // form — a customer plan must never be able to write tradesman limits.
  const scopedColumn =
    before.account_type === 'customer'
      ? 'customer_limits'
      : before.account_type === 'business'
        ? 'business_limits'
        : 'tradesman_limits'

  const patch: Record<string, unknown> = {
    name,
    tagline: input.tagline.trim() || null,
    description: input.description.trim(),
    features,
    monthly_price: monthly,
    yearly_price: yearly,
    availability: input.availability,
    badge: input.badge.trim() || null,
    is_featured: input.isFeatured,
    is_active: input.isActive,
    sort_order: sortOrder ?? 0,
    trial_days: trialDays ?? 0,
    transaction_fee: fee,
    product_id_monthly: input.productIdMonthly.trim() || null,
    product_id_yearly: input.productIdYearly.trim() || null,
    limits,
    [scopedColumn]: scoped,
  }

  const { error } = await db.from('subscription_plans').update(patch).eq('id', input.id)
  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  // Only the fields that actually moved. A whole-row before/after on a table
  // this wide buries the one number someone changed.
  const changed: Record<string, { from: unknown; to: unknown }> = {}
  for (const [key, next] of Object.entries(patch)) {
    const prev = (before as Record<string, unknown>)[key]
    if (JSON.stringify(prev) !== JSON.stringify(next)) changed[key] = { from: prev, to: next }
  }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: 'plan_updated',
    entity: 'subscription_plans',
    entityId: input.id,
    diff: { plan: input.id, changed },
  })

  revalidatePath('/plans')
  revalidatePath('/config')

  const count = Object.keys(changed).length
  return {
    ok: true,
    message:
      count === 0
        ? 'Saved — nothing was different.'
        : `Saved ${count} ${count === 1 ? 'change' : 'changes'}. Both apps pick this up on their next launch.`,
    auditError,
  }
}
