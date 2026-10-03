import 'server-only'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * Every cross-user read in the panel.
 *
 * Kept in one file for one reason: these all run as the service role, past the
 * `auth.uid() = owner_id` policy on every table. Having a single place where
 * that happens means the review question — what can the panel see? — has one
 * answer, and a page that wants a new table has to come here to get it rather
 * than reaching for the key itself.
 *
 * Callers must already have passed requireAdmin() / requirePermission().
 */

export const PAGE_SIZE = 50

/** The two account types that use the Pro app. */
export const TRADE_TYPES = ['tradesman', 'business'] as const

export type ProfileRow = {
  id: string
  email: string | null
  account_type: string
  account_status: string
  verification_status: string | null
  rejection_reason: string | null
  role: string | null
  first_name: string | null
  last_name: string | null
  phone: string | null
  profile_image_url: string | null
  date_of_birth: string | null
  bio: string | null
  introduction_bio: string | null
  currency: string
  work_status: string | null
  links: string[] | null
  trade: string[] | null
  address_line1: string | null
  address_line2: string | null
  city: string | null
  county: string | null
  postcode: string | null
  formatted_address: string | null
  latitude: number | null
  longitude: number | null
  last_address_updated_at: string | null
  company_name: string | null
  companies_house_number: string | null
  company_email: string | null
  company_landline: string | null
  company_website: string | null
  company_logo_url: string | null
  business_name: string | null
  business_email: string | null
  business_registration_id: string | null
  vat_registered: boolean
  vat_number: string | null
  bank_name: string | null
  bank_account_number: string | null
  bank_sort_code: string | null
  national_insurance_number: string | null
  document_type: string | null
  document_urls: string[] | null
  selfie_url: string | null
  subscription_plan_selected: string | null
  push_enabled: boolean
  email_enabled: boolean
  sms_enabled: boolean
  deletion_requested_at: string | null
  deletion_scheduled_at: string | null
  recovery_window_ends_at: string | null
  personal_data_retained_until: string | null
  password_migrated_at: string | null
  firebase_uid: string | null
  details: Record<string, unknown> | null
  created_at: string
  updated_at: string | null
}

/**
 * PostgREST's `or()` takes a comma-separated filter list, so a comma or a
 * paren typed into a search box is parsed as more filters rather than as text.
 * Replacing them with spaces is lossy and deliberately so — the alternative is
 * a search for "Smith, J" returning a 400.
 */
function safeSearch(value: string): string {
  return value.replace(/[,()]/g, ' ').trim()
}

// ============================================================
// People
// ============================================================

/**
 * One list query for both people pages.
 *
 * `types` is what separates them: the tradespeople page passes
 * ['tradesman','business'] and the customers page passes ['customer']. The
 * filter is not optional and has no "everyone" mode — a single list holding
 * both would be mostly empty columns, because a customer has no company, no
 * subscription and no verification file.
 */
export async function listProfiles(opts: {
  types: readonly string[]
  q?: string
  accountType?: string
  status?: string
  verification?: string
  page?: number
}): Promise<{ rows: ProfileRow[]; total: number }> {
  const db = supabaseAdmin()
  const page = Math.max(1, opts.page ?? 1)
  const from = (page - 1) * PAGE_SIZE

  let query = db.from('profiles').select('*', { count: 'exact' })

  // The requested type must still be one of the page's own types, so a
  // hand-edited ?type= cannot make the customers page list tradesmen.
  const types =
    opts.accountType && opts.types.includes(opts.accountType) ? [opts.accountType] : opts.types
  query = query.in('account_type', types as string[])

  if (opts.q) {
    const safe = safeSearch(opts.q)
    if (safe) {
      query = query.or(
        [
          `email.ilike.%${safe}%`,
          `first_name.ilike.%${safe}%`,
          `last_name.ilike.%${safe}%`,
          `phone.ilike.%${safe}%`,
          `postcode.ilike.%${safe}%`,
          `company_name.ilike.%${safe}%`,
          `business_name.ilike.%${safe}%`,
        ].join(','),
      )
    }
  }
  if (opts.status) query = query.eq('account_status', opts.status)
  if (opts.verification) query = query.eq('verification_status', opts.verification)

  const { data, count, error } = await query
    .order('created_at', { ascending: false })
    .range(from, from + PAGE_SIZE - 1)

  if (error) throw new Error(`Loading people failed: ${error.message}`)
  return { rows: (data ?? []) as ProfileRow[], total: count ?? 0 }
}

export async function getProfile(id: string): Promise<ProfileRow | null> {
  const { data, error } = await supabaseAdmin()
    .from('profiles')
    .select('*')
    .eq('id', id)
    .maybeSingle()
  if (error) throw new Error(`Loading the profile failed: ${error.message}`)
  return (data as ProfileRow | null) ?? null
}

/**
 * Names for a set of user ids, in one query.
 *
 * Every cross-user table stores only a uuid, and a ledger that says "8f3a…" in
 * every row is unreadable. This is the N+1 that would otherwise appear on
 * eight different pages.
 */
export async function namesFor(
  ids: Array<string | null | undefined>,
): Promise<Map<string, { name: string | null; email: string | null; account_type: string }>> {
  const unique = [...new Set(ids.filter((id): id is string => Boolean(id)))]
  if (!unique.length) return new Map()

  const { data } = await supabaseAdmin()
    .from('profiles')
    .select('id, first_name, last_name, company_name, email, account_type')
    .in('id', unique)

  return new Map(
    (data ?? []).map((r) => {
      const person = [r.first_name, r.last_name].filter(Boolean).join(' ').trim()
      return [
        r.id as string,
        {
          // A business trades under its company name; a sole trader under
          // their own. Preferring the person keeps the ledger consistent with
          // the profile page it links to.
          name: person || (r.company_name as string | null) || null,
          email: (r.email as string | null) ?? null,
          account_type: (r.account_type as string) ?? 'tradesman',
        },
      ]
    }),
  )
}

// ============================================================
// Per-owner reads, for the detail pages
// ============================================================

/** Every table the panel counts against one owner, and the column to count on. */
export const OWNER_TABLES: Array<[key: string, table: string, column: string]> = [
  ['jobs', 'jobs', 'owner_id'],
  ['quotes', 'quotes', 'owner_id'],
  ['invoices', 'invoices', 'owner_id'],
  ['clients', 'customers', 'owner_id'],
  ['staff', 'staff', 'owner_id'],
  ['pricing', 'pricing_items', 'owner_id'],
  ['terms', 'term_library', 'owner_id'],
  ['todos', 'todos', 'owner_id'],
  ['journal', 'journal_entries', 'owner_id'],
  ['tools', 'tool_assets', 'owner_id'],
  ['portfolio', 'portfolio_media', 'owner_id'],
  ['documents', 'extra_documents', 'owner_id'],
  ['qualifications', 'trade_qualifications', 'owner_id'],
  ['devices', 'user_devices', 'owner_id'],
  ['sessions', 'user_sessions', 'owner_id'],
  ['tokens', 'fcm_tokens', 'owner_id'],
  ['notifications', 'notifications', 'owner_id'],
  ['shares', 'document_shares', 'owner_id'],
  // The only entry that is not owner_id, and the only one that belongs to the
  // customer app. Always 0 on a tradesperson — which is the right answer, not
  // a wasted lookup.
  ['jobRequests', 'job_requests', 'customer_id'],
]

/**
 * The counts behind one person's tabs.
 *
 * One head request per table rather than fetching rows to count them: the tab
 * bar needs the number, and pulling two thousand notifications to show
 * "2,041" is the classic way an admin page gets slow.
 */
export async function ownerCounts(id: string): Promise<Record<string, number>> {
  const db = supabaseAdmin()
  const results = await Promise.all(
    OWNER_TABLES.map(([, table, column]) =>
      db.from(table).select('*', { count: 'exact', head: true }).eq(column, id),
    ),
  )
  const counts: Record<string, number> = {}
  OWNER_TABLES.forEach(([key], i) => {
    counts[key] = results[i].count ?? 0
  })
  return counts
}

/** Newest-first rows of one table for one owner. */
export async function ownerRows(
  table: string,
  ownerId: string,
  orderBy: string,
  limit = 200,
  /**
   * The column that points back at the person. Almost always `owner_id`, but
   * job_requests keys on `customer_id` — the homeowner does not "own" the
   * request the way a tradesperson owns a job, they are the one asking.
   */
  column = 'owner_id',
): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabaseAdmin()
    .from(table)
    .select('*')
    .eq(column, ownerId)
    .order(orderBy, { ascending: false })
    .limit(limit)
  if (error) throw new Error(`Loading ${table} failed: ${error.message}`)
  return (data ?? []) as Record<string, unknown>[]
}

/** A single owner-keyed row: subscription, usage, quote settings, trade card. */
export async function ownerSingle(
  table: string,
  ownerId: string,
): Promise<Record<string, unknown> | null> {
  const { data } = await supabaseAdmin()
    .from(table)
    .select('*')
    .eq('owner_id', ownerId)
    .maybeSingle()
  return (data as Record<string, unknown> | null) ?? null
}

// ============================================================
// Generic paged reads, for the ledger pages
// ============================================================

export async function listTable(opts: {
  table: string
  orderBy: string
  ascending?: boolean
  page?: number
  pageSize?: number
  filters?: Record<string, string | undefined>
  /** Columns an ilike search runs across. */
  searchColumns?: string[]
  q?: string
  select?: string
  /** Columns that must not be null, e.g. only shares that were responded to. */
  notNull?: string[]
}): Promise<{ rows: Record<string, unknown>[]; total: number }> {
  const db = supabaseAdmin()
  const size = opts.pageSize ?? PAGE_SIZE
  const page = Math.max(1, opts.page ?? 1)
  const from = (page - 1) * size

  let query = db.from(opts.table).select(opts.select ?? '*', { count: 'exact' })

  for (const [column, value] of Object.entries(opts.filters ?? {})) {
    if (value) query = query.eq(column, value)
  }
  for (const column of opts.notNull ?? []) {
    query = query.not(column, 'is', null)
  }
  if (opts.q && opts.searchColumns?.length) {
    const safe = safeSearch(opts.q)
    if (safe) {
      query = query.or(opts.searchColumns.map((c) => `${c}.ilike.%${safe}%`).join(','))
    }
  }

  const { data, count, error } = await query
    .order(opts.orderBy, { ascending: opts.ascending ?? false })
    .range(from, from + size - 1)

  if (error) throw new Error(`Loading ${opts.table} failed: ${error.message}`)
  // Double cast: a dynamic `select` string gives PostgREST no column list to
  // infer from, so it widens the row type to its error shape rather than to an
  // object. The runtime value is a row; the type is not worth fighting.
  return { rows: (data ?? []) as unknown as Record<string, unknown>[], total: count ?? 0 }
}

export async function countRows(
  table: string,
  filters?: Record<string, string | undefined>,
): Promise<number> {
  let query = supabaseAdmin().from(table).select('*', { count: 'exact', head: true })
  for (const [column, value] of Object.entries(filters ?? {})) {
    if (value) query = query.eq(column, value)
  }
  const { count } = await query
  return count ?? 0
}

/** Rows of one type created since a cut-off — the "last 7 days" numbers. */
export async function countSince(
  table: string,
  column: string,
  since: Date,
  filters?: Record<string, string | undefined>,
): Promise<number> {
  let query = supabaseAdmin()
    .from(table)
    .select('*', { count: 'exact', head: true })
    .gte(column, since.toISOString())
  for (const [k, v] of Object.entries(filters ?? {})) {
    if (v) query = query.eq(k, v)
  }
  const { count } = await query
  return count ?? 0
}

export async function countIn(
  table: string,
  column: string,
  values: readonly string[],
): Promise<number> {
  const { count } = await supabaseAdmin()
    .from(table)
    .select('*', { count: 'exact', head: true })
    .in(column, values as string[])
  return count ?? 0
}

/**
 * The values a column actually holds, for a filter dropdown.
 *
 * Capped at a thousand rows: a filter that offers every value in a million-row
 * table is a full scan on every page load, and the CHECK constraints behind
 * these columns mean the distinct set is tiny and shows up in the first page.
 */
export async function distinctValues(table: string, column: string): Promise<string[]> {
  const { data } = await supabaseAdmin().from(table).select(column).limit(1000)
  const values = new Set<string>()
  for (const row of data ?? []) {
    const v = (row as unknown as Record<string, unknown>)[column]
    if (typeof v === 'string' && v) values.add(v)
  }
  return [...values].sort()
}

// ============================================================
// Aggregates
// ============================================================

export type DashboardStats = {
  generated_at: string
  invoices: Record<string, { count: number; total: number }>
  quotes: Record<string, { count: number; total: number }>
  jobs: Record<string, number>
  subscriptions: Array<{
    status: string
    plan_type: string
    provider: string | null
    billing_cycle: string
    count: number
    price: number
  }>
  stale_subscriptions: number
  shares: Record<string, number>
  work_30d: { jobs: number; quotes: number; invoices: number; invoiced: number }
  expenses_total: number
  tracked_seconds: number
}

/**
 * The money, and the grouped breakdowns.
 *
 * Counts the panel gets from head requests; sums it cannot — PostgREST has no
 * SUM without an aggregate function, and summing in the panel means fetching
 * every invoice. So this is an RPC.
 *
 * It returns a reason instead of throwing when the function is not there,
 * because it ships in a migration the operator applies on their own schedule:
 * a dashboard that 500s until someone runs `supabase db push` is a worse
 * answer than one that renders every count and says which card is waiting.
 */
export async function dashboardStats(): Promise<
  { ok: true; stats: DashboardStats } | { ok: false; reason: string }
> {
  const { data, error } = await supabaseAdmin().rpc('admin_dashboard_stats')
  if (error) {
    const missing = /could not find the function|does not exist|schema cache/i.test(error.message)
    return {
      ok: false,
      reason: missing
        ? 'Migration 20260914090000_phase9_admin_panel.sql has not been applied to this project yet.'
        : error.message,
    }
  }
  return { ok: true, stats: data as DashboardStats }
}

// ============================================================
// Storage
// ============================================================

/**
 * A viewable link for something in a private bucket.
 *
 * Identity documents, trade cards and job photos live in `user-documents` and
 * `user-tools`, both private — an admin looking at a verification submission
 * needs to actually see the passport scan.
 *
 * Columns in this schema hold either a full URL (written back when the app
 * had a public bucket) or a storage path, and which one varies by row. Rather
 * than guess per column, anything that already looks like a URL is passed
 * through and everything else is signed.
 *
 * Short-lived on purpose: the URL bypasses RLS for anyone holding it, and an
 * hour is longer than any review takes.
 */
export async function viewableUrl(
  value: string | null | undefined,
  bucket: 'user-documents' | 'user-tools' = 'user-documents',
  expiresIn = 3600,
): Promise<string | null> {
  if (!value) return null
  if (/^https?:\/\//i.test(value)) return value
  const { data } = await supabaseAdmin().storage.from(bucket).createSignedUrl(value, expiresIn)
  return data?.signedUrl ?? null
}

export async function viewableUrls(
  values: Array<string | null | undefined>,
  bucket: 'user-documents' | 'user-tools' = 'user-documents',
): Promise<Array<{ source: string; url: string | null }>> {
  const list = values.filter((v): v is string => Boolean(v))
  return Promise.all(
    list.map(async (source) => ({ source, url: await viewableUrl(source, bucket) })),
  )
}

// ============================================================
// Joins the schema has no foreign key for
// ============================================================

export type SubscriptionRow = {
  owner_id: string
  status: string
  plan_type: string
  billing_cycle: string
  provider: string | null
  name: string | null
  price: number
  product_id: string | null
  original_transaction_id: string | null
  stripe_subscription_id: string | null
  stripe_customer_id: string | null
  auto_renew: boolean
  cancel_at_period_end: boolean
  current_period_start: string | null
  current_period_end: string | null
  metadata: Record<string, unknown> | null
  created_at: string
  updated_at: string | null
}

/**
 * The subscription for each person on a page of the list.
 *
 * `subscriptions` is keyed by owner_id with no row for anyone who never
 * subscribed, so this is a left join done in two queries rather than one — and
 * an absent entry is a real answer: never paid, as distinct from lapsed.
 */
export async function subscriptionsFor(
  ids: Array<string | null | undefined>,
): Promise<Map<string, SubscriptionRow>> {
  const unique = [...new Set(ids.filter((id): id is string => Boolean(id)))]
  if (!unique.length) return new Map()
  const { data } = await supabaseAdmin().from('subscriptions').select('*').in('owner_id', unique)
  return new Map((data ?? []).map((r) => [r.owner_id as string, r as SubscriptionRow]))
}

/** The app_config value for one key, or null if the key has never been set. */
export async function appConfig(key: string): Promise<Record<string, unknown> | null> {
  const { data } = await supabaseAdmin()
    .from('app_config')
    .select('value')
    .eq('key', key)
    .maybeSingle()
  return (data?.value as Record<string, unknown> | null) ?? null
}

/**
 * The plan limits a usage counter should be read against.
 *
 * Shaped `{ accountType: { planType: { limits: {...} } } }` under the
 * `subscriptions` app_config key — the old RTDB `config/subscriptions` node.
 * Returns null rather than a default when the key is missing: inventing a
 * limit would mean the panel reporting someone as over or under a number
 * nothing in the app enforces.
 */
export async function planLimits(
  accountType: string | null | undefined,
  planType: string | null | undefined,
): Promise<Record<string, unknown> | null> {
  if (!accountType || !planType) return null
  const config = await appConfig('subscriptions')
  const byType = config?.[accountType] as Record<string, unknown> | undefined
  const plan = byType?.[planType] as Record<string, unknown> | undefined
  return (plan?.limits as Record<string, unknown> | undefined) ?? null
}

/**
 * Accounts whose personal data was promised to be gone by now.
 *
 * A comparison against `now()` rather than an equality, so countRows() cannot
 * express it. Worth its own name because it is the one number in this panel
 * that describes a promise made to a user rather than a fact about the
 * business — and nothing in the codebase acts on it (see the spec's §5.10),
 * so this is the only place it is visible at all.
 */
export async function countPastRetention(): Promise<number> {
  const { count } = await supabaseAdmin()
    .from('profiles')
    .select('*', { count: 'exact', head: true })
    .not('personal_data_retained_until', 'is', null)
    .lt('personal_data_retained_until', new Date().toISOString())
  return count ?? 0
}
