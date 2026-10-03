import { requirePermission } from '@/lib/auth'
import { supabaseAdmin } from '@/lib/supabase/server'
import { namesFor } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import {
  ADMIN_ROLES,
  PERMISSIONS,
  ROLE_BLURB,
  ROLE_LABEL,
  ROLE_TONE,
  can,
  type AdminRole,
} from '@/lib/roles'
import { GrantForm, RevokeButton } from './controls'
import { fmtAgo, fmtDate, humanise, initials } from '@/lib/format'
import { ENV_LABEL, FIF_ENV } from '@/lib/env'
import { cn } from '@/lib/utils'

export const metadata = { title: 'Admin roles · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

type RosterRow = {
  user_id: string
  role: AdminRole
  is_active: boolean
  display_name: string | null
  created_at: string
  updated_at: string | null
  last_seen_at: string | null
}

export default async function AdminsPage() {
  const admin = await requirePermission('manageAdmins')

  const { data, error } = await supabaseAdmin()
    .from('admin_roles')
    .select('user_id, role, is_active, display_name, created_at, updated_at, last_seen_at')
    .order('is_active', { ascending: false })
    .order('created_at', { ascending: true })

  if (error) {
    throw new Error(
      `Loading the roster failed: ${error.message}. If it mentions display_name or last_seen_at, migration 20260914090000_phase9_admin_panel.sql has not been applied to this project.`,
    )
  }

  const rows = (data ?? []) as RosterRow[]
  const people = await namesFor(rows.map((r) => r.user_id))
  const activeSupers = rows.filter((r) => r.is_active && r.role === 'superAdmin').length

  return (
    <>
      <PageHeader
        title="Admin roles"
        subtitle={`Who can open this panel on the ${ENV_LABEL[FIF_ENV].toLowerCase()} project, and how much of it they see.`}
      />

      {activeSupers <= 1 ? (
        <p className="mb-2 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-[11px] leading-relaxed text-warning">
          There is only one active super admin on this project. Nobody can restore their access if
          they lose it, and nobody else can change this roster — a second one is cheap insurance.
        </p>
      ) : null}

      <div className="mb-2">
        <GrantForm />
      </div>

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Person</TH>
              <TH>Role</TH>
              <TH>Access</TH>
              <TH className="text-right">Granted</TH>
              <TH className="text-right">Changed</TH>
              <TH className="text-right">Last signed in</TH>
              <TH className="text-right">Action</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={7}>
                Nobody is on the roster — which cannot be true, because you are reading this. The
                row that let you in is missing its select, or this is a different project.
              </Empty>
            ) : (
              rows.map((row) => {
                const person = people.get(row.user_id)
                const label = row.display_name || person?.name || person?.email || row.user_id
                const isSelf = row.user_id === admin.userId
                return (
                  <TR key={row.user_id} className={row.is_active ? undefined : 'opacity-60'}>
                    <TD>
                      <span className="flex items-center gap-2">
                        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold">
                          {initials(label, person?.email)}
                        </span>
                        <span className="min-w-0">
                          <span className="block max-w-[13rem] truncate font-medium">
                            {label}
                            {isSelf ? (
                              <span className="ml-1 text-[10px] text-muted-foreground">(you)</span>
                            ) : null}
                          </span>
                          <span className="block max-w-[13rem] truncate text-[10px] text-muted-foreground">
                            {person?.email ?? row.user_id}
                          </span>
                        </span>
                      </span>
                    </TD>
                    <TD>
                      <span
                        className={cn(
                          'inline-flex items-center rounded border px-1.5 py-px text-[10px] font-medium',
                          ROLE_TONE[row.role],
                        )}
                      >
                        {ROLE_LABEL[row.role] ?? humanise(row.role)}
                      </span>
                    </TD>
                    <TD>
                      {row.is_active ? (
                        <Badge tone="success">Active</Badge>
                      ) : (
                        <Badge tone="muted">Revoked</Badge>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(row.created_at)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(row.updated_at)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {row.last_seen_at ? fmtAgo(row.last_seen_at) : 'Never here'}
                    </TD>
                    <TD className="text-right">
                      <RevokeButton userId={row.user_id} active={row.is_active} isSelf={isSelf} />
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Card className="mt-3">
        <CardHeader>
          <CardTitle>What each role can do</CardTitle>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <TableWrap className="rounded-none border-0">
            <Table>
              <THead>
                <TR>
                  <TH>Permission</TH>
                  {ADMIN_ROLES.map((r) => (
                    <TH key={r} className="text-center">
                      {ROLE_LABEL[r]}
                    </TH>
                  ))}
                </TR>
              </THead>
              <TBody>
                {PERMISSIONS.map((permission) => (
                  <TR key={permission}>
                    <TD className="font-medium">{humanise(permission)}</TD>
                    {ADMIN_ROLES.map((role) => (
                      <TD key={role} className="text-center">
                        {can(role, permission) ? (
                          <span className="text-success" aria-label="yes">
                            ●
                          </span>
                        ) : (
                          <span className="text-muted-foreground/40" aria-label="no">
                            ·
                          </span>
                        )}
                      </TD>
                    ))}
                  </TR>
                ))}
              </TBody>
            </Table>
          </TableWrap>
          <div className="space-y-1 px-3 py-2">
            {ADMIN_ROLES.map((role) => (
              <p key={role} className="text-[11px] text-muted-foreground">
                <span className="font-medium text-foreground">{ROLE_LABEL[role]}</span> —{' '}
                {ROLE_BLURB[role]}
              </p>
            ))}
            <p className="pt-1 text-[10px] leading-relaxed text-muted-foreground">
              This matrix lives in lib/roles.ts, not in the database — the database stores only the
              role name. Redistributing what a role sees is one edit there. Note that the `api` edge
              function keeps its own narrower check for sending notifications: it accepts super
              admin, admin and support, so a verifier or analyst granted `sendNotification` here
              would still be refused by it.
            </p>
          </div>
        </CardBody>
      </Card>

      <p className="mt-2 text-[11px] leading-relaxed text-muted-foreground">
        Revoking keeps the row and flips it inactive, because the audit log points at it — an entry
        from six months ago should still be able to say who made it and what they were.
      </p>
    </>
  )
}
