#!/usr/bin/env node
/**
 * Imports the old mobile app's service flows into `public.services`.
 *
 * The flows are 37 JSON files totalling ~284KB — too much to sit in a
 * migration, and they are editable content rather than schema, so they are
 * imported once and maintained in the panel afterwards.
 *
 * Idempotent: re-running upserts by id. It deliberately does NOT overwrite
 * `thumbnail_url`, `thumbnail_path`, `is_active` or `sort_order` on a service
 * that already exists — those are set by a person in the panel, and a re-import
 * to pick up a flow change must not undo their work.
 *
 *   node scripts/import-services.mjs            # dry run, prints what it would do
 *   node scripts/import-services.mjs --apply
 *   node scripts/import-services.mjs --apply --images   # also upload artwork
 */

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join, basename, extname } from 'node:path'
import { createClient } from '@supabase/supabase-js'

const SOURCE =
  process.env.FIF_SERVICES_DIR ??
  '../../old_app_code/old_apps/fixitfelix_mobile/assets/documents/services'
const IMAGES =
  process.env.FIF_SERVICE_IMAGES_DIR ??
  '../../old_app_code/old_apps/fixitfelix_mobile/assets/images/services'

const apply = process.argv.includes('--apply')
const withImages = process.argv.includes('--images')

const url = process.env.NEXT_PUBLIC_SUPABASE_URL
const key = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!url || !key) {
  console.error('Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (source .env.local).')
  process.exit(1)
}
const db = createClient(url, key, { auth: { persistSession: false } })

// ---- read the index, which carries the presentation metadata ---------------
const index = JSON.parse(readFileSync(join(SOURCE, 'services_index.json'), 'utf8'))
const byId = new Map(index.services.map((s) => [s.id, s]))
const groupIdFor = (name) =>
  name ? name.toLowerCase().replace(/&/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') : null

// ---- every flow file is a service, indexed or not --------------------------
const files = readdirSync(SOURCE)
  .filter((f) => f.endsWith('.json') && f !== 'services_index.json')
  .sort()

function countTree(categories) {
  let options = 0
  const walk = (list) => list.forEach((o) => { options++; walk(o.options ?? []) })
  categories.forEach((c) => walk(c.options ?? []))
  return { categories: categories.length, options }
}

const rows = []
const incomplete = []
for (const file of files) {
  const id = basename(file, '.json')
  const flow = JSON.parse(readFileSync(join(SOURCE, file), 'utf8'))
  const meta = byId.get(id)
  const categories = flow.categories ?? []
  const counts = countTree(categories)

  if (!meta) incomplete.push(id)

  rows.push({
    id,
    // An unindexed flow has no display name, so the id is title-cased rather
    // than invented: "van_assisted_moving" -> "Van Assisted Moving".
    name: meta?.name ?? id.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()),
    subtitle: meta?.subtitle ?? null,
    description: meta?.description ?? '',
    icon: meta?.icon ?? null,
    color: meta?.color ?? null,
    group_id: meta ? groupIdFor(meta.category) : null,
    is_popular: meta?.isPopular ?? false,
    has_emergency: meta?.hasEmergency ?? false,
    flow_title: flow.title ?? '',
    flow_subtitle: flow.subtitle ?? null,
    categories,
    _counts: counts,
  })
}

console.log(`${rows.length} flows read from ${SOURCE}`)
console.log(`  ${rows.length - incomplete.length} with index metadata, ${incomplete.length} without`)
if (incomplete.length) console.log(`  no icon/colour/group: ${incomplete.join(', ')}`)
console.log(
  `  totals: ${rows.reduce((a, r) => a + r._counts.categories, 0)} categories, ` +
    `${rows.reduce((a, r) => a + r._counts.options, 0)} options`,
)

if (!apply) {
  console.log('\nDry run. Re-run with --apply to write.')
  process.exit(0)
}

// ---- upsert, preserving anything a person set in the panel -----------------
const { data: existingRows } = await db
  .from('services')
  .select('id, sort_order, is_active, thumbnail_url, thumbnail_path')
const existing = new Map((existingRows ?? []).map((r) => [r.id, r]))

let n = 0
for (const [i, row] of rows.entries()) {
  const { _counts, ...service } = row
  const prior = existing.get(row.id)
  const payload = {
    ...service,
    sort_order: prior?.sort_order ?? i + 1,
    is_active: prior?.is_active ?? true,
    ...(prior?.thumbnail_url ? { thumbnail_url: prior.thumbnail_url } : {}),
    ...(prior?.thumbnail_path ? { thumbnail_path: prior.thumbnail_path } : {}),
  }
  const { error } = await db.from('services').upsert(payload, { onConflict: 'id' })
  if (error) console.error(`  ${row.id}: ${error.message}`)
  else n++
}
console.log(`\nupserted ${n}/${rows.length} services`)

// ---- artwork ---------------------------------------------------------------
if (withImages) {
  if (!existsSync(IMAGES)) {
    console.log(`no image directory at ${IMAGES}, skipping artwork`)
  } else {
    const ids = new Set(rows.map((r) => r.id))
    const pics = readdirSync(IMAGES).filter((f) => /\.(jpe?g|png|webp)$/i.test(f))
    let uploaded = 0, skipped = []
    for (const pic of pics) {
      const id = basename(pic, extname(pic))
      // Only artwork whose filename matches a service id. The rest
      // (deep_clean, gutter, pressure_wash…) belong to services that no
      // longer exist, and guessing which one they meant would be worse than
      // leaving them out.
      if (!ids.has(id)) { skipped.push(pic); continue }
      const body = readFileSync(join(IMAGES, pic))
      const path = `${id}${extname(pic).toLowerCase()}`
      const { error } = await db.storage
        .from('service-thumbnails')
        .upload(path, body, { contentType: `image/${extname(pic).slice(1).replace('jpg', 'jpeg')}`, upsert: true })
      if (error) { console.error(`  ${pic}: ${error.message}`); continue }
      const { data } = db.storage.from('service-thumbnails').getPublicUrl(path)
      await db.from('services').update({ thumbnail_url: data.publicUrl, thumbnail_path: path }).eq('id', id)
      uploaded++
    }
    console.log(`uploaded ${uploaded} thumbnails`)
    if (skipped.length) console.log(`  no matching service, left alone: ${skipped.join(', ')}`)
  }
}
