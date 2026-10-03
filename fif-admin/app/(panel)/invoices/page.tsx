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

export const metadata = { title: 'Invoices · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string
    status?: string
    payment?: string
    owner?: string
    page?: string
  }>
}) {
  await requirePermission('viewWork')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const [{ rows, total }, statuses, methods] = await Promise.all([
    listTable({
      table: 'invoices',
      orderBy: 'created_at',
      page,
      filters: {
        status: params.status,
        payment_method: params.payment,
        owner_id: params.owner,
      },
      searchColumns: ['reference', 'title', 'share_token'],
      q: params.q,
    }),
    distinctValues('invoices', 'status'),
    distinctValues('invoices', 'payment_method'),
  ])

  const owners = await namesFor(rows.map((r) => r.owner_id as string))
  const today = new Date()

  return (
    <>
      <PageHeader
        title="Invoices"
        subtitle="Search matches reference, title and share token."
        actions={<SearchBox placeholder="Reference, title or token…" />}
      />

      <FilterBar
        filters={[
          { param: 'status', label: 'Status', options: statuses, current: params.status },
          { param: 'payment', label: 'Paid by', options: methods, current: params.payment },
        ]}
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
              <TH>Method</TH>
              <TH className="text-right">Dated</TH>
              <TH className="text-right">Due</TH>
              <TH className="text-right">Sent</TH>
              <TH className="text-right">Paid</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={11}>No invoices match that.</Empty>
            ) : (
              rows.map((inv) => {
                const snapshot = inv.customer_snapshot as Record<string, unknown> | null
                const due = inv.due_date as string | null
                // Past its due date and not paid, whatever the status column
                // says. Nothing moves a row to `overdue` on a schedule, so the
                // status alone would under-report it.
                const late =
                  !inv.paid_at && due != null && new Date(due) < today && inv.status !== 'cancelled'
                return (
                  <TR key={inv.id as string}>
                    <TD className="tabular font-medium">{(inv.reference as string) || '—'}</TD>
                    <TD className="max-w-[14rem] truncate">{(inv.title as string) || '—'}</TD>
                    <TD>
                      <OwnerLink
                        id={inv.owner_id as string}
                        owner={owners.get(inv.owner_id as string)}
                      />
                    </TD>
                    <TD className="max-w-[11rem] truncate text-muted-foreground">
                      {(snapshot?.name as string) ?? '—'}
                    </TD>
                    <TD>
                      <Badge tone={statusTone(inv.status as string)}>{humanise(inv.status)}</Badge>
                    </TD>
                    <TD className="tabular text-right font-medium">
                      {fmtMoney(inv.total as number)}
                    </TD>
                    <TD className="text-muted-foreground">{humanise(inv.payment_method)}</TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(inv.invoice_date as string)}
                    </TD>
                    <TD
                      className={`whitespace-nowrap text-right ${late ? 'font-medium text-destructive' : 'text-muted-foreground'}`}
                      title={late ? 'Past its due date and not marked paid' : undefined}
                    >
                      {fmtDate(due)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(inv.sent_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(inv.paid_at as string)}
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
        params={{ q: params.q, status: params.status, payment: params.payment, owner: params.owner }}
      />
    </>
  )
}
