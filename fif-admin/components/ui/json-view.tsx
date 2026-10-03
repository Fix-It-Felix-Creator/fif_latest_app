import { cn } from '@/lib/utils'

/**
 * Raw jsonb, shown as itself.
 *
 * `profiles.details`, `subscriptions.metadata`, a quote's `customer_snapshot`
 * and a notification's `payload` are all free-form documents whose shape
 * differs per row. A pretty renderer for one of them would be a second
 * implementation of a schema nobody wrote down, silently dropping any key it
 * did not know. The panel shows the parts it understands in real widgets AND
 * keeps the whole document here, so nothing is invisible.
 */
export function JsonView({ value, className }: { value: unknown; className?: string }) {
  if (value === null || value === undefined) {
    return <p className="text-xs text-muted-foreground">Nothing stored.</p>
  }
  return (
    <pre
      className={cn(
        'scroll-thin max-h-[32rem] overflow-auto rounded-md border border-border bg-background p-2.5 text-[11px] leading-relaxed',
        className,
      )}
    >
      {JSON.stringify(value, null, 2)}
    </pre>
  )
}
