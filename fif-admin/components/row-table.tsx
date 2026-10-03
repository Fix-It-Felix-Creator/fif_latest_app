import { Badge, statusTone } from '@/components/ui/badge'
import { JsonView } from '@/components/ui/json-view'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { fmtAny, humanise } from '@/lib/format'
import { cn } from '@/lib/utils'

export type Column = {
  key: string
  label: string
  align?: 'left' | 'right'
  badge?: boolean
  render?: (value: unknown, row: Record<string, unknown>) => React.ReactNode
}

/**
 * The panel's workhorse table.
 *
 * `auto` derives columns from the first row's keys — for the small,
 * irregularly-shaped per-owner tables (staff, terms, todos, portfolio) where
 * writing a column list by hand means a dozen near-identical lists that go
 * stale the moment a migration adds a field.
 *
 * `expandKey` names a jsonb column that gets its own full-width row under each
 * record. A customer snapshot or a notification payload is the interesting
 * part of its row and does not fit in a cell; putting it inline keeps it one
 * click from the values it explains rather than on another page.
 */
export function RowTable({
  rows,
  columns,
  empty,
  auto,
  expandKey,
  hideKeys = ['owner_id', 'id'],
}: {
  rows: Record<string, unknown>[]
  columns?: Column[]
  empty: string
  auto?: boolean
  expandKey?: string
  hideKeys?: string[]
}) {
  const cols: Column[] =
    columns ??
    (auto && rows.length
      ? Object.keys(rows[0])
          .filter((key) => !hideKeys.includes(key) && key !== expandKey)
          .map((key) => ({ key, label: humanise(key) }))
      : [])

  const span = cols.length || 1

  return (
    <TableWrap>
      <Table>
        <THead>
          <TR>
            {cols.map((col) => (
              <TH key={col.key} className={col.align === 'right' ? 'text-right' : undefined}>
                {col.label}
              </TH>
            ))}
          </TR>
        </THead>
        <TBody>
          {rows.length === 0 ? (
            <Empty colSpan={span}>{empty}</Empty>
          ) : (
            rows.map((row, i) => {
              const expandable = expandKey ? row[expandKey] : undefined
              return (
                <Rows key={(row.id as string) ?? i}>
                  <TR>
                    {cols.map((col) => {
                      const value = row[col.key]
                      return (
                        <TD
                          key={col.key}
                          className={cn(
                            'max-w-[18rem] truncate',
                            col.align === 'right' && 'tabular text-right',
                          )}
                          title={typeof value === 'string' ? value : undefined}
                        >
                          {col.render ? (
                            col.render(value, row)
                          ) : col.badge ? (
                            value ? (
                              <Badge tone={statusTone(String(value))}>
                                {humanise(String(value))}
                              </Badge>
                            ) : (
                              <span className="text-muted-foreground">—</span>
                            )
                          ) : (
                            fmtAny(value)
                          )}
                        </TD>
                      )
                    })}
                  </TR>
                  {expandable ? (
                    <tr className="border-b border-border/60">
                      <td colSpan={span} className="bg-background/60 px-2.5 pb-2.5">
                        <details>
                          <summary className="cursor-pointer py-1.5 text-[11px] text-muted-foreground transition-colors hover:text-foreground">
                            {humanise(expandKey!)}
                          </summary>
                          <JsonView value={expandable} />
                        </details>
                      </td>
                    </tr>
                  ) : null}
                </Rows>
              )
            })
          )}
        </TBody>
      </Table>
    </TableWrap>
  )
}

/** A keyed fragment — two <tr>s per record and nothing may wrap them. */
function Rows({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
