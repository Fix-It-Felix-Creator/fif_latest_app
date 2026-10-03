import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDate, humanise } from '@/lib/format'

export const metadata = { title: 'Job requests · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * What homeowners posted.
 *
 * Separate from /jobs on purpose. A job is a tradesperson's record of work
 * they are doing; a request is a customer asking for someone, and most of the
 * support questions about it are the ones this page can answer — did it go
 * out, who has it, and why has nobody called.
 *
 * The column that earns this page is `latitude`. A request with no
 * coordinates cannot be returned by any distance search, so it sits looking
 * perfectly posted while reaching nobody at all. That is invisible in the app
 * and would otherwise only surface as "I posted a job last week and heard
 * nothing".
 */
export default async function JobRequestsPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string
    status?: string
    urgency?: string
    customer?: string
    page?: string
  }>
}) {
  const admin = await requirePermission('viewJobRequests')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1
  const pii = can(admin.role, 'readPii')

  const [{ rows, total }, statuses, urgencies] = await Promise.all([
    listTable({
      table: 'job_requests',
      orderBy: 'created_at',
      page,
      filters: {
        status: params.status,
        urgency: params.urgency,
        customer_id: params.customer,
      },
      searchColumns: ['service_name', 'description', 'formatted_address', 'postcode'],
      q: params.q,
    }),
    distinctValues('job_requests', 'status'),
    distinctValues('job_requests', 'urgency'),
  ])

  const people = await namesFor([
    ...rows.map((r) => r.customer_id as string),
    ...rows.map((r) => r.accepted_by as string).filter(Boolean),
  ])

  // Counted on this page rather than across the table: it is a prompt to look,
  // not a metric, and a number that needs its own query to be right is a
  // number that will be wrong.
  const unpinned = rows.filter(
    (r) => r.latitude === null && r.status !== 'completed' && r.status !== 'cancelled',
  ).length

  return (
    <>
      <PageHeader
        title="Job requests"
        subtitle="What customers posted. Search matches the service, the description, the address and the postcode."
        actions={<SearchBox placeholder="Service, address or postcode…" />}
      />

      <FilterBar
        filters={[
          { param: 'status', label: 'Status', options: statuses, current: params.status },
          { param: 'urgency', label: 'Urgency', options: urgencies, current: params.urgency },
        ]}
      />

      {unpinned > 0 ? (
        <p className="mb-2 text-[11px] text-destructive">
          {unpinned} open {unpinned === 1 ? 'request has' : 'requests have'} no map pin, so no
          nearby tradesperson can be matched to {unpinned === 1 ? 'it' : 'them'}.
        </p>
      ) : null}

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Service</TH>
              <TH>What they asked for</TH>
              <TH>Customer</TH>
              <TH>Where</TH>
              <TH>Pin</TH>
              <TH>Urgency</TH>
              <TH>Status</TH>
              <TH>Accepted by</TH>
              <TH className="text-right">Posted</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={9}>No job requests match that.</Empty>
            ) : (
              rows.map((job) => {
                const selections = Array.isArray(job.selections)
                  ? (job.selections as Array<{ name?: string }>)
                  : []
                // The leaf is what the job IS; the trail above it is how they
                // got there, and it is the trail a tradesperson needs to quote.
                const trail = selections.map((s) => s?.name).filter(Boolean).join(' › ')
                const open = job.status !== 'completed' && job.status !== 'cancelled'
                const accepted = job.accepted_by as string | null

                return (
                  <TR key={job.id as string}>
                    <TD className="font-medium">{(job.service_name as string) || '—'}</TD>
                    <TD className="max-w-[20rem] truncate text-muted-foreground" title={trail}>
                      {trail || '—'}
                    </TD>
                    <TD>
                      <OwnerLink
                        id={job.customer_id as string}
                        owner={people.get(job.customer_id as string)}
                      />
                    </TD>
                    <TD className="max-w-[14rem] truncate text-muted-foreground">
                      {/* The full address is personal data. Without readPii
                          the postcode is enough to answer "is this the right
                          area", which is what this column is for. */}
                      {pii
                        ? (job.formatted_address as string) || '—'
                        : (job.postcode as string) || '—'}
                    </TD>
                    <TD>
                      {job.latitude !== null ? (
                        <span className="text-muted-foreground">—</span>
                      ) : (
                        <Badge tone={open ? 'danger' : 'muted'}>Missing</Badge>
                      )}
                    </TD>
                    <TD>{humanise(job.urgency)}</TD>
                    <TD>
                      <Badge tone={statusTone(job.status as string)}>
                        {humanise(job.status)}
                      </Badge>
                    </TD>
                    <TD>
                      {accepted ? (
                        <OwnerLink id={accepted} owner={people.get(accepted)} />
                      ) : (
                        <span className="text-muted-foreground">Nobody yet</span>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      <span title={fmtDate(job.created_at as string)}>
                        {fmtAgo(job.created_at as string)}
                      </span>
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
        params={{
          q: params.q,
          status: params.status,
          urgency: params.urgency,
          customer: params.customer,
        }}
      />
    </>
  )
}
