import { notFound, redirect } from 'next/navigation'
import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { getProfile, ownerCounts, type ProfileRow } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Tabs } from '@/components/tabs'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { KV } from '@/components/ui/kv'
import { JsonView } from '@/components/ui/json-view'
import { Badge, statusTone } from '@/components/ui/badge'
import { ExternalLink } from '@/components/external-link'
import { AccountActions } from '@/app/(panel)/_components/account-actions'
import { DevicesTab, JobRequestsTab, NotificationsTab } from '@/app/(panel)/_components/person-tabs'
import { fmtAgo, fmtDate, fmtNum, fullName, humanise, initials, shortAddress } from '@/lib/format'

export const dynamic = 'force-dynamic'

type Params = { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> }

export async function generateMetadata({ params }: Params) {
  const { id } = await params
  const profile = await getProfile(id)
  const name = profile ? (fullName(profile.first_name, profile.last_name) ?? profile.email) : null
  return { title: `${name ?? 'Customer'} · Fix It Felix Admin` }
}

/**
 * A customer account.
 *
 * Short by design, and it should stay short until the customer app grows a
 * domain of its own. What exists today is an identity, a contact address and
 * the devices it is signed in on — so this page shows those properly rather
 * than padding itself with a dozen empty sections borrowed from the Pro app.
 */
export default async function CustomerPage({ params, searchParams }: Params) {
  const admin = await requirePermission('viewCustomers')
  const { id } = await params
  const { tab = 'overview' } = await searchParams

  const profile = await getProfile(id)
  if (!profile) notFound()
  if (profile.account_type !== 'customer') redirect(`/tradespeople/${id}`)

  const counts = await ownerCounts(id)
  const name = fullName(profile.first_name, profile.last_name)

  const tabs = [
    { key: 'overview', label: 'Overview' },
    ...(can(admin.role, 'viewJobRequests')
      ? [{ key: 'jobs', label: 'Jobs posted', count: counts.jobRequests }]
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
        title={name ?? 'No name yet'}
        subtitle={
          <span className="flex flex-wrap items-center gap-1.5">
            <Badge tone="success">Customer app</Badge>
            <Badge tone={statusTone(profile.account_status)}>
              {humanise(profile.account_status)}
            </Badge>
            <span className="tabular text-muted-foreground">
              Joined {fmtDate(profile.created_at)}
            </span>
          </span>
        }
        actions={
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-semibold">
            {initials(name, profile.email)}
          </div>
        }
      />

      <Tabs tabs={tabs} current={tab} basePath={`/customers/${id}`} />

      {tab === 'overview' ? (
        <Overview
          profile={profile}
          counts={counts}
          canAct={can(admin.role, 'manageAccount')}
          pii={can(admin.role, 'readPii')}
        />
      ) : null}
      {tab === 'jobs' ? <JobRequestsTab customerId={id} /> : null}
      {tab === 'devices' ? <DevicesTab ownerId={id} /> : null}
      {tab === 'notifications' ? <NotificationsTab ownerId={id} /> : null}
      {tab === 'raw' ? (
        <div className="grid gap-2 lg:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>details jsonb</CardTitle>
            </CardHeader>
            <CardBody>
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
      ) : null}
    </>
  )
}

async function Overview({
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
  const name = fullName(profile.first_name, profile.last_name)
  const hasAddress = Boolean(profile.postcode || profile.formatted_address)

  // A customer account holding tradesperson records means something went
  // wrong — most likely a Pro-app account whose `account_type` was flipped, or
  // the customer app's claim step running on an existing profile. It is rare
  // enough to deserve a warning and too important to leave invisible.
  const strayTables = ['jobs', 'quotes', 'invoices', 'clients', 'staff'] as const
  const stray = strayTables.filter((key) => (counts[key] ?? 0) > 0)

  return (
    <div className="space-y-2">
      {stray.length ? (
        <p
          role="alert"
          className="rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-[11px] leading-relaxed text-warning"
        >
          This customer account owns Pro-app records:{' '}
          {stray.map((k) => `${fmtNum(counts[k])} ${k}`).join(', ')}. A customer never creates
          those, so this profile was most likely a tradesperson before its account type changed.
        </p>
      ) : null}

      {!name || !hasAddress ? (
        <p className="rounded-sm border border-border bg-card px-3 py-2 text-[11px] leading-relaxed text-muted-foreground">
          Onboarding is unfinished:{' '}
          {[!name && 'no name', !profile.phone && 'no phone', !hasAddress && 'no address']
            .filter(Boolean)
            .join(', ')}
          . The app asks for these after sign-in, so this account authenticated and stopped.
        </p>
      ) : null}

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
                { label: 'Currency', value: profile.currency },
                { label: 'Joined', value: fmtDate(profile.created_at) },
                { label: 'Last change', value: fmtAgo(profile.updated_at) },
                {
                  label: 'Migrated from Firebase',
                  value: profile.firebase_uid ? 'Yes' : 'No',
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

        <Card>
          <CardHeader>
            <CardTitle>Reachable how</CardTitle>
          </CardHeader>
          <CardBody>
            <KV
              items={[
                { label: 'Push', value: profile.push_enabled ? 'On' : 'Off' },
                { label: 'Email', value: profile.email_enabled ? 'On' : 'Off' },
                { label: 'SMS', value: profile.sms_enabled ? 'On' : 'Off' },
                { label: 'Devices signed in', value: fmtNum(counts.devices) },
                { label: 'Push tokens', value: fmtNum(counts.tokens) },
                { label: 'Jobs posted', value: fmtNum(counts.jobRequests) },
                { label: 'Notifications received', value: fmtNum(counts.notifications) },
              ]}
            />
            {counts.tokens === 0 && profile.push_enabled ? (
              <p className="mt-2 text-[10px] leading-relaxed text-muted-foreground">
                Push is switched on but no token has ever registered, so a push would silently
                reach nobody. Usually an OS-level permission that was never granted.
              </p>
            ) : null}
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
                  { label: 'Deletion requested', value: fmtDate(profile.deletion_requested_at) },
                  { label: 'Recovery ends', value: fmtDate(profile.recovery_window_ends_at) },
                  {
                    label: 'Data retained until',
                    value: fmtDate(profile.personal_data_retained_until),
                  },
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
