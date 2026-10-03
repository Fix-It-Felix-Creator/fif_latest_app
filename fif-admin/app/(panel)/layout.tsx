import { requireAdmin } from '@/lib/auth'
import { Sidebar } from '@/components/sidebar'
import { TopBar } from '@/components/top-bar'

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const admin = await requireAdmin()

  return (
    <div className="flex min-h-screen">
      <Sidebar role={admin.role} />
      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar admin={admin} />
        {/* No max-width. The brief is more data per screen, and a centred
            measure would waste a third of a wide monitor on margins. */}
        <main className="min-w-0 flex-1 px-4 py-4">{children}</main>
      </div>
    </div>
  )
}
