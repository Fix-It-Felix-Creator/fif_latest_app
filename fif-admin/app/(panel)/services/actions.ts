'use server'

import { revalidatePath } from 'next/cache'
import { currentAdmin } from '@/lib/auth'
import { recordAdminAction } from '@/lib/audit'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'
import { MAX_THUMBNAIL_BYTES } from './limits'

/**
 * Editing the service catalogue and its question flows.
 *
 * The flow is the part that matters. It is the nested set of questions a
 * customer walks to describe a job, so changing it changes what both apps ask
 * and what a tradesperson receives. Hence superAdmin, and hence the audit
 * entry records which fields moved rather than the whole 14KB document.
 */

export type ServiceResult =
  | { ok: true; message: string; auditError: string | null }
  | { ok: false; error: string }

export type ServiceInput = {
  id: string
  name: string
  subtitle: string
  description: string
  icon: string
  color: string
  groupId: string
  isPopular: boolean
  hasEmergency: boolean
  isActive: boolean
  sortOrder: string
  flowTitle: string
  flowSubtitle: string
  /** The question tree, as JSON. Validated before it is written. */
  categoriesText: string
}

/**
 * Validates the question tree.
 *
 * Shape errors here would surface in the apps as a blank step or a dead end
 * mid-flow, which is the worst place to find them — so the parse is strict
 * about the things the apps actually rely on: an array of categories, each
 * with an id and a name, and options nesting the same way.
 */
function parseCategories(raw: string): unknown[] | Error {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return new Error(`The flow is not valid JSON: ${e instanceof Error ? e.message : String(e)}`)
  }
  if (!Array.isArray(parsed)) return new Error('The flow has to be an array of categories.')

  const problems: string[] = []
  const walk = (nodes: unknown[], path: string) => {
    nodes.forEach((node, i) => {
      const where = `${path}[${i}]`
      if (node === null || typeof node !== 'object' || Array.isArray(node)) {
        problems.push(`${where} is not an object`)
        return
      }
      const n = node as Record<string, unknown>
      if (typeof n.id !== 'string' || !n.id.trim()) problems.push(`${where} has no id`)
      if (typeof n.name !== 'string' || !n.name.trim()) problems.push(`${where} has no name`)
      if (n.options !== undefined) {
        if (!Array.isArray(n.options)) problems.push(`${where}.options is not an array`)
        else walk(n.options, `${where}.options`)
      }
    })
  }
  walk(parsed, 'categories')

  // Duplicate ids inside one parent make a selection ambiguous — the app
  // records the id, and two siblings sharing one means the answer cannot be
  // read back reliably.
  const dupes: string[] = []
  const checkSiblings = (nodes: unknown[], path: string) => {
    const seen = new Set<string>()
    nodes.forEach((node) => {
      const n = node as Record<string, unknown>
      const id = typeof n?.id === 'string' ? n.id : null
      if (id) {
        if (seen.has(id)) dupes.push(`${path}: two entries share the id "${id}"`)
        seen.add(id)
      }
      if (Array.isArray(n?.options)) checkSiblings(n.options as unknown[], `${path} › ${id}`)
    })
  }
  checkSiblings(parsed, 'categories')

  const all = [...problems, ...dupes]
  if (all.length) {
    return new Error(
      all.length <= 4 ? all.join('; ') : `${all.slice(0, 4).join('; ')} — and ${all.length - 4} more`,
    )
  }
  return parsed
}

export async function saveService(input: ServiceInput): Promise<ServiceResult> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'editServices')) {
    return { ok: false, error: 'Only a super admin can change the service catalogue.' }
  }

  const name = input.name.trim()
  if (!name) return { ok: false, error: 'A service needs a name — it is the tile a customer taps.' }

  const categories = parseCategories(input.categoriesText)
  if (categories instanceof Error) return { ok: false, error: categories.message }

  const sortOrder = Number(input.sortOrder.trim() || '0')
  if (!Number.isFinite(sortOrder)) return { ok: false, error: 'Sort order is not a number.' }

  const db = supabaseAdmin()
  const { data: before, error: readError } = await db
    .from('services')
    .select('*')
    .eq('id', input.id)
    .maybeSingle()
  if (readError) return { ok: false, error: `Could not read that service: ${readError.message}` }
  if (!before) return { ok: false, error: 'No such service.' }

  const patch: Record<string, unknown> = {
    name,
    subtitle: input.subtitle.trim() || null,
    description: input.description.trim(),
    icon: input.icon.trim() || null,
    color: input.color.trim() || null,
    group_id: input.groupId.trim() || null,
    is_popular: input.isPopular,
    has_emergency: input.hasEmergency,
    is_active: input.isActive,
    sort_order: sortOrder,
    flow_title: input.flowTitle.trim(),
    flow_subtitle: input.flowSubtitle.trim() || null,
    categories,
  }

  const { error } = await db.from('services').update(patch).eq('id', input.id)
  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  // Field names only for the tree — a before/after of 2,000 options would bury
  // the one word someone changed, and the row itself is the current state.
  const changed: string[] = []
  for (const [key, next] of Object.entries(patch)) {
    const prev = (before as Record<string, unknown>)[key]
    if (JSON.stringify(prev) !== JSON.stringify(next)) changed.push(key)
  }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: 'service_updated',
    entity: 'services',
    entityId: input.id,
    diff: {
      service: input.id,
      changed,
      // The flow gets counts rather than content, for the same reason.
      ...(changed.includes('categories')
        ? {
            flow: {
              from: countTree((before as Record<string, unknown>).categories),
              to: countTree(categories),
            },
          }
        : {}),
    },
  })

  revalidatePath('/services')
  return {
    ok: true,
    message: changed.length
      ? `Saved ${changed.length} ${changed.length === 1 ? 'change' : 'changes'}. Both apps pick this up on their next load.`
      : 'Saved — nothing was different.',
    auditError,
  }
}

function countTree(value: unknown): { categories: number; options: number } {
  if (!Array.isArray(value)) return { categories: 0, options: 0 }
  let options = 0
  const walk = (nodes: unknown[]) =>
    nodes.forEach((n) => {
      options++
      const kids = (n as Record<string, unknown>)?.options
      if (Array.isArray(kids)) walk(kids)
    })
  value.forEach((c) => {
    const kids = (c as Record<string, unknown>)?.options
    if (Array.isArray(kids)) walk(kids)
  })
  return { categories: value.length, options }
}

/**
 * Stores a thumbnail.
 *
 * The bytes arrive already cropped and re-encoded by the browser, which is
 * where that work belongs: the editor shows the crop, so the file that lands
 * here is the file a customer will download. This still refuses anything over
 * the ceiling rather than trusting it — a server action is a public endpoint,
 * and "the client promised it resized" is not a size check.
 */
export async function saveThumbnail(
  serviceId: string,
  dataUrl: string,
): Promise<ServiceResult & { url?: string }> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'editServices')) {
    return { ok: false, error: 'Only a super admin can change service artwork.' }
  }

  const match = /^data:(image\/(jpeg|png|webp));base64,(.+)$/.exec(dataUrl)
  if (!match) return { ok: false, error: 'That is not a JPEG, PNG or WebP image.' }
  const [, contentType, ext, b64] = match
  const bytes = Buffer.from(b64, 'base64')

  if (bytes.byteLength > MAX_THUMBNAIL_BYTES) {
    return {
      ok: false,
      error: `That is ${(bytes.byteLength / 1_000_000).toFixed(2)}MB. Crop tighter or lower the quality — the ceiling is 1MB so customer tiles load quickly.`,
    }
  }

  const db = supabaseAdmin()
  const { data: before } = await db
    .from('services')
    .select('thumbnail_path')
    .eq('id', serviceId)
    .maybeSingle()

  // A new name per upload, so a replaced image cannot be served from a CDN
  // cache keyed on the old path.
  const path = `${serviceId}-${Date.now()}.${ext === 'jpeg' ? 'jpg' : ext}`
  const { error: uploadError } = await db.storage
    .from('service-thumbnails')
    .upload(path, bytes, { contentType, upsert: true })
  if (uploadError) return { ok: false, error: `Upload failed: ${uploadError.message}` }

  const { data: pub } = db.storage.from('service-thumbnails').getPublicUrl(path)
  const { error } = await db
    .from('services')
    .update({ thumbnail_url: pub.publicUrl, thumbnail_path: path })
    .eq('id', serviceId)
  if (error) return { ok: false, error: `Saved the file but could not record it: ${error.message}` }

  // Only after the row points at the new object — deleting first would leave
  // the service with no artwork if the update then failed.
  const priorPath = (before?.thumbnail_path as string | null) ?? null
  if (priorPath && priorPath !== path) {
    await db.storage.from('service-thumbnails').remove([priorPath])
  }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: 'service_thumbnail_set',
    entity: 'services',
    entityId: serviceId,
    diff: { path, bytes: bytes.byteLength, replaced: priorPath },
  })

  revalidatePath('/services')
  return {
    ok: true,
    url: pub.publicUrl,
    message: `Saved at ${Math.round(bytes.byteLength / 1024)}KB.`,
    auditError,
  }
}

/** Points the service at an image hosted elsewhere, with no upload. */
export async function setThumbnailUrl(
  serviceId: string,
  url: string,
): Promise<ServiceResult> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'editServices')) {
    return { ok: false, error: 'Only a super admin can change service artwork.' }
  }

  const trimmed = url.trim()
  if (trimmed && !/^https:\/\/\S+$/i.test(trimmed)) {
    return { ok: false, error: 'Use an https:// URL, or clear the box to remove the image.' }
  }

  const db = supabaseAdmin()
  const { error } = await db
    .from('services')
    // thumbnail_path is cleared: the row no longer points at an object this
    // panel owns, so nothing here should later delete whatever is at that path.
    .update({ thumbnail_url: trimmed || null, thumbnail_path: null })
    .eq('id', serviceId)
  if (error) return { ok: false, error: `The write was refused: ${error.message}` }

  const auditError = await recordAdminAction({
    actorId: actor.userId,
    actorEmail: actor.email,
    action: trimmed ? 'service_thumbnail_linked' : 'service_thumbnail_cleared',
    entity: 'services',
    entityId: serviceId,
    diff: { url: trimmed || null },
  })

  revalidatePath('/services')
  return {
    ok: true,
    message: trimmed ? 'Linked. Nothing was uploaded.' : 'Image removed.',
    auditError,
  }
}
