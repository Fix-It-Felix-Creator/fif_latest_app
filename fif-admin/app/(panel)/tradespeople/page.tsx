import Link from 'next/link'
import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { listProfiles, subscriptionsFor, PAGE_SIZE, TRADE_TYPES } from '@/lib/queries'
import { ACCOUNT_TYPE_LABEL, Badge, accountTypeTone, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PageHeader } from '@/components/page-header'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { fmtAgo, fmtDate, fullName, humanise, initials, shortAddress } from '@/lib/format'

export const metadata = { title: 'Tradespeople · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * Everyone on the Pro app.
 *
 * Two account types share this page because they share a product: a business
 * is a tradesperson with a company behind them, and every column below means
 * the same thing for both. Customers get their own page instead of a third
 * filter value — they have no trade, no verification and no subscription, so
 * they would be three-quarters dashes here.
 */
export default async function TradespeoplePage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string
    type?: string
    status?: string
    verification?: string
    page?: string
  }>
}) {
  const admin = await requirePermission('viewTradespeople')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const { rows, total } = await listProfiles({
    types: TRADE_TYPES,
    q: params.q,
    accountType: params.type,
    status: params.status,
    verification: params.verification,
    page,
  })

  const pii = can(admin.role, 'readPii')
  const finance = can(admin.role, 'readFinance')
  const subs = finance ? await subscriptionsFor(rows.map((r) => r.id)) : new Map()

  const columnCount = 7 + (pii ? 1 : 0) + (finance ? 1 : 0)

  return (
    <>
      <PageHeader
        title="Tradespeople"
        subtitle="Sole traders and businesses on the Pro app. Search matches name, email, phone, postcode and company."
        actions={<SearchBox placeholder="Name, email, phone, postcode…" />}
      />

      <FilterBar
        filters={[
          {
            param: 'type',
            label: 'Type',
            current: params.type,
            options: TRADE_TYPES.map((t) => ({ value: t, label: ACCOUNT_TYPE_LABEL[t] })),
            allLabel: 'Both',
          },
          {
            param: 'verification',
            label: 'Verification',
            current: params.verification,
            // Hardcoded here, unlike everywhere else, because these four are a
            // CHECK constraint on the column and a fifth cannot appear without
            // a migration — and "never submitted" is a null, which a distinct
            // scan over the data would never turn up as an option.
            options: ['waiting', 'verified', 'unverified', 'rejected'],
          },
          {
            param: 'status',
            label: 'Account',
            current: params.status,
            options: ['active', 'disabled', 'deletion_pending'],
          },
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Person</TH>
              {pii ? <TH>Contact</TH> : null}
              <TH>Type</TH>
              <TH>Trade</TH>
              <TH>Verification</TH>
              <TH>Account</TH>
              {finance ? <TH>Plan</TH> : null}
              <TH>Where</TH>
              <TH className="text-right">Joined</TH>
              <TH className="text-right">Last change</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={columnCount + 1}>
                Nobody matches that.{' '}
                {params.q ? 'Try a shorter search, or clear the filters.' : ''}
              </Empty>
            ) : (
              rows.map((p) => {
                const name = fullName(p.first_name, p.last_name)
                const trading = p.company_name || p.business_name
                const sub = subs.get(p.id)
                return (
                  <TR key={p.id}>
                    <TD>
                      <Link href={`/tradespeople/${p.id}`} className="group flex items-center gap-2">
                        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-semibold">
                          {initials(name ?? trading, p.email)}
                        </span>
                        <span className="min-w-0">
                          <span className="block max-w-[11rem] truncate font-medium group-hover:text-primary group-hover:underline">
                            {name ?? trading ?? 'Unnamed'}
                          </span>
                          {trading && name ? (
                            <span className="block max-w-[11rem] truncate text-[10px] text-muted-foreground">
                              {trading}
                            </span>
                          ) : null}
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
                      <Badge tone={accountTypeTone(p.account_type)}>
                        {ACCOUNT_TYPE_LABEL[p.account_type] ?? humanise(p.account_type)}
                      </Badge>
                    </TD>
                    <TD className="max-w-[10rem] truncate text-muted-foreground">
                      {humanise(p.trade)}
                    </TD>
                    <TD>
                      {p.verification_status ? (
                        <Badge tone={statusTone(p.verification_status)}>
                          {humanise(p.verification_status)}
                        </Badge>
                      ) : (
                        // Never applied, which is not the same as being turned
                        // down — and the column is nullable precisely so the
                        // two stay distinguishable.
                        <span className="text-[10px] text-muted-foreground">Not submitted</span>
                      )}
                    </TD>
                    <TD>
                      <Badge tone={statusTone(p.account_status)}>
                        {humanise(p.account_status)}
                      </Badge>
                    </TD>
                    {finance ? (
                      <TD>
                        {sub ? (
                          <span className="flex items-center gap-1">
                            <Badge tone={statusTone(sub.status)}>{humanise(sub.plan_type)}</Badge>
                            <span className="text-[10px] text-muted-foreground">
                              {humanise(sub.provider)}
                            </span>
                          </span>
                        ) : (
                          <span className="text-[10px] text-muted-foreground">Never paid</span>
                        )}
                      </TD>
                    ) : null}
                    <TD className="max-w-[12rem] truncate text-muted-foreground">
                      {shortAddress(p)}
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
        params={{
          q: params.q,
          type: params.type,
          status: params.status,
          verification: params.verification,
        }}
      />
    </>
  )
}
