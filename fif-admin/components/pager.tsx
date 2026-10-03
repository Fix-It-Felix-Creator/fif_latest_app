import Link from 'next/link'
import { cn } from '@/lib/utils'

export function Pager({
  page,
  pageSize,
  total,
  params,
}: {
  page: number
  pageSize: number
  total: number
  params: Record<string, string | undefined>
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1
  const to = Math.min(page * pageSize, total)

  function href(target: number) {
    const next = new URLSearchParams()
    Object.entries(params).forEach(([k, v]) => {
      if (v) next.set(k, v)
    })
    next.set('page', String(target))
    return `?${next.toString()}`
  }

  return (
    <div className="mt-2 flex items-center justify-between text-[11px] text-muted-foreground">
      <span className="tabular">
        {from}–{to} of {total.toLocaleString('en-GB')}
      </span>
      <div className="flex items-center gap-1">
        <PageLink href={href(page - 1)} disabled={page <= 1}>
          Previous
        </PageLink>
        <span className="tabular px-1.5">
          {page} / {pages}
        </span>
        <PageLink href={href(page + 1)} disabled={page >= pages}>
          Next
        </PageLink>
      </div>
    </div>
  )
}

function PageLink({
  href,
  disabled,
  children,
}: {
  href: string
  disabled: boolean
  children: React.ReactNode
}) {
  const className = cn(
    'rounded border border-border px-2 py-1 transition-colors',
    disabled ? 'pointer-events-none opacity-40' : 'hover:bg-accent hover:text-foreground',
  )
  // A disabled link is an inert span, not an <a> with a handler swallowing the
  // click: nothing should be focusable that does nothing when activated.
  if (disabled) return <span className={className}>{children}</span>
  return (
    <Link href={href} className={className}>
      {children}
    </Link>
  )
}
