import { requirePermission } from '@/lib/auth'
import { distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDate, fmtMoney, humanise } from '@/lib/format'

export const metadata = { title: 'Quotes · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

export default async function QuotesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; owner?: string; page?: string }>
}) {
  await requirePermission('viewWork')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const [{ rows, total }, statuses] = await Promise.all([
    listTable({
      table: 'quotes',
      orderBy: 'created_at',
      page,
      filters: { status: params.status, owner_id: params.owner },
      searchColumns: ['reference', 'title', 'share_token'],
      q: params.q,
    }),
    distinctValues('quotes', 'status'),
  ])

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Quotes"
        subtitle="Search matches reference, title and share token — paste a token from a customer's link to find the quote behind it."
        actions={<SearchBox placeholder="Reference, title or token…" />}
      />

      <FilterBar
        filters={[{ param: 'status', label: 'Status', options: statuses, current: params.status }]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Reference</TH>
              <TH>Title</TH>
              <TH>Tradesperson</TH>
              <TH>Customer</TH>
              <TH>Status</TH>
              <TH className="text-right">Total</TH>
              <TH>Expiry</TH>
              <TH className="text-right">Dated</TH>
              <TH className="text-right">Sent</TH>
              <TH className="text-right">Opened</TH>
              <TH className="text-right">Answered</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={11}>No quotes match that.</Empty>
            ) : (
              rows.map((q) => {
                const snapshot = q.customer_snapshot as Record<string, unknown> | null
                return (
                  <TR key={q.id as string}>
                    <TD className="tabular font-medium">{(q.reference as string) || '—'}</TD>
                    <TD className="max-w-[14rem] truncate">{(q.title as string) || '—'}</TD>
                    <TD>
                      <OwnerLink id={q.owner_id as string} owner={owners.get(q.owner_id as string)} />
                    </TD>
                    <TD className="max-w-[11rem] truncate text-muted-foreground">
                      {(snapshot?.name as string) ?? '—'}
                    </TD>
                    <TD>
                      <Badge tone={statusTone(q.status as string)}>{humanise(q.status)}</Badge>
                    </TD>
                    <TD className="tabular text-right font-medium">{fmtMoney(q.total as number)}</TD>
                    <TD className="text-muted-foreground">{humanise(q.expiry)}</TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(q.quote_date as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(q.sent_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(q.viewed_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(q.responded_at as string)}
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
