import { Button } from '@/components/ui/button'
import { ThemeToggle } from '@/components/theme-toggle'
import { ROLE_LABEL, ROLE_TONE } from '@/lib/roles'
import type { AdminIdentity } from '@/lib/auth'
import { initials } from '@/lib/format'
import { ENV_NOTE, FIF_ENV, IS_PRODUCTION } from '@/lib/env'
import { cn } from '@/lib/utils'

export function TopBar({ admin }: { admin: AdminIdentity }) {
  return (
    <header
      className={cn(
        'sticky top-0 z-20 flex h-11 shrink-0 items-center justify-between gap-3 border-b px-4 backdrop-blur',
        // Production is tinted rather than merely labelled. The sentence is the
        // thing that explains; the colour is the thing that gets noticed at
        // the moment someone reaches for a destructive button.
        IS_PRODUCTION
          ? 'border-destructive/40 bg-destructive/10'
          : 'border-border bg-background/95',
      )}
    >
      <span
        className={cn(
          'truncate text-[11px]',
          IS_PRODUCTION ? 'font-medium text-destructive' : 'text-muted-foreground',
        )}
      >
        {ENV_NOTE[FIF_ENV]}
      </span>

      <div className="flex shrink-0 items-center gap-2">
        <ThemeToggle />
        <span
          className={cn(
            'inline-flex items-center rounded border px-1.5 py-px text-[10px] font-medium',
            ROLE_TONE[admin.role],
          )}
        >
          {ROLE_LABEL[admin.role]}
        </span>
        <div className="flex items-center gap-1.5">
          <div className="flex h-6 w-6 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold">
            {initials(admin.name, admin.email)}
          </div>
          <span className="hidden text-[11px] text-muted-foreground sm:inline">{admin.email}</span>
        </div>
        <form action="/api/signout" method="post">
          <Button type="submit" variant="ghost" size="sm" className="text-muted-foreground">
            Sign out
          </Button>
        </form>
      </div>
    </header>
  )
}
