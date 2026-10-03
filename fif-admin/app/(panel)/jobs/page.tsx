import { requirePermission } from '@/lib/auth'
import { distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDate, humanise } from '@/lib/format'

export const metadata = { title: 'Jobs · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

export default async function JobsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; owner?: string; page?: string }>
}) {
  await requirePermission('viewWork')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const [{ rows, total }, statuses] = await Promise.all([
    listTable({
      table: 'jobs',
      orderBy: 'created_at',
      page,
      filters: { status: params.status, owner_id: params.owner },
      searchColumns: ['reference', 'title', 'description'],
      q: params.q,
    }),
    distinctValues('jobs', 'status'),
  ])

  const owners = await namesFor(rows.map((r) => r.owner_id as string))
  const running = rows.filter((r) => r.clock_in_at).length

  return (
    <>
      <PageHeader
        title="Jobs"
        subtitle="Every job across every tradesperson. Search matches reference, title and description."
        actions={<SearchBox placeholder="Reference or title…" />}
      />

      <FilterBar
        filters={[{ param: 'status', label: 'Status', options: statuses, current: params.status }]}
      />

      {running > 0 ? (
        <p className="mb-2 text-[11px] text-muted-foreground">
          {running} on this page {running === 1 ? 'has' : 'have'} a clock running right now.
        </p>
      ) : null}

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Reference</TH>
              <TH>Title</TH>
              <TH>Tradesperson</TH>
              <TH>Customer</TH>
              <TH>Status</TH>
              <TH>Clock</TH>
              <TH className="text-right">Starts</TH>
              <TH className="text-right">Created</TH>
              <TH className="text-right">Changed</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={9}>No jobs match that.</Empty>
            ) : (
              rows.map((job) => {
                const snapshot = job.customer_snapshot as Record<string, unknown> | null
                return (
                  <TR key={job.id as string}>
                    <TD className="tabular font-medium">{(job.reference as string) || '—'}</TD>
                    <TD className="max-w-[16rem] truncate">{(job.title as string) || '—'}</TD>
                    <TD>
                      <OwnerLink
                        id={job.owner_id as string}
                        owner={owners.get(job.owner_id as string)}
                      />
                    </TD>
                    <TD className="max-w-[12rem] truncate text-muted-foreground">
                      {/* The snapshot, not a join: a job keeps the customer as
                          they were when it was written, and that is the name
                          on the paperwork even if the contact changed since. */}
                      {(snapshot?.name as string) ?? '—'}
                    </TD>
                    <TD>
                      <Badge tone={statusTone(job.status as string)}>
                        {humanise(job.status)}
                      </Badge>
                    </TD>
                    <TD>
                      {job.clock_in_at ? (
                        <Badge tone="info">Since {fmtAgo(job.clock_in_at as string)}</Badge>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(job.start_date as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(job.created_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(job.updated_at as string)}
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
        params={{ q: params.q, status: params.status, owner: params.owner }}
      />
    </>
  )
}
