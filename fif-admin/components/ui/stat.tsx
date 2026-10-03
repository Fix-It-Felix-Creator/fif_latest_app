import { cn } from '@/lib/utils'

/**
 * One number, its name, and optionally what it is a share of.
 *
 * Small on purpose — eight of these across one row say more than three hero
 * tiles, and the brief for this panel is more data per screen.
 */
export function Stat({
  label,
  value,
  hint,
  tone,
  className,
}: {
  label: string
  value: React.ReactNode
  hint?: React.ReactNode
  tone?: 'default' | 'primary' | 'success' | 'warning' | 'danger' | 'info'
  className?: string
}) {
  const toneClass = {
    default: 'text-foreground',
    primary: 'text-primary',
    success: 'text-success',
    warning: 'text-warning',
    danger: 'text-destructive',
    info: 'text-info',
  }[tone ?? 'default']

  return (
    <div className={cn('rounded-sm border border-border bg-card px-3 py-2', className)}>
      <div className="truncate text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </div>
      <div className={cn('tabular mt-0.5 text-xl font-semibold leading-tight', toneClass)}>
        {value}
      </div>
      {hint ? <div className="mt-0.5 truncate text-[10px] text-muted-foreground">{hint}</div> : null}
    </div>
  )
}
