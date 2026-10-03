import type { Permission } from '@/lib/roles'

export type NavItem = {
  href: string
  label: string
  icon: string
  permission: Permission
  group: (typeof NAV_GROUPS)[number]
}

export const NAV_GROUPS = ['Overview', 'People', 'Work', 'Catalogue', 'Money', 'Operations'] as const

/**
 * The whole sidebar, as data.
 *
 * Each entry carries the permission that reveals it, so hiding a section from
 * a role is a matrix edit in roles.ts and nothing else — no page learns about
 * roles, and no link can be shown to someone the page would then redirect.
 *
 * Tradespeople and customers are two entries rather than one list with a
 * filter. They are two different products: a tradesperson has a business, a
 * subscription, a verification file and a ledger, and a customer has a name,
 * an address and a phone. One table that fits both would be mostly dashes.
 */
export const NAV: NavItem[] = [
  { href: '/', label: 'Dashboard', icon: 'gauge', permission: 'viewDashboard', group: 'Overview' },

  { href: '/tradespeople', label: 'Tradespeople', icon: 'hardHat', permission: 'viewTradespeople', group: 'People' },
  { href: '/customers', label: 'Customers', icon: 'users', permission: 'viewCustomers', group: 'People' },
  // One queue, because it is one journey.
  //
  // Verification and leads approval remain two decisions with different
  // evidence — a passport is not an insurance certificate — but they are
  // SEQUENTIAL: an unverified account cannot be approved for leads at all.
  // Two lists made staff hold that sequence in their heads and check two
  // pages to answer "where is this person up to". The app shows it as one
  // card walking one path; this is the same path from the other side.
  { href: '/approvals', label: 'Approvals', icon: 'badgeCheck', permission: 'reviewVerification', group: 'People' },
  { href: '/deletions', label: 'Deletions', icon: 'userMinus', permission: 'manageAccount', group: 'People' },

  // What a homeowner posted, before any tradesperson has it. Above /jobs
  // because it comes first in life: a request becomes a job only once someone
  // accepts it, and a request nobody accepted never becomes one at all.
  { href: '/job-requests', label: 'Job requests', icon: 'inbox', permission: 'viewJobRequests', group: 'Work' },
  { href: '/jobs', label: 'Jobs', icon: 'wrench', permission: 'viewWork', group: 'Work' },
  { href: '/quotes', label: 'Quotes', icon: 'fileText', permission: 'viewWork', group: 'Work' },
  { href: '/invoices', label: 'Invoices', icon: 'receipt', permission: 'viewWork', group: 'Work' },
  { href: '/shares', label: 'Share links', icon: 'link', permission: 'viewWork', group: 'Work' },
  // The tradesperson's own address book. Named so it cannot be mistaken for
  // the customer-app accounts one group up — they are unrelated tables.
  { href: '/client-book', label: 'Client book', icon: 'contact', permission: 'viewWork', group: 'Work' },

  // What a customer picks from, and the questions each pick asks. Its own
  // group: a service is neither a person nor a piece of work — it is the
  // catalogue both apps are built around.
  { href: '/services', label: 'Services', icon: 'wrench2', permission: 'viewServices', group: 'Catalogue' },

  { href: '/subscriptions', label: 'Subscriptions', icon: 'creditCard', permission: 'readFinance', group: 'Money' },
  { href: '/usage', label: 'Plan usage', icon: 'gauge2', permission: 'readFinance', group: 'Money' },
  // What the apps' paywalls show. Above usage in meaning — usage is measured
  // against whatever this page says the limits are.
  { href: '/plans', label: 'Subscription plans', icon: 'layers', permission: 'viewPlans', group: 'Money' },

  { href: '/notifications', label: 'Notifications', icon: 'bell', permission: 'sendNotification', group: 'Operations' },
  { href: '/devices', label: 'Devices', icon: 'smartphone', permission: 'viewDevices', group: 'Operations' },
  { href: '/config', label: 'App config', icon: 'settings', permission: 'viewConfig', group: 'Operations' },
  { href: '/audit', label: 'Audit log', icon: 'scroll', permission: 'viewAudit', group: 'Operations' },
  { href: '/admins', label: 'Admin roles', icon: 'shield', permission: 'manageAdmins', group: 'Operations' },
]
