import { cn } from '@/lib/utils'

/**
 * A label/value grid for the "everything we hold about this person" panels.
 *
 * A null value renders as a dash rather than being dropped, because on a
 * profile page the ABSENCE of a value is itself the answer — "this tradesman
 * never gave us a VAT number" and "the column is missing from the query" look
 * identical if empty fields quietly disappear.
 */
export function KV({
  items,
  columns = 2,
  className,
}: {
  items: Array<{ label: string; value: React.ReactNode }>
  columns?: 1 | 2 | 3 | 4
  className?: string
}) {
  const cols = {
    1: 'sm:grid-cols-1',
    2: 'sm:grid-cols-2',
    3: 'sm:grid-cols-3',
    4: 'sm:grid-cols-4',
  }[columns]

  return (
    <dl className={cn('grid grid-cols-1 gap-x-4 gap-y-0', cols, className)}>
      {items.map((item, i) => (
        <div
          key={`${item.label}-${i}`}
          className="flex items-baseline justify-between gap-3 border-b border-border/50 py-1.5 last:border-0"
        >
          <dt className="shrink-0 text-[11px] text-muted-foreground">{item.label}</dt>
          <dd className="tabular min-w-0 truncate text-right text-xs font-medium">
            {item.value ?? <span className="text-muted-foreground">—</span>}
          </dd>
        </div>
      ))}
    </dl>
  )
}
