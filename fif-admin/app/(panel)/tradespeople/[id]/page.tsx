import { notFound } from 'next/navigation'
import Link from 'next/link'
import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import {
  getProfile,
  ownerCounts,
  ownerRows,
  ownerSingle,
  planLimits,
  viewableUrl,
  viewableUrls,
  type ProfileRow,
  type SubscriptionRow,
} from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Tabs } from '@/components/tabs'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { KV } from '@/components/ui/kv'
import { Stat } from '@/components/ui/stat'
import { JsonView } from '@/components/ui/json-view'
import { ACCOUNT_TYPE_LABEL, Badge, accountTypeTone, statusTone } from '@/components/ui/badge'
import { RowTable } from '@/components/row-table'
import { ExternalLink } from '@/components/external-link'
import { AccountActions } from '@/app/(panel)/_components/account-actions'
import { VerificationActions } from '@/app/(panel)/_components/verification-actions'
import { DevicesTab, NotificationsTab } from '@/app/(panel)/_components/person-tabs'
import {
  fmtAgo,
  fmtBytes,
  fmtDate,
  fmtDateTime,
  fmtMoney,
  fmtNum,
  fullName,
  humanise,
  initials,
  shortAddress,
} from '@/lib/format'

export const dynamic = 'force-dynamic'

type Params = { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> }

export async function generateMetadata({ params }: Params) {
  const { id } = await params
  const profile = await getProfile(id)
  const name = profile ? (fullName(profile.first_name, profile.last_name) ?? profile.email) : null
  return { title: `${name ?? 'Tradesperson'} · Fix It Felix Admin` }
}

export default async function TradespersonPage({ params, searchParams }: Params) {
  const admin = await requirePermission('viewTradespeople')
  const { id } = await params
  const { tab = 'overview' } = await searchParams

  const profile = await getProfile(id)
  if (!profile) notFound()
  // A customer id reaching this route would render a page of empty business
  // sections. Sending it to the page built for it is the honest answer.
  if (profile.account_type === 'customer') {
    const { redirect } = await import('next/navigation')
    redirect(`/customers/${id}`)
  }

  const counts = await ownerCounts(id)
  const name = fullName(profile.first_name, profile.last_name)
  const trading = profile.company_name || profile.business_name
  const finance = can(admin.role, 'readFinance')
  const work = can(admin.role, 'viewWork')

  const tabs = [
    { key: 'overview', label: 'Overview' },
    { key: 'verification', label: 'Verification' },
    ...(finance ? [{ key: 'billing', label: 'Billing' }] : []),
    ...(work
      ? [
          { key: 'jobs', label: 'Jobs', count: counts.jobs },
          { key: 'quotes', label: 'Quotes', count: counts.quotes },
          { key: 'invoices', label: 'Invoices', count: counts.invoices },
          { key: 'clients', label: 'Clients', count: counts.clients },
          { key: 'team', label: 'Team', count: counts.staff },
          { key: 'catalogue', label: 'Catalogue', count: counts.pricing + counts.terms },
          { key: 'workspace', label: 'Workspace', count: counts.todos + counts.journal + counts.tools },
          { key: 'portfolio', label: 'Portfolio', count: counts.portfolio + counts.documents },
          { key: 'shares', label: 'Share links', count: counts.shares },
        ]
      : []),
    ...(can(admin.role, 'viewDevices')
      ? [{ key: 'devices', label: 'Devices', count: counts.devices }]
      : []),
    { key: 'notifications', label: 'Notifications', count: counts.notifications },
    { key: 'raw', label: 'Raw row' },
  ]

  return (
    <>
      <PageHeader
        title={name ?? trading ?? 'Unnamed account'}
        subtitle={
          <span className="flex flex-wrap items-center gap-1.5">
            <Badge tone={accountTypeTone(profile.account_type)}>
              {ACCOUNT_TYPE_LABEL[profile.account_type] ?? humanise(profile.account_type)}
            </Badge>
            <Badge tone={statusTone(profile.account_status)}>
              {humanise(profile.account_status)}
            </Badge>
            {profile.verification_status ? (
              <Badge tone={statusTone(profile.verification_status)}>
                {humanise(profile.verification_status)}
              </Badge>
            ) : (
              <Badge tone="muted">Never submitted</Badge>
            )}
            {trading && name ? <span className="text-muted-foreground">{trading}</span> : null}
            <span className="tabular text-muted-foreground">Joined {fmtDate(profile.created_at)}</span>
          </span>
        }
        actions={
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-semibold">
            {initials(name ?? trading, profile.email)}
          </div>
        }
      />

      <Tabs tabs={tabs} current={tab} basePath={`/tradespeople/${id}`} />

      {tab === 'overview' ? <Overview profile={profile} counts={counts} canAct={can(admin.role, 'manageAccount')} pii={can(admin.role, 'readPii')} /> : null}
      {tab === 'verification' ? <Verification profile={profile} canReview={can(admin.role, 'reviewVerification')} /> : null}
      {tab === 'billing' && finance ? <Billing profile={profile} /> : null}
      {tab === 'jobs' && work ? <Jobs ownerId={id} /> : null}
      {tab === 'quotes' && work ? <Documents ownerId={id} table="quotes" /> : null}
      {tab === 'invoices' && work ? <Documents ownerId={id} table="invoices" /> : null}
      {tab === 'clients' && work ? <Clients ownerId={id} /> : null}
      {tab === 'team' && work ? <Team ownerId={id} /> : null}
      {tab === 'catalogue' && work ? <Catalogue ownerId={id} /> : null}
      {tab === 'workspace' && work ? <Workspace ownerId={id} /> : null}
      {tab === 'portfolio' && work ? <Portfolio ownerId={id} /> : null}
      {tab === 'shares' && work ? <Shares ownerId={id} /> : null}
      {tab === 'devices' ? <DevicesTab ownerId={id} /> : null}
      {tab === 'notifications' ? <NotificationsTab ownerId={id} /> : null}
      {tab === 'raw' ? <Raw profile={profile} /> : null}
    </>
  )
}

// ============================================================
// Overview
// ============================================================

function Overview({
  profile,
  counts,
  canAct,
  pii,
}: {
  profile: ProfileRow
  counts: Record<string, number>
  canAct: boolean
  pii: boolean
}) {
  return (
    <div className="space-y-2">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 xl:grid-cols-8">
        <Stat label="Jobs" value={fmtNum(counts.jobs)} />
        <Stat label="Quotes" value={fmtNum(counts.quotes)} />
        <Stat label="Invoices" value={fmtNum(counts.invoices)} />
        <Stat label="Clients" value={fmtNum(counts.clients)} />
        <Stat label="Team" value={fmtNum(counts.staff)} />
        <Stat label="Catalogue" value={fmtNum(counts.pricing)} hint={`${fmtNum(counts.terms)} terms`} />
        <Stat label="Devices" value={fmtNum(counts.devices)} hint={`${fmtNum(counts.tokens)} push tokens`} />
        <Stat label="Notifications" value={fmtNum(counts.notifications)} />
      </div>

      <div className="grid gap-2 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Person</CardTitle>
          </CardHeader>
          <CardBody>
            <KV
              items={[
                { label: 'First name', value: profile.first_name },
                { label: 'Last name', value: profile.last_name },
                { label: 'Email', value: pii ? profile.email : 'Hidden by your role' },
                { label: 'Phone', value: pii ? profile.phone : 'Hidden by your role' },
                { label: 'Date of birth', value: pii ? fmtDate(profile.date_of_birth) : '—' },
                { label: 'Business role', value: humanise(profile.role) },
                { label: 'Work status', value: humanise(profile.work_status) },
                { label: 'Trades', value: humanise(profile.trade) },
                { label: 'Currency', value: profile.currency },
                { label: 'Firebase uid', value: profile.firebase_uid ?? '—' },
                {
                  label: 'Password migrated',
                  // Set by the Firebase→Supabase move. Null on an account that
                  // signed up after it, which is a different thing from one
                  // that never completed it.
                  value: profile.password_migrated_at ? fmtDate(profile.password_migrated_at) : '—',
                },
                { label: 'Last updated', value: fmtAgo(profile.updated_at) },
              ]}
            />
            {profile.bio || profile.introduction_bio ? (
              <p className="mt-2 border-t border-border/60 pt-2 text-[11px] leading-relaxed text-muted-foreground">
                {profile.introduction_bio || profile.bio}
              </p>
            ) : null}
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Business</CardTitle>
          </CardHeader>
          <CardBody>
            <KV
              items={[
                { label: 'Company name', value: profile.company_name },
                { label: 'Business name', value: profile.business_name },
                { label: 'Companies House', value: profile.companies_house_number },
                { label: 'Registration id', value: profile.business_registration_id },
                { label: 'Company email', value: profile.company_email ?? profile.business_email },
                { label: 'Landline', value: profile.company_landline },
                {
                  label: 'Website',
                  value: profile.company_website ? (
                    <ExternalLink href={profile.company_website} variant="inline">
                      {profile.company_website.replace(/^https?:\/\//, '')}
                    </ExternalLink>
                  ) : null,
                },
                { label: 'VAT registered', value: profile.vat_registered ? 'Yes' : 'No' },
                { label: 'VAT number', value: profile.vat_number },
                {
                  label: 'Bank',
                  value: pii ? profile.bank_name : 'Hidden by your role',
                },
                {
                  label: 'Sort code',
                  value: pii ? profile.bank_sort_code : '—',
                },
                {
                  label: 'Account number',
                  // Shown in full rather than masked. A support call about a
                  // missing payment is answered by reading the number back,
                  // and a mask that hides the digit someone typed wrong makes
                  // this page useless for the one job it has here.
                  value: pii ? profile.bank_account_number : '—',
                },
              ]}
            />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Address</CardTitle>
            {profile.latitude && profile.longitude ? (
              <ExternalLink
                href={`https://www.google.com/maps/search/?api=1&query=${profile.latitude},${profile.longitude}`}
                variant="inline"
                className="text-[10px]"
              >
                Map
              </ExternalLink>
            ) : null}
          </CardHeader>
          <CardBody>
            <KV
              items={[
                { label: 'Line 1', value: profile.address_line1 },
                { label: 'Line 2', value: profile.address_line2 },
                { label: 'City', value: profile.city },
                { label: 'County', value: profile.county },
                { label: 'Postcode', value: profile.postcode },
                { label: 'Latitude', value: profile.latitude },
                { label: 'Longitude', value: profile.longitude },
                { label: 'Last changed', value: fmtAgo(profile.last_address_updated_at) },
              ]}
            />
            <p className="mt-2 text-[11px] text-muted-foreground">{shortAddress(profile)}</p>
          </CardBody>
        </Card>

        <div className="space-y-2">
          <Card>
            <CardHeader>
              <CardTitle>Account</CardTitle>
            </CardHeader>
            <CardBody>
              <KV
                items={[
                  { label: 'Status', value: humanise(profile.account_status) },
                  { label: 'Verification', value: humanise(profile.verification_status) },
                  { label: 'Rejection reason', value: profile.rejection_reason },
                  { label: 'Push', value: profile.push_enabled ? 'On' : 'Off' },
                  { label: 'Email', value: profile.email_enabled ? 'On' : 'Off' },
                  { label: 'SMS', value: profile.sms_enabled ? 'On' : 'Off' },
                  { label: 'Deletion requested', value: fmtDate(profile.deletion_requested_at) },
                  { label: 'Recovery ends', value: fmtDate(profile.recovery_window_ends_at) },
                  {
                    label: 'Data retained until',
                    value: fmtDate(profile.personal_data_retained_until),
                  },
                  { label: 'Plan chosen at signup', value: humanise(profile.subscription_plan_selected) },
                ]}
              />
            </CardBody>
          </Card>

          {canAct ? (
            <AccountActions
              userId={profile.id}
              email={profile.email}
              accountStatus={profile.account_status}
              recoveryEndsAt={profile.recovery_window_ends_at}
            />
          ) : null}
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Verification
// ============================================================

async function Verification({
  profile,
  canReview,
}: {
  profile: ProfileRow
  canReview: boolean
}) {
  const [card, qualifications, documents, selfie] = await Promise.all([
    ownerSingle('trade_cards', profile.id),
    ownerRows('trade_qualifications', profile.id, 'uploaded_at', 100),
    viewableUrls(profile.document_urls ?? []),
    viewableUrl(profile.selfie_url),
  ])

  const cardImage = card ? await viewableUrl(card.image_url as string | null) : null

  return (
    <div className="space-y-2">
      <div className="grid gap-2 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Identity submission</CardTitle>
            <Badge tone={statusTone(profile.verification_status)}>
              {profile.verification_status ? humanise(profile.verification_status) : 'Not submitted'}
            </Badge>
          </CardHeader>
          <CardBody>
            <KV
              items={[
                { label: 'Document type', value: humanise(profile.document_type) },
                { label: 'National Insurance', value: profile.national_insurance_number },
                { label: 'Documents uploaded', value: fmtNum(profile.document_urls?.length ?? 0) },
                { label: 'Selfie', value: profile.selfie_url ? 'Uploaded' : 'Missing' },
                { label: 'Rejection reason', value: profile.rejection_reason },
              ]}
            />

            {/* Links, not inline images. Both buckets are private, so these are
                one-hour signed URLs — and a page that embedded a dozen of them
                would be handing out a dozen live credentials on every render
                whether anyone looked or not. */}
            <div className="mt-2 flex flex-wrap gap-1.5 border-t border-border/60 pt-2">
              {documents.map((doc, i) =>
                doc.url ? (
                  <ExternalLink key={doc.source} href={doc.url}>
                    Document {i + 1}
                  </ExternalLink>
                ) : (
                  <span
                    key={doc.source}
                    className="inline-flex h-8 items-center rounded-md border border-destructive/40 px-3 text-xs text-destructive"
                  >
                    Document {i + 1} is missing from storage
                  </span>
                ),
              )}
              {selfie ? <ExternalLink href={selfie}>Selfie</ExternalLink> : null}
              {!documents.length && !selfie ? (
                <p className="text-xs text-muted-foreground">Nothing uploaded.</p>
              ) : null}
            </div>
            <p className="mt-1.5 text-[10px] text-muted-foreground">
              Links are signed for one hour and open in a new tab.
            </p>
          </CardBody>
        </Card>

        {canReview ? (
          <Card>
            <CardHeader>
              <CardTitle>Decision</CardTitle>
            </CardHeader>
            <CardBody>
              <VerificationActions userId={profile.id} current={profile.verification_status} />
            </CardBody>
          </Card>
        ) : null}
      </div>

      <div className="grid gap-2 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Trade card</CardTitle>
            {cardImage ? (
              <ExternalLink href={cardImage} variant="inline" className="text-[10px]">
                Open
              </ExternalLink>
            ) : null}
          </CardHeader>
          <CardBody>
            {card ? (
              <KV
                items={[
                  { label: 'Scheme', value: humanise(card.card_scheme) },
                  { label: 'Colour', value: humanise(card.card_color) },
                  { label: 'Level', value: humanise(card.qualification_level) },
                  { label: 'Registration', value: (card.registration_number as string) ?? null },
                  { label: 'Mapped trade', value: humanise(card.mapped_trade) },
                  { label: 'Expires', value: fmtDate(card.expiry_date as string) },
                  { label: 'Status', value: humanise(card.verification_status) },
                  { label: 'Rejection reason', value: (card.rejection_reason as string) ?? null },
                  { label: 'Size', value: fmtBytes(card.file_size as number) },
                  { label: 'Uploaded', value: fmtAgo(card.uploaded_at as string) },
                ]}
              />
            ) : (
              <p className="text-xs text-muted-foreground">No trade card uploaded.</p>
            )}
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Qualifications</CardTitle>
            <span className="tabular text-[10px] text-muted-foreground">
              {fmtNum(qualifications.length)}
            </span>
          </CardHeader>
          <CardBody className="px-0 pb-0">
            <RowTable
              rows={qualifications}
              empty="No qualification documents."
              columns={[
                { key: 'name', label: 'Name' },
                { key: 'issuing_body', label: 'Issued by' },
                { key: 'requirement_id', label: 'Requirement' },
                { key: 'is_mandatory', label: 'Mandatory' },
                { key: 'expiry_date', label: 'Expires', render: (v) => fmtDate(v as string) },
                { key: 'verification_status', label: 'Status', badge: true },
                { key: 'uploaded_at', label: 'Uploaded', align: 'right', render: (v) => fmtAgo(v as string) },
              ]}
            />
          </CardBody>
        </Card>
      </div>
    </div>
  )
}

// ============================================================
// Billing
// ============================================================

async function Billing({ profile }: { profile: ProfileRow }) {
  const [sub, usage, settings] = await Promise.all([
    ownerSingle('subscriptions', profile.id),
    ownerSingle('usage_counters', profile.id),
    ownerSingle('quote_settings', profile.id),
  ])
  const subscription = sub as SubscriptionRow | null
  const limits = await planLimits(profile.account_type, subscription?.plan_type)

  const stale =
    subscription?.status === 'active' &&
    subscription.current_period_end != null &&
    new Date(subscription.current_period_end) < new Date()

  // Every counter the app tracks, paired with its limit where the config has
  // one. Built from the usage row rather than a hardcoded list so a counter
  // added by a migration shows up here without an edit.
  const counterRows = usage
    ? Object.entries(usage)
        .filter(
          ([k]) =>
            !['owner_id', 'created_at', 'updated_at', 'period_start', 'reset_at'].includes(k),
        )
        .map(([key, used]) => ({
          key,
          counter: humanise(key),
          used: Number(used ?? 0),
          limit: limits ? (limits[toCamel(key)] ?? limits[key] ?? null) : null,
        }))
    : []

  return (
    <div className="space-y-2">
      {stale ? (
        <p
          role="alert"
          className="rounded-lg border border-destructive/40 bg-destructive/10 px-3 py-2 text-[11px] text-destructive"
        >
          This subscription says active but its period ended {fmtAgo(subscription!.current_period_end)}.
          That is a renewal or a webhook that did not land, not a paying customer.
        </p>
      ) : null}

      <div className="grid gap-2 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Subscription</CardTitle>
            {subscription ? (
              <Badge tone={statusTone(subscription.status)}>{humanise(subscription.status)}</Badge>
            ) : null}
          </CardHeader>
          <CardBody>
            {subscription ? (
              <>
                <KV
                  items={[
                    { label: 'Plan', value: humanise(subscription.plan_type) },
                    { label: 'Name', value: subscription.name },
                    { label: 'Billing cycle', value: humanise(subscription.billing_cycle) },
                    { label: 'Provider', value: humanise(subscription.provider) },
                    { label: 'Price', value: fmtMoney(subscription.price, profile.currency) },
                    { label: 'Auto renew', value: subscription.auto_renew ? 'Yes' : 'No' },
                    {
                      label: 'Cancels at period end',
                      value: subscription.cancel_at_period_end ? 'Yes' : 'No',
                    },
                    { label: 'Period start', value: fmtDate(subscription.current_period_start) },
                    { label: 'Period end', value: fmtDate(subscription.current_period_end) },
                    { label: 'Product id', value: subscription.product_id },
                    {
                      label: 'Apple transaction',
                      value: subscription.original_transaction_id,
                    },
                    { label: 'Stripe subscription', value: subscription.stripe_subscription_id },
                    { label: 'Started', value: fmtDate(subscription.created_at) },
                  ]}
                />
                {/* Billing moved to native in-app purchase, so there is no
                    server-side cancel or refund to offer — those exist only in
                    the stores. Saying so beats a disabled button. */}
                <p className="mt-2 border-t border-border/60 pt-2 text-[11px] leading-relaxed text-muted-foreground">
                  Cancellations and refunds happen in App Store Connect or Play Console, not here —
                  the store owns the entitlement.
                </p>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <ExternalLink
                    href={process.env.NEXT_PUBLIC_APP_STORE_CONNECT_URL ?? 'https://appstoreconnect.apple.com/apps'}
                  >
                    App Store Connect
                  </ExternalLink>
                  <ExternalLink
                    href={process.env.NEXT_PUBLIC_PLAY_CONSOLE_URL ?? 'https://play.google.com/console'}
                  >
                    Play Console
                  </ExternalLink>
                </div>
              </>
            ) : (
              <p className="text-xs text-muted-foreground">
                No subscription row. This account has never subscribed — not even a trial.
              </p>
            )}
          </CardBody>
        </Card>

        <div className="space-y-2">
          <Card>
            <CardHeader>
              <CardTitle>Plan usage</CardTitle>
              <span className="text-[10px] text-muted-foreground">
                {usage?.reset_at ? `Reset ${fmtAgo(usage.reset_at as string)}` : 'Never reset'}
              </span>
            </CardHeader>
            <CardBody className="px-0 pb-0">
              <RowTable
                rows={counterRows}
                empty="No usage row — nothing has been counted for this account."
                hideKeys={['key']}
                columns={[
                  { key: 'counter', label: 'Counter' },
                  { key: 'used', label: 'Used', align: 'right' },
                  {
                    key: 'limit',
                    label: 'Limit',
                    align: 'right',
                    render: (v) =>
                      v === null || v === undefined ? (
                        <span className="text-muted-foreground">—</span>
                      ) : (
                        fmtNum(Number(v))
                      ),
                  },
                ]}
              />
              {!limits ? (
                <p className="px-3 py-2 text-[10px] leading-relaxed text-muted-foreground">
                  No limits in the `subscriptions` app_config key for{' '}
                  {humanise(profile.account_type)} · {humanise(subscription?.plan_type)}, so the
                  limit column is blank rather than guessed — a number here that the app does not
                  enforce would answer &ldquo;why am I blocked&rdquo; wrongly.
                </p>
              ) : null}
            </CardBody>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Numbering</CardTitle>
            </CardHeader>
            <CardBody>
              {settings ? (
                <KV
                  items={[
                    { label: 'Auto-generate', value: settings.auto_generate_number ? 'Yes' : 'No' },
                    { label: 'Prefix', value: (settings.prefix as string) || '—' },
                    { label: 'Next quote', value: fmtNum(settings.next_quote_number as number) },
                    { label: 'Next invoice', value: fmtNum(settings.next_invoice_number as number) },
                  ]}
                />
              ) : (
                <p className="text-xs text-muted-foreground">Using the defaults.</p>
              )}
            </CardBody>
          </Card>
        </div>
      </div>
    </div>
  )
}

/** `photo_upload_count` → `photoUploadCount`, which is how the config keys it. */
function toCamel(value: string): string {
  return value.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase())
}

// ============================================================
// Work tabs
// ============================================================

async function Jobs({ ownerId }: { ownerId: string }) {
  const rows = await ownerRows('jobs', ownerId, 'created_at')
  return (
    <RowTable
      rows={rows}
      empty="No jobs."
      expandKey="customer_snapshot"
      columns={[
        {
          key: 'reference',
          label: 'Reference',
          render: (v, row) => (
            <Link href={`/jobs?q=${v}`} className="font-medium hover:text-primary hover:underline">
              {(v as string) || (row.title as string) || '—'}
            </Link>
          ),
        },
        { key: 'title', label: 'Title' },
        { key: 'status', label: 'Status', badge: true },
        { key: 'start_date', label: 'Starts', render: (v) => fmtDate(v as string) },
        {
          key: 'clock_in_at',
          label: 'Clocked in',
          render: (v) =>
            v ? <Badge tone="info">Running · {fmtAgo(v as string)}</Badge> : <span className="text-muted-foreground">—</span>,
        },
        { key: 'created_at', label: 'Created', align: 'right', render: (v) => fmtDate(v as string) },
        { key: 'updated_at', label: 'Changed', align: 'right', render: (v) => fmtAgo(v as string) },
      ]}
    />
  )
}

async function Documents({ ownerId, table }: { ownerId: string; table: 'quotes' | 'invoices' }) {
  const rows = await ownerRows(table, ownerId, 'created_at')
  const isInvoice = table === 'invoices'

  return (
    <RowTable
      rows={rows}
      empty={isInvoice ? 'No invoices.' : 'No quotes.'}
      expandKey="customer_snapshot"
      columns={[
        { key: 'reference', label: 'Reference' },
        { key: 'title', label: 'Title' },
        { key: 'status', label: 'Status', badge: true },
        {
          key: 'total',
          label: 'Total',
          align: 'right',
          render: (v) => fmtMoney(v as number),
        },
        {
          key: isInvoice ? 'invoice_date' : 'quote_date',
          label: 'Dated',
          render: (v) => fmtDate(v as string),
        },
        {
          key: isInvoice ? 'due_date' : 'expiry',
          label: isInvoice ? 'Due' : 'Expiry',
          render: (v) => (isInvoice ? fmtDate(v as string) : humanise(v)),
        },
        { key: 'sent_at', label: 'Sent', render: (v) => fmtAgo(v as string) },
        { key: 'viewed_at', label: 'Viewed', render: (v) => fmtAgo(v as string) },
        {
          key: isInvoice ? 'paid_at' : 'responded_at',
          label: isInvoice ? 'Paid' : 'Answered',
          render: (v) => fmtAgo(v as string),
        },
        {
          key: 'share_token',
          label: 'Link',
          align: 'right',
          render: (v) =>
            v ? (
              <Badge tone="muted" title={v as string}>
                Shared
              </Badge>
            ) : (
              <span className="text-muted-foreground">—</span>
            ),
        },
      ]}
    />
  )
}

async function Clients({ ownerId }: { ownerId: string }) {
  const rows = await ownerRows('customers', ownerId, 'created_at')
  return (
    <>
      <p className="mb-2 text-[11px] text-muted-foreground">
        This tradesperson&apos;s own address book. These are not customer-app accounts — they are
        contacts typed in or imported from a phone, and nobody signs in as one.
      </p>
      <RowTable
        rows={rows}
        empty="No clients saved."
        columns={[
          { key: 'name', label: 'Name' },
          { key: 'company', label: 'Company' },
          { key: 'email', label: 'Email' },
          { key: 'phone', label: 'Phone' },
          {
            key: 'formatted_address',
            label: 'Address',
            render: (_v, row) => shortAddress(row as Record<string, string | null>),
          },
          { key: 'created_at', label: 'Added', align: 'right', render: (v) => fmtDate(v as string) },
        ]}
      />
    </>
  )
}

async function Team({ ownerId }: { ownerId: string }) {
  const rows = await ownerRows('staff', ownerId, 'created_at')
  return (
    <RowTable
      rows={rows}
      empty="Nobody on the team."
      columns={[
        { key: 'name', label: 'Name' },
        { key: 'email', label: 'Email' },
        { key: 'phone', label: 'Phone' },
        { key: 'default_pay_type', label: 'Paid by', render: (v) => humanise(v) },
        { key: 'rate', label: 'Standard', align: 'right', render: (v) => fmtMoney(v as number) },
        { key: 'weekend_rate', label: 'Weekend', align: 'right', render: (v) => fmtMoney(v as number) },
        { key: 'emergency_rate', label: 'Emergency', align: 'right', render: (v) => fmtMoney(v as number) },
        { key: 'sociable_rate', label: 'Sociable', align: 'right', render: (v) => fmtMoney(v as number) },
      ]}
    />
  )
}

async function Catalogue({ ownerId }: { ownerId: string }) {
  const [pricing, terms] = await Promise.all([
    ownerRows('pricing_items', ownerId, 'created_at'),
    ownerRows('term_library', ownerId, 'created_at'),
  ])
  return (
    <div className="grid gap-2 lg:grid-cols-2">
      <Card>
        <CardHeader>
          <CardTitle>Services and materials</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{fmtNum(pricing.length)}</span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={pricing}
            empty="Nothing priced up."
            columns={[
              { key: 'name', label: 'Item' },
              { key: 'kind', label: 'Kind', badge: true },
              { key: 'item_code', label: 'Code' },
              { key: 'unit_cost', label: 'Cost', align: 'right', render: (v) => fmtMoney(v as number) },
              { key: 'unit_markup', label: 'Markup', align: 'right', render: (v) => fmtMoney(v as number) },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Terms library</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{fmtNum(terms.length)}</span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={terms}
            empty="No saved terms."
            columns={[
              { key: 'name', label: 'Name' },
              { key: 'details', label: 'Details' },
              { key: 'created_at', label: 'Added', align: 'right', render: (v) => fmtDate(v as string) },
            ]}
          />
        </CardBody>
      </Card>
    </div>
  )
}

async function Workspace({ ownerId }: { ownerId: string }) {
  const [todos, journal, tools] = await Promise.all([
    ownerRows('todos', ownerId, 'created_at', 100),
    ownerRows('journal_entries', ownerId, 'entry_date', 100),
    ownerRows('tool_assets', ownerId, 'created_at', 100),
  ])
  return (
    <div className="space-y-2">
      <div className="grid gap-2 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>To do</CardTitle>
          </CardHeader>
          <CardBody className="px-0 pb-0">
            <RowTable
              rows={todos}
              empty="Nothing on the list."
              columns={[
                { key: 'title', label: 'Task' },
                { key: 'due_at', label: 'Due', render: (v) => fmtDateTime(v as string) },
                {
                  key: 'completed',
                  label: 'Done',
                  render: (v) => (v ? <Badge tone="success">Done</Badge> : <Badge tone="muted">Open</Badge>),
                },
                { key: 'completed_at', label: 'Finished', align: 'right', render: (v) => fmtAgo(v as string) },
              ]}
            />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Diary</CardTitle>
          </CardHeader>
          <CardBody className="px-0 pb-0">
            <RowTable
              rows={journal}
              empty="No diary entries."
              columns={[
                { key: 'title', label: 'Entry' },
                { key: 'entry_date', label: 'Date', render: (v) => fmtDate(v as string) },
                { key: 'all_day', label: 'All day' },
                { key: 'customer_name', label: 'Customer' },
                { key: 'location', label: 'Where' },
              ]}
            />
          </CardBody>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Notes and files</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{fmtNum(tools.length)}</span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={tools}
            empty="Nothing stored."
            columns={[
              { key: 'title', label: 'Title' },
              { key: 'kind', label: 'Kind', badge: true },
              { key: 'file_name', label: 'File' },
              { key: 'mime_type', label: 'Type' },
              { key: 'size_bytes', label: 'Size', align: 'right', render: (v) => fmtBytes(v as number) },
              { key: 'created_at', label: 'Added', align: 'right', render: (v) => fmtDate(v as string) },
            ]}
          />
        </CardBody>
      </Card>
    </div>
  )
}

async function Portfolio({ ownerId }: { ownerId: string }) {
  const [media, documents] = await Promise.all([
    ownerRows('portfolio_media', ownerId, 'created_at', 200),
    ownerRows('extra_documents', ownerId, 'created_at', 100),
  ])
  return (
    <div className="space-y-2">
      <Card>
        <CardHeader>
          <CardTitle>Portfolio media</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{fmtNum(media.length)}</span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={media}
            empty="Nothing in the portfolio."
            columns={[
              { key: 'title', label: 'Title' },
              { key: 'kind', label: 'Kind', badge: true },
              { key: 'job_title', label: 'Job' },
              { key: 'is_video', label: 'Video' },
              { key: 'duration_seconds', label: 'Length', align: 'right' },
              { key: 'file_size', label: 'Size', align: 'right', render: (v) => fmtBytes(v as number) },
              { key: 'created_at', label: 'Added', align: 'right', render: (v) => fmtDate(v as string) },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Other documents</CardTitle>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={documents}
            empty="No extra documents."
            columns={[
              { key: 'name', label: 'Name' },
              { key: 'type', label: 'Type' },
              { key: 'description', label: 'Description' },
              { key: 'file_size', label: 'Size', align: 'right', render: (v) => fmtBytes(v as number) },
              { key: 'created_at', label: 'Added', align: 'right', render: (v) => fmtDate(v as string) },
            ]}
          />
        </CardBody>
      </Card>
    </div>
  )
}

async function Shares({ ownerId }: { ownerId: string }) {
  const rows = await ownerRows('document_shares', ownerId, 'created_at', 200)
  return (
    <>
      <p className="mb-2 text-[11px] text-muted-foreground">
        Public links to a quote or an invoice. A tombstone with no quote and no invoice is a
        deleted document whose link is still in somebody&apos;s inbox — which is the case worth
        catching here.
      </p>
      <RowTable
        rows={rows}
        empty="Nothing shared."
        columns={[
          { key: 'token', label: 'Token' },
          {
            key: 'quote_id',
            label: 'Document',
            render: (_v, row) =>
              row.quote_id ? (
                <Badge tone="info">Quote</Badge>
              ) : row.invoice_id ? (
                <Badge tone="primary">Invoice</Badge>
              ) : (
                <Badge tone="danger">Deleted</Badge>
              ),
          },
          { key: 'created_at', label: 'Created', render: (v) => fmtDate(v as string) },
          { key: 'viewed_at', label: 'Opened', render: (v) => fmtAgo(v as string) },
          { key: 'responded_at', label: 'Answered', render: (v) => fmtAgo(v as string) },
          { key: 'responded_action', label: 'Answer', badge: true },
          { key: 'deleted_at', label: 'Revoked', align: 'right', render: (v) => fmtAgo(v as string) },
        ]}
      />
    </>
  )
}

function Raw({ profile }: { profile: ProfileRow }) {
  return (
    <div className="grid gap-2 lg:grid-cols-2">
      <Card>
        <CardHeader>
          <CardTitle>details jsonb</CardTitle>
        </CardHeader>
        <CardBody>
          <p className="mb-2 text-[11px] leading-relaxed text-muted-foreground">
            The catch-all column. Anything the app persists that has no typed column of its own
            lands here, so it is the first place to look when a value shows in the app and nowhere
            on this page.
          </p>
          <JsonView value={profile.details} />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>profiles row</CardTitle>
        </CardHeader>
        <CardBody>
          <JsonView value={profile} />
        </CardBody>
      </Card>
    </div>
  )
}
