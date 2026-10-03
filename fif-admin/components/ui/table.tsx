import { cn } from '@/lib/utils'

/**
 * A dense table. Every size here is one step smaller than shadcn's default:
 * this panel exists to put as many real rows on screen at once as will fit,
 * and comfortable row padding costs about a third of them.
 */
export function TableWrap({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      className={cn(
        'scroll-thin w-full overflow-x-auto rounded-sm border border-border bg-card',
        className,
      )}
      {...props}
    />
  )
}

export function Table({ className, ...props }: React.ComponentProps<'table'>) {
  return <table className={cn('w-full caption-bottom text-xs', className)} {...props} />
}

export function THead({ className, ...props }: React.ComponentProps<'thead'>) {
  return (
    <thead
      className={cn('sticky top-0 z-10 bg-card [&_tr]:border-b [&_tr]:border-border', className)}
      {...props}
    />
  )
}

export function TBody({ className, ...props }: React.ComponentProps<'tbody'>) {
  return <tbody className={cn('[&_tr:last-child]:border-0', className)} {...props} />
}

export function TR({ className, ...props }: React.ComponentProps<'tr'>) {
  return (
    <tr
      className={cn('border-b border-border/60 transition-colors hover:bg-accent/50', className)}
      {...props}
    />
  )
}

export function TH({ className, ...props }: React.ComponentProps<'th'>) {
  return (
    <th
      className={cn(
        'whitespace-nowrap px-2.5 py-1.5 text-left text-[10px] font-semibold uppercase tracking-wider text-muted-foreground',
        className,
      )}
      {...props}
    />
  )
}

export function TD({ className, ...props }: React.ComponentProps<'td'>) {
  return <td className={cn('px-2.5 py-1.5 align-middle', className)} {...props} />
}

export function Empty({ colSpan, children }: { colSpan: number; children: React.ReactNode }) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-2.5 py-8 text-center text-xs text-muted-foreground">
        {children}
      </td>
    </tr>
  )
}
