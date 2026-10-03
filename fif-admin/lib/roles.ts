/**
 * What each admin role may do.
 *
 * The DATABASE stores only the role, in `admin_roles`. This file is the matrix
 * that turns a role into permissions, and it is deliberately the only place
 * that mapping exists — redistributing what a verifier or a support agent may
 * see is then one edit here, not a hunt through pages.
 *
 * The five roles come from the panel spec (docs/admin-panel-dashboard-spec.md
 * §4.2). `admin` and `superAdmin` predate it: they are what `admin_roles`
 * already held and what the `api` edge function's own isAdmin() checks, so
 * they keep their exact meaning and existing rows keep working.
 */

export const ADMIN_ROLES = ['superAdmin', 'admin', 'support', 'verifier', 'analyst'] as const

export type AdminRole = (typeof ADMIN_ROLES)[number]

export const ROLE_LABEL: Record<AdminRole, string> = {
  superAdmin: 'Super admin',
  admin: 'Admin',
  support: 'Support',
  verifier: 'Verifier',
  analyst: 'Analyst',
}

export const ROLE_BLURB: Record<AdminRole, string> = {
  superAdmin: 'Everything, including who else gets in and what the apps are configured with.',
  admin: 'Everything except handing out roles, app config, plan cards or service flows.',
  support: 'Look someone up, fix their account, send them a notification. No broadcasts.',
  verifier: 'The verification queue and nothing else.',
  analyst: 'Dashboards and aggregates. No route to one person.',
}

/**
 * One permission per thing worth withholding.
 *
 * `readPii` is separate from `viewTradespeople` on purpose: a verifier needs
 * to see someone's identity document to do their job and has no business
 * reading that person's bank details or invoice history. Splitting them is the
 * whole reason this is a matrix rather than a rank.
 */
export const PERMISSIONS = [
  'viewDashboard',
  'viewTradespeople',
  'viewCustomers',
  'readPii', // email, phone, address, bank — who this person is
  'readFinance', // subscriptions, invoices, quotes, money
  'viewWork', // jobs, quotes, invoices, shares, client book
  'viewJobRequests', // what customers posted, and who it reached
  'reviewLeadApplications', // approve or reject a tradesperson for live leads
  // Overriding one person's verification_status from their detail page. The
  // standalone queue this was written for is gone — identity is now decided
  // as part of a leads application, which is the only place documents are
  // ever collected. This remains for the support case: correcting a status by
  // hand without a new application.
  'reviewVerification',
  'manageAccount', // disable, re-enable, force deletion, recover
  'sendNotification', // to named recipients
  'broadcastNotification', // to everyone at once
  'viewDevices',
  'viewPlans', // the subscription cards both apps show
  'editPlans', // ...and changing what they say
  'viewServices', // the trade catalogue and its question flows
  'editServices', // ...and changing what a customer is asked
  'viewConfig',
  'writeConfig', // what the apps read at launch — maintenance, force-update
  'viewAudit',
  'manageAdmins',
] as const

export type Permission = (typeof PERMISSIONS)[number]

const ALL: Permission[] = [...PERMISSIONS]

export const ROLE_PERMISSIONS: Record<AdminRole, readonly Permission[]> = {
  superAdmin: ALL,
  // An admin runs the platform but does not decide who else runs it, and does
  // not change what every installed copy of both apps reads at launch — a bad
  // `force_app_update` or a stuck maintenance flag locks out every user at
  // once, which is a different size of mistake to anything else on this list.
  // editPlans sits with writeConfig for the same reason: a plan card is what
  // every installed copy of both apps shows on its paywall, and a wrong price
  // there is a wrong price everywhere at once.
  admin: ALL.filter(
    (p) =>
      p !== 'manageAdmins' &&
      p !== 'writeConfig' &&
      p !== 'editPlans' &&
      p !== 'editServices',
  ),
  // Spec §4.2: support answers tickets. That needs the person, their account
  // state and a way to message them — not a broadcast, and not the books.
  support: [
    'viewDashboard',
    'viewTradespeople',
    'viewCustomers',
    'readPii',
    'viewWork',
    'viewJobRequests',
    'reviewVerification',
    'reviewLeadApplications',
    'manageAccount',
    'sendNotification',
    'viewDevices',
    'viewPlans',
    'viewServices',
    'viewConfig',
  ],
  // The narrowest role in the spec, and the highest-volume one. A verifier
  // sees identity documents all day; giving them the invoice ledger as well
  // would be handing out far more than the job needs.
  // A verifier reviews identity all day. A leads application is the same kind
  // of decision — check a document against a register, approve or explain —
  // so it belongs to the same role rather than to a new one.
  verifier: [
    'viewDashboard',
    'reviewVerification',
    'reviewLeadApplications',
    'readPii',
  ],
  // No route to one person at all. An analyst who can open a profile is not
  // an analyst — the aggregate pages are the whole job.
  analyst: [
    'viewDashboard',
    'readFinance',
    'viewPlans',
    'viewServices',
    // Volume and reach, not the address on any one of them — readPii is what
    // that would need, and an analyst does not have it.
    'viewJobRequests',
    'viewAudit',
  ],
}

export function can(role: AdminRole | null, permission: Permission): boolean {
  if (!role) return false
  return ROLE_PERMISSIONS[role].includes(permission)
}

export const ROLE_TONE: Record<AdminRole, string> = {
  superAdmin: 'text-primary border-primary/40 bg-primary/10',
  admin: 'text-foreground border-border bg-secondary',
  support: 'text-info border-info/40 bg-info/10',
  verifier: 'text-success border-success/40 bg-success/10',
  analyst: 'text-warning border-warning/40 bg-warning/10',
}

/**
 * The roles the `api` edge function's own isAdmin() lets through.
 *
 * Push notifications are sent by that function, not by this panel — it holds
 * the FCM service account and the stale-token cleanup. So a role can only
 * really send if BOTH this matrix and that function agree, and a mismatch
 * shows up as a 403 from a button that rendered. Naming the overlap here lets
 * the compose screen say so before anyone clicks.
 */
export const API_SEND_ROLES: readonly AdminRole[] = ['superAdmin', 'admin', 'support']
