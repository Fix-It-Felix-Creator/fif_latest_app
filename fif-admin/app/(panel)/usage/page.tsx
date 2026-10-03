import { requirePermission } from '@/lib/auth'
import { appConfig, listTable, namesFor, subscriptionsFor, PAGE_SIZE } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtNum, humanise } from '@/lib/format'
import { cn } from '@/lib/utils'

export const metadata = { title: 'Plan usage · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/** The counters worth a column. The row has eighteen; a table cannot hold them all. */
const COLUMNS = [
  ['customer_count', 'Clients'],
  ['job_count', 'Jobs'],
  ['quotation_count', 'Quotes'],
  ['invoice_count', 'Invoices'],
  ['staff_count', 'Staff'],
  ['service_count', 'Services'],
  ['photo_upload_count', 'Photos'],
  ['video_upload_count', 'Videos'],
] as const

/** `photo_upload_count` → `photoUploadCount`, which is how the config keys it. */
function toCamel(value: string): string {
  return value.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase())
}

/**
 * What everyone has used, against what their plan allows.
 *
 * The page a "why can't I add another customer" ticket is answered from. The
 * limits come from the `subscriptions` app_config key — the same value the app
 * reads — so this page cannot disagree with the app about what the limit is.
 *
 * Where the config has no limit for a plan, the cell is blank rather than
 * filled with a default: a number here that nothing enforces would send
 * someone chasing a block that does not exist.
 */
export default async function UsagePage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; over?: string }>
}) {
  await requirePermission('readFinance')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const [{ rows, total }, config] = await Promise.all([
    listTable({ table: 'usage_counters', orderBy: 'updated_at', page }),
    appConfig('subscriptions'),
  ])

  const ids = rows.map((r) => r.owner_id as string)
  const [owners, subs] = await Promise.all([namesFor(ids), subscriptionsFor(ids)])

  function limitFor(ownerId: string, counter: string): number | null {
    const sub = subs.get(ownerId)
    const accountType = owners.get(ownerId)?.account_type
    if (!sub || !accountType || !config) return null
    const plan = (config[accountType] as Record<string, unknown> | undefined)?.[sub.plan_type] as
      | Record<string, unknown>
      | undefined
    const limits = plan?.limits as Record<string, unknown> | undefined
    const value = limits?.[toCamel(counter)] ?? limits?.[counter]
    return typeof value === 'number' ? value : null
  }

  const visible =
    params.over === 'yes'
      ? rows.filter((r) =>
          COLUMNS.some(([key]) => {
            const limit = limitFor(r.owner_id as string, key)
            return limit !== null && limit >= 0 && Number(r[key] ?? 0) >= limit
          }),
        )
      : rows

  return (
    <>
      <PageHeader
        title="Plan usage"
        subtitle="Counters against plan limits. Reset on a subscription change, not on a calendar month."
      />

      {!config ? (
        <p className="mb-2 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-[11px] leading-relaxed text-warning">
          The `subscriptions` key is not in app_config on this project, so there are no limits to
          compare against. Usage is still accurate — every cell below is a real count — but nothing
          here can say whether someone is at their ceiling.
        </p>
      ) : null}

      <FilterBar
        filters={[
          {
            param: 'over',
            label: 'At or over a limit',
            current: params.over,
            options: [{ value: 'yes', label: 'Only these' }],
            allLabel: 'Everyone',
          },
        ]}
      />

      {params.over ? (
        <p className="mb-2 text-[11px] text-muted-foreground">
          Worked out per row against each account&apos;s own plan, so this narrows the current page
          of {rows.length} rather than the whole {total.toLocaleString('en-GB')}.
        </p>
      ) : null}

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Account</TH>
              <TH>Plan</TH>
              {COLUMNS.map(([key, label]) => (
                <TH key={key} className="text-right">
                  {label}
                </TH>
              ))}
              <TH className="text-right">Reset</TH>
            </TR>
          </THead>
          <TBody>
            {visible.length === 0 ? (
              <Empty colSpan={COLUMNS.length + 3}>
                {rows.length === 0
                  ? 'No usage rows yet.'
                  : 'Nobody on this page is at a limit — try the next page.'}
              </Empty>
            ) : (
              visible.map((row) => {
                const ownerId = row.owner_id as string
                const sub = subs.get(ownerId)
                return (
                  <TR key={ownerId}>
                    <TD>
                      <OwnerLink id={ownerId} owner={owners.get(ownerId)} />
                    </TD>
                    <TD>
                      {sub ? (
                        <Badge tone={statusTone(sub.status)}>{humanise(sub.plan_type)}</Badge>
                      ) : (
                        <span className="text-[10px] text-muted-foreground">No plan</span>
                      )}
                    </TD>
                    {COLUMNS.map(([key]) => {
                      const used = Number(row[key] ?? 0)
                      const limit = limitFor(ownerId, key)
                      const atLimit = limit !== null && limit >= 0 && used >= limit
                      return (
                        <TD
                          key={key}
                          className={cn(
                            'tabular text-right',
                            atLimit && 'font-medium text-destructive',
                          )}
                          title={limit === null ? 'No limit configured' : `Limit ${limit}`}
                        >
                          {fmtNum(used)}
                          {limit !== null ? (
                            <span className="ml-0.5 text-[10px] text-muted-foreground">
                              /{limit < 0 ? '∞' : limit}
                            </span>
                          ) : null}
                        </TD>
                      )
                    })}
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {row.reset_at ? fmtAgo(row.reset_at as string) : 'Never'}
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager page={page} pageSize={PAGE_SIZE} total={total} params={{ over: params.over }} />

      <Card className="mt-3">
        <CardHeader>
          <CardTitle>The other ten counters</CardTitle>
        </CardHeader>
        <CardBody>
          <p className="text-[11px] leading-relaxed text-muted-foreground">
            A usage row carries eighteen counters and this table shows eight. The rest — addresses,
            templates, applications this month, completed jobs, freelance hires, branches, projects,
            voice seconds, suggestions and leads viewed — are all on each account&apos;s Billing tab,
            with their limits beside them.
          </p>
        </CardBody>
      </Card>
    </>
  )
}
