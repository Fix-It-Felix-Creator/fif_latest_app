import Link from 'next/link'
import { cn } from '@/lib/utils'

/**
 * Tabs as links, not state.
 *
 * A tab on a tradesperson's page is a place — "look at this person's invoices"
 * is a thing you send to a colleague. Keeping it in the URL makes every tab
 * linkable, survives a refresh, and lets the server fetch only the tab being
 * looked at instead of all thirteen.
 */
export function Tabs({
  tabs,
  current,
  basePath,
  param = 'tab',
}: {
  tabs: Array<{ key: string; label: string; count?: number | null }>
  current: string
  basePath: string
  param?: string
}) {
  return (
    <div className="scroll-thin mb-3 flex gap-px overflow-x-auto border-b border-border">
      {tabs.map((tab) => {
        const active = tab.key === current
        return (
          <Link
            key={tab.key}
            href={`${basePath}?${param}=${tab.key}`}
            aria-current={active ? 'page' : undefined}
            className={cn(
              'flex shrink-0 items-center gap-1.5 border-b-2 px-3 py-1.5 text-xs transition-colors',
              active
                ? 'border-primary font-medium text-foreground'
                : 'border-transparent text-muted-foreground hover:text-foreground',
            )}
          >
            {tab.label}
            {typeof tab.count === 'number' ? (
              <span className="tabular rounded bg-secondary px-1 text-[10px] text-muted-foreground">
                {tab.count}
              </span>
            ) : null}
          </Link>
        )
      })}
    </div>
  )
}
