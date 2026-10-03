import Link from 'next/link'
import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { listProfiles, PAGE_SIZE } from '@/lib/queries'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { fmtAgo, fmtDate, fullName, humanise, initials, shortAddress } from '@/lib/format'

export const metadata = { title: 'Customers · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

const CUSTOMER_TYPES = ['customer'] as const

/**
 * Everyone on the customer app.
 *
 * A deliberately narrow page, and it should stay narrow. The customer app is
 * early: it signs someone in, collects a name, a phone number and an address,
 * and shows them a home screen. There is no trade, no verification file, no
 * subscription and no ledger — so the columns that carry the tradespeople page
 * are absent here rather than present and empty.
 *
 * What there IS worth showing is the onboarding funnel: a customer who
 * authenticated but never finished giving their details is the one support
 * case this list exists to surface, and it is visible as a missing name or a
 * missing address rather than as a status column, because nothing records it
 * as a status.
 */
export default async function CustomersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; onboarding?: string; page?: string }>
}) {
  const admin = await requirePermission('viewCustomers')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const { rows, total } = await listProfiles({
    types: CUSTOMER_TYPES,
    q: params.q,
    status: params.status,
    page,
  })

  const pii = can(admin.role, 'readPii')

  // Filtered after the query rather than in it: "has no address" is the
  // absence of four different columns, which PostgREST cannot express as one
  // filter, and the alternative is a computed column nothing else needs.
  const visible =
    params.onboarding === 'incomplete'
      ? rows.filter((p) => !fullName(p.first_name, p.last_name) || !p.postcode)
      : params.onboarding === 'complete'
        ? rows.filter((p) => fullName(p.first_name, p.last_name) && p.postcode)
        : rows

  const columnCount = pii ? 8 : 7

  return (
    <>
      <PageHeader
        title="Customers"
        subtitle="Accounts on the customer app. Search matches name, email, phone and postcode."
        actions={<SearchBox placeholder="Name, email, phone, postcode…" />}
      />

      <FilterBar
        filters={[
          {
            param: 'status',
            label: 'Account',
            current: params.status,
            options: ['active', 'disabled', 'deletion_pending'],
          },
          {
            param: 'onboarding',
            label: 'Onboarding',
            current: params.onboarding,
            options: [
              { value: 'complete', label: 'Finished' },
              { value: 'incomplete', label: 'Signed up, never finished' },
            ],
            allLabel: 'Any',
          },
        ]}
      />

      {params.onboarding ? (
        <p className="mb-2 text-[11px] text-muted-foreground">
          Onboarding is worked out from the row rather than stored, so this filter narrows the
          current page of {rows.length} — not the whole {total.toLocaleString('en-GB')}.
        </p>
      ) : null}

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Customer</TH>
              {pii ? <TH>Contact</TH> : null}
              <TH>Account</TH>
              <TH>Address</TH>
              <TH>Onboarding</TH>
              <TH>Reachable</TH>
              <TH className="text-right">Joined</TH>
              <TH className="text-right">Last change</TH>
            </TR>
          </THead>
          <TBody>
            {visible.length === 0 ? (
              <Empty colSpan={columnCount}>
                {rows.length === 0
                  ? 'No customer accounts match that.'
                  : 'Nobody on this page matches that filter — try the next page.'}
              </Empty>
            ) : (
              visible.map((p) => {
                const name = fullName(p.first_name, p.last_name)
                const address = shortAddress(p)
                const done = Boolean(name && p.postcode)
                return (
                  <TR key={p.id}>
                    <TD>
                      <Link href={`/customers/${p.id}`} className="group flex items-center gap-2">
                        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold">
                          {initials(name, p.email)}
                        </span>
                        <span className="max-w-[12rem] truncate font-medium group-hover:text-primary group-hover:underline">
                          {name ?? 'No name yet'}
                        </span>
                      </Link>
                    </TD>
                    {pii ? (
                      <TD className="max-w-[15rem]">
                        <span className="block truncate text-muted-foreground">
                          {p.email || '—'}
                        </span>
                        {p.phone ? (
                          <span className="tabular block truncate text-[10px] text-muted-foreground">
                            {p.phone}
                          </span>
                        ) : null}
                      </TD>
                    ) : null}
                    <TD>
                      <Badge tone={statusTone(p.account_status)}>
                        {humanise(p.account_status)}
                      </Badge>
                    </TD>
                    <TD className="max-w-[16rem] truncate text-muted-foreground" title={address}>
                      {address}
                    </TD>
                    <TD>
                      {done ? (
                        <Badge tone="success">Finished</Badge>
                      ) : (
                        <Badge tone="warning">
                          {!name && !p.postcode ? 'Nothing given' : !name ? 'No name' : 'No address'}
                        </Badge>
                      )}
                    </TD>
                    <TD>
                      {/* Three separate booleans on the profile, and a
                          customer with all three off cannot be contacted by
                          the app at all — worth seeing in a list rather than
                          only on the detail page. */}
                      <span className="flex items-center gap-1 text-[10px] text-muted-foreground">
                        <Channel on={p.push_enabled} label="Push" />
                        <Channel on={p.email_enabled} label="Email" />
                        <Channel on={p.sms_enabled} label="SMS" />
                      </span>
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(p.created_at)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(p.updated_at)}
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        params={{ q: params.q, status: params.status, onboarding: params.onboarding }}
      />
    </>
  )
}

function Channel({ on, label }: { on: boolean; label: string }) {
  return (
    <span className={on ? 'text-foreground' : 'text-muted-foreground line-through'}>{label}</span>
  )
}
