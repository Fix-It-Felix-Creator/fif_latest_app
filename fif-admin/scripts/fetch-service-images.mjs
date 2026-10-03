#!/usr/bin/env node
/**
 * Gives every service a photograph, from Pexels.
 *
 * Writes to two places, because two things read service artwork today:
 *   - fixitfelix/assets/images/services/<id>.jpg — what the customer app
 *     bundles and shows now.
 *   - the `service-thumbnails` bucket, and services.thumbnail_url — what the
 *     admin panel shows, and what the apps will read once they stop bundling.
 *
 * The API key comes from PEXELS_API_KEY. It is never written to disk: a stock
 * photo key is low-value but it is still a credential, and a script with one
 * baked in gets committed eventually.
 *
 *   PEXELS_API_KEY=... node scripts/fetch-service-images.mjs           # dry run
 *   PEXELS_API_KEY=... node scripts/fetch-service-images.mjs --apply
 *   ... --apply --only plumber,roofer        # just these
 *   ... --apply --missing                    # only services with no image
 */

import { writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { createClient } from '@supabase/supabase-js'

const KEY = process.env.PEXELS_API_KEY
if (!KEY) {
  console.error('Set PEXELS_API_KEY. It is read from the environment, never from a file.')
  process.exit(1)
}

const ASSETS =
  process.env.FIF_APP_IMAGES_DIR ??
  '../fixitfelix/assets/images/services'

const apply = process.argv.includes('--apply')
const missingOnly = process.argv.includes('--missing')
const onlyArg = process.argv.find((a) => a.startsWith('--only='))
const only = onlyArg ? new Set(onlyArg.slice('--only='.length).split(',')) : null

const url = process.env.NEXT_PUBLIC_SUPABASE_URL
const key = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!url || !key) {
  console.error('Also source fif-admin/.env.local for the Supabase credentials.')
  process.exit(1)
}
const db = createClient(url, key, { auth: { persistSession: false } })

/**
 * Search terms that need help.
 *
 * Most service names are already good queries — "plumber" returns plumbers.
 * These are the ones where the name alone returns the wrong thing: an
 * abbreviation, a word with a commoner non-trade meaning, or a job title that
 * stock libraries do not tag.
 */
const QUERIES = {
  mot: 'car inspection garage',
  other: 'handyman tools workbench',
  labourer: 'construction worker site',
  builder: 'construction builder bricklaying',
  glazier: 'window installation glass',
  scaffolder: 'scaffolding construction',
  welder: 'welding sparks metal',
  plasterer: 'plastering wall trowel',
  tiler: 'tiling floor tiles',
  roofer: 'roof repair roofing',
  gardener: 'gardening garden work',
  landscaper: 'landscaping garden design',
  tree_surgeon: 'tree surgery chainsaw',
  central_heating: 'radiator heating system',
  boiler_repair: 'boiler repair engineer',
  gas_engineer: 'gas engineer boiler',
  hvac_technician: 'air conditioning technician',
  kitchen_fitter: 'kitchen installation fitting',
  locksmith: 'locksmith door lock',
  mechanic: 'car mechanic garage',
  cleaner: 'house cleaning',
  hairdresser: 'hairdresser salon',
  carpenter: 'carpenter woodworking',
  handyman: 'handyman home repair',
  painter: 'painter decorating wall',
  electrician: 'electrician wiring',
  plumber: 'plumber pipes',
  car_service: 'car service garage',
  tyres_brakes: 'car tyre change',
  tv_mounting: 'tv wall mounting',
  furniture_assembly: 'furniture assembly flatpack',
  general_mounting: 'drill wall mounting shelf',
  heavy_lifting: 'moving heavy boxes',
  help_moving: 'house moving boxes',
  van_assisted_moving: 'moving van loading',
  minor_home_repairs: 'home repair tools',
}

async function findPhoto(id, name) {
  const query = QUERIES[id] ?? name
  const res = await fetch(
    `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`,
    { headers: { Authorization: KEY } },
  )
  if (!res.ok) return { query, error: `Pexels answered ${res.status}` }
  const data = await res.json()
  const photo = data.photos?.[0]
  if (!photo) return { query, error: 'no results' }
  return {
    query,
    // Square, cropped by Pexels rather than by the app.
    //
    // The named sizes are all landscape, and both apps draw a service in a
    // square box — so a 940x650 asset had its top and bottom thrown away on
    // every render, and nobody choosing the photo ever saw which part
    // survived. 800 square is plenty at 3x and well under the 1MB ceiling.
    src: `${photo.src.original}?auto=compress&cs=tinysrgb&w=800&h=800&fit=crop`,
    credit: photo.photographer,
    link: photo.url,
  }
}

const { data: services, error } = await db
  .from('services')
  .select('id, name, thumbnail_url, thumbnail_path')
  .order('sort_order')
if (error) {
  console.error(`Could not read services: ${error.message}`)
  process.exit(1)
}

let targets = services
if (only) targets = targets.filter((s) => only.has(s.id))
if (missingOnly) targets = targets.filter((s) => !s.thumbnail_url)

console.log(`${targets.length} of ${services.length} services targeted`)
if (!apply) console.log('Dry run — nothing downloaded or written.\n')

mkdirSync(ASSETS, { recursive: true })

let ok = 0
const failures = []
for (const service of targets) {
  const found = await findPhoto(service.id, service.name)
  if (found.error) {
    failures.push(`${service.id}: ${found.error} (query "${found.query}")`)
    console.log(`  ${service.id.padEnd(22)} ✗ ${found.error}`)
    continue
  }

  console.log(`  ${service.id.padEnd(22)} "${found.query}" — ${found.credit}`)
  if (!apply) { ok++; continue }

  const img = await fetch(found.src)
  if (!img.ok) {
    failures.push(`${service.id}: download ${img.status}`)
    continue
  }
  const bytes = Buffer.from(await img.arrayBuffer())

  writeFileSync(join(ASSETS, `${service.id}.jpg`), bytes)

  const path = `${service.id}-${Date.now()}.jpg`
  const { error: upErr } = await db.storage
    .from('service-thumbnails')
    .upload(path, bytes, { contentType: 'image/jpeg', upsert: true })
  if (upErr) {
    failures.push(`${service.id}: upload ${upErr.message}`)
    continue
  }
  const { data: pub } = db.storage.from('service-thumbnails').getPublicUrl(path)
  await db
    .from('services')
    .update({ thumbnail_url: pub.publicUrl, thumbnail_path: path })
    .eq('id', service.id)

  // Replace, do not accumulate: the old object is only removed once the row
  // points at the new one.
  if (service.thumbnail_path && service.thumbnail_path !== path) {
    await db.storage.from('service-thumbnails').remove([service.thumbnail_path])
  }
  ok++
}

console.log(`\n${ok}/${targets.length} ${apply ? 'written' : 'resolved'}`)
if (failures.length) {
  console.log('failed:')
  failures.forEach((f) => console.log(`  ${f}`))
}
if (apply) {
  console.log('\nPhotos from Pexels (pexels.com) — free to use, no attribution required.')
}
