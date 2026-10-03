import { NAV, NAV_GROUPS } from '@/lib/nav'
import { can, type AdminRole } from '@/lib/roles'
import { NavLink } from '@/components/nav-link'
import { ENV_LABEL, FIF_ENV, IS_PRODUCTION, projectRef } from '@/lib/env'
import { cn } from '@/lib/utils'

export function Sidebar({ role }: { role: AdminRole }) {
  const visible = NAV.filter((item) => can(role, item.permission))

  return (
    <aside className="sticky top-0 hidden h-screen w-52 shrink-0 flex-col border-r border-border bg-card md:flex">
      <div className="flex items-center gap-2 px-3 py-3">
        <div className="flex h-7 w-7 items-center justify-center rounded bg-primary text-xs font-bold text-primary-foreground">
          F
        </div>
        <span className="text-xs font-semibold">Fix It Felix Admin</span>
      </div>

      <nav className="scroll-thin flex-1 overflow-y-auto px-2 pb-4">
        {NAV_GROUPS.map((group) => {
          const items = visible.filter((item) => item.group === group)
          if (!items.length) return null
          return (
            <div key={group} className="mb-3">
              <div className="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                {group}
              </div>
              <ul className="space-y-px">
                {items.map((item) => (
                  <li key={item.href}>
                    <NavLink href={item.href} icon={item.icon} label={item.label} />
                  </li>
                ))}
              </ul>
            </div>
          )
        })}
      </nav>

      {/* Which database is behind every number on screen. Staging and
          production are separate Supabase projects, and someone with both open
          needs to be able to tell the tabs apart without clicking anything. */}
      <div className="border-t border-border px-3 py-2">
        <div className={cn('text-[10px] font-medium', IS_PRODUCTION ? 'text-destructive' : 'text-muted-foreground')}>
          {ENV_LABEL[FIF_ENV]}
        </div>
        <div className="truncate text-[10px] text-muted-foreground">Supabase · {projectRef()}</div>
      </div>
    </aside>
  )
}
