'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  Bell, BadgeCheck, Contact, CreditCard, FileText, Gauge, HardHat, Inbox, Layers, Link2,
  Radio, Receipt, Scroll, Settings, Shield, Smartphone, UserMinus, Users, Wrench, type LucideIcon,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const ICONS: Record<string, LucideIcon> = {
  badgeCheck: BadgeCheck,
  bell: Bell,
  contact: Contact,
  creditCard: CreditCard,
  fileText: FileText,
  gauge: Gauge,
  gauge2: Gauge,
  layers: Layers,
  hardHat: HardHat,
  inbox: Inbox,
  radio: Radio,
  link: Link2,
  receipt: Receipt,
  scroll: Scroll,
  settings: Settings,
  shield: Shield,
  smartphone: Smartphone,
  userMinus: UserMinus,
  users: Users,
  wrench: Wrench,
  wrench2: Wrench,
}

export function NavLink({ href, icon, label }: { href: string; icon: string; label: string }) {
  const pathname = usePathname()
  // The dashboard is the only exact match — every other section should stay
  // lit while you are three levels down inside it.
  const active = href === '/' ? pathname === '/' : pathname.startsWith(href)
  const Icon = ICONS[icon] ?? Gauge

  return (
    <Link
      href={href}
      aria-current={active ? 'page' : undefined}
      className={cn(
        'flex items-center gap-2 rounded-md px-2 py-1.5 text-xs transition-colors',
        active
          ? 'bg-primary/10 font-medium text-primary'
          : 'text-muted-foreground hover:bg-accent hover:text-foreground',
      )}
    >
      <Icon className="h-3.5 w-3.5 shrink-0" />
      <span className="truncate">{label}</span>
    </Link>
  )
}
