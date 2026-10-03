import Link from 'next/link'
import { requirePermission } from '@/lib/auth'
import { countRows, PAGE_SIZE } from '@/lib/queries'
import { supabaseAdmin } from '@/lib/supabase/server'
import { PageHeader } from '@/components/page-header'
import { Tabs } from '@/components/tabs'
import { Stat } from '@/components/ui/stat'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { ACCOUNT_TYPE_LABEL, Badge, accountTypeTone } from '@/components/ui/badge'
import { Pager } from '@/components/pager'
import { ownerHref } from '@/components/owner-link'
import { fmtAgo, fmtDate, fmtNum, fmtUntil, fullName, humanise, initials } from '@/lib/format'
import type { ProfileRow } from '@/lib/queries'

export const metadata = { title: 'Deletions · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * Accounts on the way out, and the ones nobody took out.
 *
 * Three lists, because they are three different problems:
 *
 *   Pending      — inside the recovery window. The person can still stop it.
 *   Due          — the window has closed. Nothing in the codebase acts on
 *                  this, so these sit here until someone does.
 *   Past retention — the date the app promised personal data would be gone
 *                  by. The spec (§5.10) flags the purge job as missing; until
 *                  it exists, this list is the only place that promise is
 *                  visible to anyone.
 */
const TABS = ['pending', 'due', 'retention'] as const
type Tab = (typeof TABS)[number]

export default async function DeletionsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; page?: string }>
}) {
  await requirePermission('manageAccount')
  const params = await searchParams
  const tab: Tab = (TABS as readonly string[]).includes(params.tab ?? '')
    ? (params.tab as Tab)
    : 'pending'
  const page = Number(params.page ?? '1') || 1

  const now = new Date().toISOString()
  const db = supabaseAdmin()

  function base() {
    return db.from('profiles').select('*', { count: 'exact' })
  }

  const [pendingCount, dueCount, retentionCount] = await Promise.all([
    countRows('profiles', { account_status: 'deletion_pending' }),
    base()
      .eq('account_status', 'deletion_pending')
      .lt('recovery_window_ends_at', now)
      .then((r) => r.count ?? 0),
    base()
      .not('personal_data_retained_until', 'is', null)
      .lt('personal_data_retained_until', now)
      .then((r) => r.count ?? 0),
  ])

  let query = base()
  if (tab === 'pending') {
    query = query.eq('account_status', 'deletion_pending').order('recovery_window_ends_at', { ascending: true })
  } else if (tab === 'due') {
    query = query
      .eq('account_status', 'deletion_pending')
      .lt('recovery_window_ends_at', now)
      .order('recovery_window_ends_at', { ascending: true })
  } else {
    query = query
      .not('personal_data_retained_until', 'is', null)
      .lt('personal_data_retained_until', now)
      .order('personal_data_retained_until', { ascending: true })
  }

  const from = (page - 1) * PAGE_SIZE
  const { data, count, error } = await query.range(from, from + PAGE_SIZE - 1)
  if (error) throw new Error(`Loading the deletion queue failed: ${error.message}`)
  const rows = (data ?? []) as ProfileRow[]

  return (
    <>
      <PageHeader
        title="Deletions"
        subtitle="Accounts a person asked to close, or that staff closed for them. Nothing here has been erased."
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Stat label="In the window" value={fmtNum(pendingCount - dueCount)} hint="Still recoverable" />
        <Stat
          label="Window closed"
          value={fmtNum(dueCount)}
          tone={dueCount > 0 ? 'warning' : 'default'}
          hint="Waiting on a purge"
        />
        <Stat
          label="Past retention"
          value={fmtNum(retentionCount)}
          tone={retentionCount > 0 ? 'danger' : 'default'}
          hint="Data promised gone"
        />
        <Stat label="Pending in total" value={fmtNum(pendingCount)} />
      </div>

      {retentionCount > 0 ? (
        <p className="mb-2 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-[11px] leading-relaxed text-warning">
          Nothing in the codebase purges these. The retention deadline is written when a deletion
          starts and then read by nobody — so until a scheduled job exists, clearing them is manual,
          and this list is how you find them.
        </p>
      ) : null}

      <Tabs
        basePath="/deletions"
        current={tab}
        tabs={[
          { key: 'pending', label: 'Pending', count: pendingCount },
          { key: 'due', label: 'Window closed', count: dueCount },
          { key: 'retention', label: 'Past retention', count: retentionCount },
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Account</TH>
              <TH>App</TH>
              <TH>Email</TH>
              <TH className="text-right">Requested</TH>
              <TH className="text-right">Recovery ends</TH>
              <TH className="text-right">Data retained until</TH>
              <TH className="text-right">Joined</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={7}>
                {tab === 'pending'
                  ? 'Nobody is mid-deletion.'
                  : tab === 'due'
                    ? 'Nothing has passed its recovery window.'
                    : 'Nothing is past its retention date.'}
              </Empty>
            ) : (
              rows.map((p) => {
                const name = fullName(p.first_name, p.last_name) ?? p.company_name
                const overdue =
                  p.recovery_window_ends_at != null &&
                  new Date(p.recovery_window_ends_at) < new Date()
                return (
                  <TR key={p.id}>
                    <TD>
                      <Link
                        href={ownerHref(p.id, p.account_type)}
                        className="group flex items-center gap-2"
                      >
                        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold">
                          {initials(name, p.email)}
                        </span>
                        <span className="max-w-[12rem] truncate font-medium group-hover:text-primary group-hover:underline">
                          {name ?? 'Unnamed'}
                        </span>
                      </Link>
                    </TD>
                    <TD>
                      <Badge tone={accountTypeTone(p.account_type)}>
                        {ACCOUNT_TYPE_LABEL[p.account_type] ?? humanise(p.account_type)}
                      </Badge>
                    </TD>
                    <TD className="max-w-[15rem] truncate text-muted-foreground">
                      {p.email || '—'}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(p.deletion_requested_at)}
                    </TD>
                    <TD
                      className={`whitespace-nowrap text-right ${overdue ? 'font-medium text-destructive' : 'text-muted-foreground'}`}
                    >
                      {fmtDate(p.recovery_window_ends_at)}
                      <span className="ml-1 text-[10px]">{fmtUntil(p.recovery_window_ends_at)}</span>
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(p.personal_data_retained_until)}
                      <span className="ml-1 text-[10px]">
                        {fmtUntil(p.personal_data_retained_until)}
                      </span>
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(p.created_at)}
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager page={page} pageSize={PAGE_SIZE} total={count ?? 0} params={{ tab }} />

      <p className="mt-2 text-[11px] leading-relaxed text-muted-foreground">
        Cancelling a deletion happens on the person&apos;s own page — it needs the context of who
        they are, not a row in a queue.
      </p>
    </>
  )
}
