import { requirePermission } from '@/lib/auth'
import { listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtDate, shortAddress } from '@/lib/format'

export const metadata = { title: 'Client book · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * The `customers` table — which is not the customers page.
 *
 * These are address-book entries a tradesperson typed in or imported from
 * their phone. Nobody signs in as one, they have no account and no app: they
 * exist so a quote can carry a name. The customer-app accounts are under
 * People → Customers, and the two have no relationship in the schema at all.
 */
export default async function ClientBookPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; owner?: string; page?: string }>
}) {
  await requirePermission('viewWork')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const { rows, total } = await listTable({
    table: 'customers',
    orderBy: 'created_at',
    page,
    filters: { owner_id: params.owner },
    searchColumns: ['name', 'email', 'phone', 'company', 'postcode'],
    q: params.q,
  })

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Client book"
        subtitle="Contacts saved by tradespeople. Not customer-app accounts — nobody signs in as one of these."
        actions={<SearchBox placeholder="Name, email, phone, company…" />}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Name</TH>
              <TH>Company</TH>
              <TH>Email</TH>
              <TH>Phone</TH>
              <TH>Address</TH>
              <TH>Saved by</TH>
              <TH className="text-right">Added</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={7}>No contacts match that.</Empty>
            ) : (
              rows.map((c) => (
                <TR key={c.id as string}>
                  <TD className="max-w-[12rem] truncate font-medium">{(c.name as string) || '—'}</TD>
                  <TD className="max-w-[11rem] truncate text-muted-foreground">
                    {(c.company as string) || '—'}
                  </TD>
                  <TD className="max-w-[14rem] truncate text-muted-foreground">
                    {(c.email as string) || '—'}
                  </TD>
                  <TD className="tabular text-muted-foreground">{(c.phone as string) || '—'}</TD>
                  <TD className="max-w-[16rem] truncate text-muted-foreground">
                    {shortAddress(c as Record<string, string | null>)}
                  </TD>
                  <TD>
                    <OwnerLink id={c.owner_id as string} owner={owners.get(c.owner_id as string)} />
                  </TD>
                  <TD className="whitespace-nowrap text-right text-muted-foreground">
                    {fmtDate(c.created_at as string)}
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager page={page} pageSize={PAGE_SIZE} total={total} params={{ q: params.q, owner: params.owner }} />
    </>
  )
}
