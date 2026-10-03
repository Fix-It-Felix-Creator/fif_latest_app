import Link from 'next/link'
import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import {
  countPastRetention,
  countRows,
  countSince,
  dashboardStats,
  listTable,
} from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Stat } from '@/components/ui/stat'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { KV } from '@/components/ui/kv'
import { fmtAgo, fmtDuration, fmtMoney, fmtNum, humanise, pct } from '@/lib/format'

export const metadata = { title: 'Dashboard · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

function daysAgo(n: number): Date {
  return new Date(Date.now() - n * 24 * 60 * 60 * 1000)
}

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ denied?: string }>
}) {
  const admin = await requirePermission('viewDashboard')
  const { denied } = await searchParams

  const week = daysAgo(7)
  const month = daysAgo(30)

  const [
    tradesmen,
    businesses,
    customers,
    newWeek,
    newMonth,
    newCustomersWeek,
    waiting,
    verified,
    rejected,
    activeSubs,
    trialSubs,
    deletionPending,
    disabled,
    pastRetention,
    notifWeek,
    stats,
  ] = await Promise.all([
    countRows('profiles', { account_type: 'tradesman' }),
    countRows('profiles', { account_type: 'business' }),
    countRows('profiles', { account_type: 'customer' }),
    countSince('profiles', 'created_at', week),
    countSince('profiles', 'created_at', month),
    countSince('profiles', 'created_at', week, { account_type: 'customer' }),
    countRows('profiles', { verification_status: 'waiting' }),
    countRows('profiles', { verification_status: 'verified' }),
    countRows('profiles', { verification_status: 'rejected' }),
    countRows('subscriptions', { status: 'active' }),
    countRows('subscriptions', { status: 'trial' }),
    countRows('profiles', { account_status: 'deletion_pending' }),
    countRows('profiles', { account_status: 'disabled' }),
    // The purge job the spec flags as missing (§5.10). Until something runs
    // it, this is the only place anyone would notice data outliving its
    // retention promise — so it gets a number rather than a footnote.
    countPastRetention(),
    countSince('notifications', 'created_at', week),
    dashboardStats(),
  ])

  const trade = tradesmen + businesses
  const people = trade + customers
  const finance = can(admin.role, 'readFinance')

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="Both apps, one project. Tradespeople and businesses use the Pro app; customers use the customer app."
      />

      {denied ? (
        <p
          role="alert"
          className="mb-3 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-[11px] text-warning"
        >
          Your role does not include <span className="font-medium">{humanise(denied)}</span>, so that
          page sent you here.
        </p>
      ) : null}

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4 xl:grid-cols-8">
        <Stat label="Tradespeople" value={fmtNum(tradesmen)} hint="Pro app · sole traders" />
        <Stat label="Businesses" value={fmtNum(businesses)} hint="Pro app · companies" />
        <Stat
          label="Customers"
          value={fmtNum(customers)}
          tone="success"
          hint={`${fmtNum(newCustomersWeek)} in 7 days`}
        />
        <Stat label="New in 7 days" value={fmtNum(newWeek)} hint={`${fmtNum(newMonth)} in 30 days`} />
        <Stat
          label="Awaiting review"
          value={fmtNum(waiting)}
          tone={waiting > 0 ? 'warning' : 'default'}
          hint={<Link href="/approvals" className="hover:text-foreground">Open the queue</Link>}
        />
        <Stat
          label="Paying"
          value={fmtNum(activeSubs)}
          tone="success"
          hint={`${fmtNum(trialSubs)} on trial · ${pct(activeSubs, trade)}% of trade accounts`}
        />
        <Stat
          label="Deletion pending"
          value={fmtNum(deletionPending)}
          tone={deletionPending > 0 ? 'warning' : 'default'}
          hint={`${fmtNum(disabled)} disabled`}
        />
        <Stat
          label="Past retention"
          value={fmtNum(pastRetention)}
          tone={pastRetention > 0 ? 'danger' : 'default'}
          hint="Data owed a purge"
        />
      </div>

      <div className="grid gap-2 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>Who is here</CardTitle>
            <span className="tabular text-[10px] text-muted-foreground">{fmtNum(people)} total</span>
          </CardHeader>
          <CardBody>
            <KV
              columns={1}
              items={[
                { label: 'Tradespeople', value: fmtNum(tradesmen) },
                { label: 'Businesses', value: fmtNum(businesses) },
                { label: 'Customers', value: fmtNum(customers) },
                { label: 'Signed up this week', value: fmtNum(newWeek) },
                { label: 'Signed up this month', value: fmtNum(newMonth) },
                { label: 'Notifications sent this week', value: fmtNum(notifWeek) },
              ]}
            />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Verification</CardTitle>
            <Link href="/approvals" className="text-[10px] text-primary hover:underline">
              Review
            </Link>
          </CardHeader>
          <CardBody>
            <KV
              columns={1}
              items={[
                { label: 'Waiting', value: fmtNum(waiting) },
                { label: 'Verified', value: fmtNum(verified) },
                { label: 'Rejected', value: fmtNum(rejected) },
                {
                  label: 'Never submitted',
                  // Everything that is neither of the three above. A dash here
                  // would hide the largest group on the platform.
                  value: fmtNum(Math.max(0, trade - waiting - verified - rejected)),
                },
              ]}
            />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account states</CardTitle>
          </CardHeader>
          <CardBody>
            <KV
              columns={1}
              items={[
                { label: 'Active', value: fmtNum(people - disabled - deletionPending) },
                { label: 'Disabled', value: fmtNum(disabled) },
                { label: 'Deletion pending', value: fmtNum(deletionPending) },
                { label: 'Past their retention date', value: fmtNum(pastRetention) },
              ]}
            />
            {pastRetention > 0 ? (
              <p className="mt-2 text-[10px] leading-relaxed text-warning">
                No scheduled job purges these. Until one exists, clearing them is a manual job —{' '}
                <Link href="/deletions" className="underline">the deletions page</Link> lists them.
              </p>
            ) : null}
          </CardBody>
        </Card>
      </div>

      {finance ? <MoneySection stats={stats} /> : null}

      {can(admin.role, 'viewAudit') ? <RecentAudit /> : null}
    </>
  )
}

async function MoneySection({
  stats,
}: {
  stats: Awaited<ReturnType<typeof dashboardStats>>
}) {
  if (!stats.ok) {
    return (
      <Card className="mt-2">
        <CardHeader>
          <CardTitle>Money</CardTitle>
        </CardHeader>
        <CardBody>
          <p className="text-xs text-muted-foreground">{stats.reason}</p>
          <p className="mt-1 text-[10px] text-muted-foreground">
            Counts above come from head requests and do not need it. Totals do — Postgres has to do
            the summing, or the panel would be fetching every invoice to add them up.
          </p>
        </CardBody>
      </Card>
    )
  }

  const s = stats.stats
  const invoiceRows = Object.entries(s.invoices)
  const quoteRows = Object.entries(s.quotes)
  const outstanding = (s.invoices.sent?.total ?? 0) + (s.invoices.overdue?.total ?? 0)
  const shares = s.shares

  return (
    <>
      <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        <Stat
          label="Invoiced, 30 days"
          value={fmtMoney(s.work_30d.invoiced)}
          hint={`${fmtNum(s.work_30d.invoices)} invoices`}
        />
        <Stat
          label="Paid, all time"
          value={fmtMoney(s.invoices.paid?.total ?? 0)}
          tone="success"
          hint={`${fmtNum(s.invoices.paid?.count ?? 0)} invoices`}
        />
        <Stat
          label="Outstanding"
          value={fmtMoney(outstanding)}
          tone={(s.invoices.overdue?.count ?? 0) > 0 ? 'danger' : 'default'}
          hint={`${fmtNum(s.invoices.overdue?.count ?? 0)} overdue`}
        />
        <Stat
          label="Quoted, accepted"
          value={fmtMoney(s.quotes.accepted?.total ?? 0)}
          hint={`${fmtNum(s.quotes.accepted?.count ?? 0)} quotes`}
        />
        <Stat label="Expenses logged" value={fmtMoney(s.expenses_total)} />
        <Stat
          label="Time tracked"
          value={fmtDuration(s.tracked_seconds)}
          hint="Across every clocked session"
        />
      </div>

      <div className="mt-2 grid gap-2 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>Invoices by status</CardTitle>
          </CardHeader>
          <CardBody className="px-0 pb-0">
            <StatusTotals rows={invoiceRows} href="/invoices" />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Quotes by status</CardTitle>
          </CardHeader>
          <CardBody className="px-0 pb-0">
            <StatusTotals rows={quoteRows} href="/quotes" />
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Share links</CardTitle>
            <Link href="/shares" className="text-[10px] text-primary hover:underline">
              All links
            </Link>
          </CardHeader>
          <CardBody>
            <KV
              columns={1}
              items={[
                { label: 'Sent', value: fmtNum(shares.created) },
                {
                  label: 'Opened by the customer',
                  value: `${fmtNum(shares.viewed)} · ${pct(shares.viewed, shares.created)}%`,
                },
                {
                  label: 'Responded to',
                  value: `${fmtNum(shares.responded)} · ${pct(shares.responded, shares.created)}%`,
                },
                { label: 'Accepted', value: fmtNum(shares.accepted) },
                { label: 'Rejected', value: fmtNum(shares.rejected) },
              ]}
            />
          </CardBody>
        </Card>
      </div>

      <Card className="mt-2">
        <CardHeader>
          <CardTitle>Subscriptions</CardTitle>
          <span className="text-[10px] text-muted-foreground">
            {s.stale_subscriptions > 0 ? (
              <Link href="/subscriptions?anomaly=stale" className="text-destructive hover:underline">
                {fmtNum(s.stale_subscriptions)} active but past their period end
              </Link>
            ) : (
              'Nothing out of sync'
            )}
          </span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <TableWrap className="rounded-none border-0">
            <Table>
              <THead>
                <TR>
                  <TH>Status</TH>
                  <TH>Plan</TH>
                  <TH>Provider</TH>
                  <TH>Cycle</TH>
                  <TH className="text-right">Accounts</TH>
                  <TH className="text-right">Listed value</TH>
                </TR>
              </THead>
              <TBody>
                {s.subscriptions.length === 0 ? (
                  <Empty colSpan={6}>No subscription rows at all.</Empty>
                ) : (
                  [...s.subscriptions]
                    .sort((a, b) => b.count - a.count)
                    .map((row, i) => (
                      <TR key={i}>
                        <TD>
                          <Badge tone={statusTone(row.status)}>{humanise(row.status)}</Badge>
                        </TD>
                        <TD>{humanise(row.plan_type)}</TD>
                        <TD className="text-muted-foreground">{humanise(row.provider)}</TD>
                        <TD className="text-muted-foreground">{humanise(row.billing_cycle)}</TD>
                        <TD className="tabular text-right">{fmtNum(row.count)}</TD>
                        <TD className="tabular text-right">{fmtMoney(row.price)}</TD>
                      </TR>
                    ))
                )}
              </TBody>
            </Table>
          </TableWrap>
        </CardBody>
      </Card>
    </>
  )
}

function StatusTotals({
  rows,
  href,
}: {
  rows: Array<[string, { count: number; total: number }]>
  href: string
}) {
  return (
    <TableWrap className="rounded-none border-0">
      <Table>
        <THead>
          <TR>
            <TH>Status</TH>
            <TH className="text-right">Count</TH>
            <TH className="text-right">Total</TH>
          </TR>
        </THead>
        <TBody>
          {rows.length === 0 ? (
            <Empty colSpan={3}>Nothing here yet.</Empty>
          ) : (
            rows
              .sort((a, b) => b[1].count - a[1].count)
              .map(([status, v]) => (
                <TR key={status}>
                  <TD>
                    <Link href={`${href}?status=${status}`}>
                      <Badge tone={statusTone(status)}>{humanise(status)}</Badge>
                    </Link>
                  </TD>
                  <TD className="tabular text-right">{fmtNum(v.count)}</TD>
                  <TD className="tabular text-right">{fmtMoney(v.total)}</TD>
                </TR>
              ))
          )}
        </TBody>
      </Table>
    </TableWrap>
  )
}

async function RecentAudit() {
  const { rows } = await listTable({
    table: 'admin_audit_log',
    orderBy: 'created_at',
    pageSize: 8,
  }).catch(() => ({ rows: [], total: 0 }))

  return (
    <Card className="mt-2">
      <CardHeader>
        <CardTitle>Latest staff actions</CardTitle>
        <Link href="/audit" className="text-[10px] text-primary hover:underline">
          Full log
        </Link>
      </CardHeader>
      <CardBody className="px-0 pb-0">
        <TableWrap className="rounded-none border-0">
          <Table>
            <THead>
              <TR>
                <TH>When</TH>
                <TH>Who</TH>
                <TH>Did what</TH>
                <TH>To</TH>
              </TR>
            </THead>
            <TBody>
              {rows.length === 0 ? (
                <Empty colSpan={4}>
                  Nothing recorded yet — either nobody has changed anything, or the Phase 9
                  migration has not been applied.
                </Empty>
              ) : (
                rows.map((r, i) => (
                  <TR key={(r.id as string) ?? i}>
                    <TD className="whitespace-nowrap text-muted-foreground">
                      {fmtAgo(r.created_at as string)}
                    </TD>
                    <TD className="max-w-[14rem] truncate">{(r.actor_email as string) ?? '—'}</TD>
                    <TD>{humanise(r.action)}</TD>
                    <TD className="tabular max-w-[16rem] truncate text-muted-foreground">
                      {(r.entity as string)}
                      {r.entity_id ? ` · ${r.entity_id}` : ''}
                    </TD>
                  </TR>
                ))
              )}
            </TBody>
          </Table>
        </TableWrap>
      </CardBody>
    </Card>
  )
}
