import { requirePermission } from '@/lib/auth'
import { listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDate, humanise } from '@/lib/format'

export const metadata = { title: 'Share links · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * The public quote and invoice links.
 *
 * This is the page a "my customer says the link is broken" ticket is answered
 * from: paste the token, see whether the row exists, whether it was revoked,
 * and whether the document behind it still does.
 */
export default async function SharesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; kind?: string; state?: string; page?: string }>
}) {
  await requirePermission('viewWork')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const notNull: string[] = []
  if (params.state === 'viewed') notNull.push('viewed_at')
  if (params.state === 'responded') notNull.push('responded_at')
  if (params.state === 'revoked') notNull.push('deleted_at')
  if (params.kind === 'quote') notNull.push('quote_id')
  if (params.kind === 'invoice') notNull.push('invoice_id')

  const { rows, total } = await listTable({
    table: 'document_shares',
    orderBy: 'created_at',
    page,
    searchColumns: ['token'],
    q: params.q,
    notNull,
    filters: params.state === 'accepted' || params.state === 'rejected'
      ? { responded_action: params.state }
      : undefined,
  })

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Share links"
        subtitle="Every public /q/ and /i/ link. Paste a token from a customer's email to find what it points at."
        actions={<SearchBox placeholder="Token…" />}
      />

      <FilterBar
        filters={[
          {
            param: 'kind',
            label: 'Document',
            current: params.kind,
            options: [
              { value: 'quote', label: 'Quotes' },
              { value: 'invoice', label: 'Invoices' },
            ],
          },
          {
            param: 'state',
            label: 'State',
            current: params.state,
            options: [
              { value: 'viewed', label: 'Opened' },
              { value: 'responded', label: 'Answered' },
              { value: 'accepted', label: 'Accepted' },
              { value: 'rejected', label: 'Rejected' },
              { value: 'revoked', label: 'Revoked' },
            ],
          },
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Token</TH>
              <TH>Points at</TH>
              <TH>Tradesperson</TH>
              <TH className="text-right">Created</TH>
              <TH className="text-right">Opened</TH>
              <TH className="text-right">Answered</TH>
              <TH>Answer</TH>
              <TH className="text-right">Revoked</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={8}>
                No link matches that. A token that is genuinely missing means the share row was
                deleted outright, not revoked.
              </Empty>
            ) : (
              rows.map((s) => {
                const dead = !s.quote_id && !s.invoice_id
                return (
                  <TR key={s.token as string}>
                    <TD className="tabular max-w-[14rem] truncate" title={s.token as string}>
                      {s.token as string}
                    </TD>
                    <TD>
                      {s.quote_id ? (
                        <Badge tone="info">Quote</Badge>
                      ) : s.invoice_id ? (
                        <Badge tone="primary">Invoice</Badge>
                      ) : (
                        // The tombstone the Phase 5 migration keeps on purpose,
                        // so a link already in an inbox can be answered with
                        // "that document was deleted" rather than a 404.
                        <Badge tone="danger">Document deleted</Badge>
                      )}
                    </TD>
                    <TD>
                      <OwnerLink id={s.owner_id as string} owner={owners.get(s.owner_id as string)} />
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(s.created_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(s.viewed_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(s.responded_at as string)}
                    </TD>
                    <TD>
                      {s.responded_action ? (
                        <Badge tone={statusTone(s.responded_action as string)}>
                          {humanise(s.responded_action)}
                        </Badge>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TD>
                    <TD
                      className={`whitespace-nowrap text-right ${dead || s.deleted_at ? 'text-destructive' : 'text-muted-foreground'}`}
                    >
                      {fmtAgo(s.deleted_at as string)}
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
        params={{ q: params.q, kind: params.kind, state: params.state }}
      />
    </>
  )
}
