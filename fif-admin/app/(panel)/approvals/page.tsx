import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { listTable, PAGE_SIZE } from '@/lib/queries'
import { supabaseAdmin } from '@/lib/supabase/server'
import { Badge, type BadgeTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDate, humanise } from '@/lib/format'
import { Decide } from './decide'

export const metadata = { title: 'Approvals · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * One queue for one journey.
 *
 * Verification and leads approval are still two decisions made on different
 * evidence — a passport is not an insurance certificate — but they happen in
 * order, and an unverified account cannot be approved for leads at all. Split
 * across two pages, staff had to hold that sequence in their heads and check
 * both to answer "where is this person up to".
 *
 * The stage comes from `tradesperson_approval_queue`, so the panel and
 * anything else asking the same question get the same answer.
 */

/** How each stage reads, and whether it is somebody's turn to act. */
const STAGE: Record<string, { label: string; tone: BadgeTone }> = {
  to_review: { label: 'To review', tone: 'warning' },
  approved: { label: 'Verified & approved', tone: 'success' },
  rejected: { label: 'Rejected', tone: 'danger' },
  withdrawn: { label: 'Withdrawn', tone: 'muted' },
  verified: { label: 'Verified, no application', tone: 'success' },
  not_started: { label: 'Not started', tone: 'muted' },
}

export default async function ApprovalsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; stage?: string; page?: string }>
}) {
  const admin = await requirePermission('reviewVerification')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1
  // Waiting first, because a queue is for finding the next piece of work.
  const stage = params.stage ?? 'waiting'

  const db = supabaseAdmin()
  let query = db
    .from('tradesperson_approval_queue')
    .select('*', { count: 'exact' })

  if (stage === 'waiting') {
    query = query.eq('needs_action', true)
  } else if (stage !== 'all') {
    query = query.eq('stage', stage)
  }
  if (params.q) {
    const like = `%${params.q}%`
    query = query.or(
      `email.ilike.${like},first_name.ilike.${like},last_name.ilike.${like}`,
    )
  }

  const from = (page - 1) * PAGE_SIZE
  const { data, count } = await query
    // Oldest waiting first — the fair order, and the one somebody will
    // eventually want to report a turnaround time on.
    .order('needs_action', { ascending: false })
    .order('waiting_since', { ascending: true, nullsFirst: false })
    .range(from, from + PAGE_SIZE - 1)

  const rows = (data ?? []) as Record<string, unknown>[]
  const total = count ?? 0

  const { rows: allRows } = await listTable({
    table: 'tradesperson_approval_queue',
    orderBy: 'waiting_since',
    pageSize: 1000,
  })
  const counts = allRows.reduce<Record<string, number>>((acc, r) => {
    const key = r.stage as string
    acc[key] = (acc[key] ?? 0) + 1
    return acc
  }, {})

  const waiting = counts.to_review ?? 0
  const canLeads = can(admin.role, 'reviewLeadApplications')

  return (
    <>
      <PageHeader
        title="Approvals"
        subtitle="One application each: how they work, their trades, where they travel from, who insures them, and who they are. Approving it verifies the account and turns their leads on."
        actions={<SearchBox placeholder="Name or email…" />}
      />

      <FilterBar
        filters={[
          {
            param: 'stage',
            label: 'Stage',
            options: [
              'waiting',
              'to_review',
              'approved',
              'rejected',
              'withdrawn',
              'not_started',
              'all',
            ],
            current: stage,
          },
        ]}
      />

      <p className="mb-2 text-[11px] text-muted-foreground">
        {waiting} waiting on you · {counts.approved ?? 0} verified and
        approved · {counts.rejected ?? 0} rejected · {counts.not_started ?? 0}{' '}
        not started. Nothing is deleted; a decided row keeps its reason.
      </p>

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Tradesperson</TH>
              <TH>Stage</TH>
              <TH>ID</TH>
              <TH>Trades</TH>
              <TH>Insurance</TH>
              <TH className="text-right">Waiting</TH>
              <TH className="text-right">Decision</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={7}>
                {stage === 'waiting'
                  ? 'Nothing waiting on you.'
                  : 'Nobody at that stage.'}
              </Empty>
            ) : (
              rows.map((r) => {
                const key = r.stage as string
                const meta = STAGE[key] ?? { label: humanise(key), tone: 'default' as BadgeTone }
                const services = (r.services as string[] | null) ?? []
                const expires = r.policy_expires_at as string | null
                const expired = expires ? new Date(expires) < new Date() : false

                return (
                  <TR key={r.id as string}>
                    <TD>
                      <OwnerLink
                        id={r.id as string}
                        owner={{
                          name: [r.first_name, r.last_name].filter(Boolean).join(' '),
                          email: r.email as string | null,
                          account_type: r.account_type as string,
                        }}
                      />
                    </TD>
                    <TD>
                      <Badge tone={meta.tone}>{meta.label}</Badge>
                    </TD>
                    <TD>
                      {r.document_type ? (
                        <span className="text-muted-foreground">
                          {humanise(r.document_type)}
                        </span>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TD>
                    <TD className="max-w-[12rem] truncate text-muted-foreground">
                      {services.length === 0
                        ? '—'
                        : services.map(humanise).join(', ')}
                    </TD>
                    <TD>
                      {r.application_status == null ? (
                        <span className="text-muted-foreground">—</span>
                      ) : r.has_own_insurance === false ? (
                        <Badge tone="warning">Under someone else</Badge>
                      ) : expired ? (
                        <Badge tone="danger">Expired {fmtDate(expires!)}</Badge>
                      ) : expires ? (
                        <span className="text-muted-foreground">
                          to {fmtDate(expires)}
                        </span>
                      ) : (
                        <Badge tone="warning">No expiry</Badge>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {r.needs_action && r.waiting_since ? (
                        <span title={fmtDate(r.waiting_since as string)}>
                          {fmtAgo(r.waiting_since as string)}
                        </span>
                      ) : (
                        '—'
                      )}
                    </TD>
                    <TD className="text-right">
                      <Decide row={r} canLeads={canLeads} />
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        params={{ q: params.q, stage: params.stage }}
      />
    </>
  )
}
