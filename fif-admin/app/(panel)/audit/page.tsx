import { requirePermission } from '@/lib/auth'
import { countRows, countSince, distinctValues, listTable, PAGE_SIZE } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Stat } from '@/components/ui/stat'
import { Card, CardBody } from '@/components/ui/card'
import { Badge, statusTone } from '@/components/ui/badge'
import { JsonView } from '@/components/ui/json-view'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { FilterBar } from '@/components/filter-bar'
import { SearchBox } from '@/components/search-box'
import { Pager } from '@/components/pager'
import { fmtDateTime, fmtNum, humanise } from '@/lib/format'

export const metadata = { title: 'Audit log · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * Everything staff have changed.
 *
 * Append-only by construction: nothing in this panel updates or deletes a row
 * here, and `actor_id` is deliberately not a foreign key so that the entry
 * recording a deletion outlives the account it deleted.
 */
export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; action?: string; entity?: string; page?: string }>
}) {
  await requirePermission('viewAudit')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1
  const week = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)

  let rows: Record<string, unknown>[] = []
  let total = 0
  let actions: string[] = []
  let entities: string[] = []
  let all = 0
  let lastWeek = 0
  let missing: string | null = null

  try {
    ;[{ rows, total }, actions, entities, all, lastWeek] = await Promise.all([
      listTable({
        table: 'admin_audit_log',
        orderBy: 'created_at',
        page,
        filters: { action: params.action, entity: params.entity },
        searchColumns: ['actor_email', 'entity_id', 'action'],
        q: params.q,
      }),
      distinctValues('admin_audit_log', 'action'),
      distinctValues('admin_audit_log', 'entity'),
      countRows('admin_audit_log'),
      countSince('admin_audit_log', 'created_at', week),
    ])
  } catch (e) {
    // The table ships in a migration the operator applies on their own
    // schedule. A page that 500s until then says less than one that names
    // the file.
    missing = e instanceof Error ? e.message : String(e)
  }

  if (missing) {
    return (
      <>
        <PageHeader title="Audit log" subtitle="Every change staff have made through this panel." />
        <Card>
          <CardBody className="py-8 text-center">
            <p className="text-xs">The audit table is not on this project yet.</p>
            <p className="mt-2 text-[11px] text-muted-foreground">{missing}</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              Apply <span className="font-medium">20260914090000_phase9_admin_panel.sql</span> and
              this fills in. Until then, actions still succeed — they are just not recorded, and the
              panel says so beside each one.
            </p>
          </CardBody>
        </Card>
      </>
    )
  }

  const actors = new Set(rows.map((r) => r.actor_email as string).filter(Boolean)).size

  return (
    <>
      <PageHeader
        title="Audit log"
        subtitle="Append-only. Search matches the person who acted, the action, and what it was done to."
        actions={<SearchBox placeholder="Email, action, id…" />}
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Stat label="Entries" value={fmtNum(all)} />
        <Stat label="Last 7 days" value={fmtNum(lastWeek)} />
        <Stat label="Distinct actions" value={fmtNum(actions.length)} />
        <Stat label="Staff on this page" value={fmtNum(actors)} />
      </div>

      <FilterBar
        filters={[
          { param: 'action', label: 'Action', options: actions, current: params.action },
          { param: 'entity', label: 'Table', options: entities, current: params.entity },
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>When</TH>
              <TH>Who</TH>
              <TH>Action</TH>
              <TH>Table</TH>
              <TH>Row</TH>
              <TH>Environment</TH>
              <TH>What changed</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={7}>Nothing recorded that matches.</Empty>
            ) : (
              rows.map((r) => (
                <TR key={r.id as string}>
                  <TD className="whitespace-nowrap text-muted-foreground">
                    {fmtDateTime(r.created_at as string)}
                  </TD>
                  <TD className="max-w-[16rem] truncate">{(r.actor_email as string) || '—'}</TD>
                  <TD>
                    <Badge tone={statusTone(String(r.action).split('_').at(-1))}>
                      {humanise(r.action)}
                    </Badge>
                  </TD>
                  <TD className="text-muted-foreground">{(r.entity as string) || '—'}</TD>
                  <TD className="tabular max-w-[16rem] truncate text-muted-foreground">
                    {(r.entity_id as string) || '—'}
                  </TD>
                  <TD>
                    <Badge tone={r.env === 'production' ? 'danger' : 'muted'}>
                      {humanise(r.env)}
                    </Badge>
                  </TD>
                  <TD className="max-w-[24rem]">
                    {r.diff ? (
                      <details>
                        <summary className="cursor-pointer text-[11px] text-muted-foreground transition-colors hover:text-foreground">
                          Before and after
                        </summary>
                        <JsonView value={r.diff} className="mt-1 max-h-72" />
                      </details>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        params={{ q: params.q, action: params.action, entity: params.entity }}
      />
    </>
  )
}
