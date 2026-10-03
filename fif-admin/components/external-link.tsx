import { ArrowUpRight } from 'lucide-react'
import { cn } from '@/lib/utils'

/**
 * A link that leaves the panel.
 *
 * Always a new tab, and always says so — an admin halfway through reviewing a
 * verification should not lose the page they were on to a click.
 * `rel="noopener"` is not optional on a `_blank` target: without it the opened
 * page gets a handle on this one through `window.opener`.
 */
export function ExternalLink({
  href,
  children,
  variant = 'button',
  className,
}: {
  href: string
  children: React.ReactNode
  variant?: 'button' | 'inline'
  className?: string
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={cn(
        variant === 'button'
          ? 'inline-flex h-8 items-center gap-1.5 rounded-md border border-border px-3 text-xs font-medium transition-colors hover:bg-accent'
          : 'inline-flex items-center gap-1 text-primary transition-colors hover:underline',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        className,
      )}
    >
      {children}
      <ArrowUpRight className="h-3 w-3 shrink-0" aria-hidden />
      <span className="sr-only">(opens in a new tab)</span>
    </a>
  )
}
