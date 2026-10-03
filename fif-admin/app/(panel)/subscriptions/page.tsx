import { requirePermission } from '@/lib/auth'
import { countRows, distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { supabaseAdmin } from '@/lib/supabase/server'
import { PageHeader } from '@/components/page-header'
import { Stat } from '@/components/ui/stat'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { FilterBar } from '@/components/filter-bar'
import { SearchBox } from '@/components/search-box'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { ExternalLink } from '@/components/external-link'
import { fmtAgo, fmtDate, fmtMoney, fmtNum, humanise } from '@/lib/format'

export const metadata = { title: 'Subscriptions · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * Subscriptions, read-only by necessity rather than by choice.
 *
 * Billing is native in-app purchase — StoreKit and Play Billing own the
 * entitlement, and there is no server-side cancel or refund to expose. What
 * this page is for is the two questions support actually gets: what does this
 * person's subscription say, and why does it disagree with what they see.
 *
 * The `anomaly=stale` filter answers the second one directly: a row marked
 * active whose period has already ended is a renewal that never arrived, and
 * it is invisible from any single user's page.
 */
export default async function SubscriptionsPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string
    status?: string
    plan?: string
    provider?: string
    anomaly?: string
    page?: string
  }>
}) {
  await requirePermission('readFinance')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1
  const now = new Date().toISOString()

  const [active, trial, cancelled, expired, stale, statuses, plans, providers] = await Promise.all([
    countRows('subscriptions', { status: 'active' }),
    countRows('subscriptions', { status: 'trial' }),
    countRows('subscriptions', { status: 'cancelled' }),
    countRows('subscriptions', { status: 'expired' }),
    supabaseAdmin()
      .from('subscriptions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active')
      .lt('current_period_end', now)
      .then((r) => r.count ?? 0),
    distinctValues('subscriptions', 'status'),
    distinctValues('subscriptions', 'plan_type'),
    distinctValues('subscriptions', 'provider'),
  ])

  let rows: Record<string, unknown>[] = []
  let total = 0

  if (params.anomaly === 'stale') {
    // Its own query: "active but past its period end" is a comparison between
    // two columns and a clock, which the generic filtered reader cannot say.
    const from = (page - 1) * PAGE_SIZE
    const { data, count, error } = await supabaseAdmin()
      .from('subscriptions')
      .select('*', { count: 'exact' })
      .eq('status', 'active')
      .lt('current_period_end', now)
      .order('current_period_end', { ascending: true })
      .range(from, from + PAGE_SIZE - 1)
    if (error) throw new Error(`Loading subscriptions failed: ${error.message}`)
    rows = (data ?? []) as Record<string, unknown>[]
    total = count ?? 0
  } else {
    const result = await listTable({
      table: 'subscriptions',
      orderBy: 'updated_at',
      page,
      filters: {
        status: params.status,
        plan_type: params.plan,
        provider: params.provider,
      },
      searchColumns: [
        'product_id',
        'original_transaction_id',
        'stripe_subscription_id',
        'stripe_customer_id',
      ],
      q: params.q,
    })
    rows = result.rows
    total = result.total
  }

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Subscriptions"
        subtitle="Search matches product id and the store transaction ids a customer can quote from a receipt."
        actions={<SearchBox placeholder="Product or transaction id…" />}
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-5">
        <Stat label="Active" value={fmtNum(active)} tone="success" />
        <Stat label="On trial" value={fmtNum(trial)} tone="info" />
        <Stat label="Cancelled" value={fmtNum(cancelled)} />
        <Stat label="Expired" value={fmtNum(expired)} />
        <Stat
          label="Out of sync"
          value={fmtNum(stale)}
          tone={stale > 0 ? 'danger' : 'default'}
          hint="Active, period ended"
        />
      </div>

      <FilterBar
        filters={[
          { param: 'status', label: 'Status', options: statuses, current: params.status },
          { param: 'plan', label: 'Plan', options: plans, current: params.plan },
          { param: 'provider', label: 'Provider', options: providers, current: params.provider },
          {
            param: 'anomaly',
            label: 'Anomaly',
            current: params.anomaly,
            options: [{ value: 'stale', label: 'Active but expired' }],
            allLabel: 'None',
          },
        ]}
      />

      {params.anomaly === 'stale' ? (
        <p className="mb-2 rounded-lg border border-destructive/40 bg-destructive/10 px-3 py-2 text-[11px] leading-relaxed text-destructive">
          These say active but their period has already ended — a renewal or a store notification
          that never landed. The person may be being served as a subscriber, or blocked as if they
          are not, depending on which check runs first.
        </p>
      ) : null}

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Account</TH>
              <TH>Status</TH>
              <TH>Plan</TH>
              <TH>Cycle</TH>
              <TH>Provider</TH>
              <TH className="text-right">Price</TH>
              <TH>Renews</TH>
              <TH className="text-right">Period start</TH>
              <TH className="text-right">Period end</TH>
              <TH>Product</TH>
              <TH className="text-right">Changed</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={11}>No subscription matches that.</Empty>
            ) : (
              rows.map((s) => {
                const end = s.current_period_end as string | null
                const ended = end != null && new Date(end) < new Date()
                return (
                  <TR key={s.owner_id as string}>
                    <TD>
                      <OwnerLink id={s.owner_id as string} owner={owners.get(s.owner_id as string)} />
                    </TD>
                    <TD>
                      <Badge tone={statusTone(s.status as string)}>{humanise(s.status)}</Badge>
                    </TD>
                    <TD>{humanise(s.plan_type)}</TD>
                    <TD className="text-muted-foreground">{humanise(s.billing_cycle)}</TD>
                    <TD className="text-muted-foreground">{humanise(s.provider)}</TD>
                    <TD className="tabular text-right">{fmtMoney(s.price as number)}</TD>
                    <TD>
                      {s.cancel_at_period_end ? (
                        <Badge tone="warning">Ends at period</Badge>
                      ) : s.auto_renew ? (
                        <Badge tone="success">Auto</Badge>
                      ) : (
                        <Badge tone="muted">No</Badge>
                      )}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDate(s.current_period_start as string)}
                    </TD>
                    <TD
                      className={`whitespace-nowrap text-right ${ended && s.status === 'active' ? 'font-medium text-destructive' : 'text-muted-foreground'}`}
                    >
                      {fmtDate(end)}
                    </TD>
                    <TD className="max-w-[14rem] truncate text-muted-foreground" title={s.product_id as string}>
                      {(s.product_id as string) || '—'}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(s.updated_at as string)}
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
          status: params.status,
          plan: params.plan,
          provider: params.provider,
          anomaly: params.anomaly,
        }}
      />

      <div className="mt-3 flex flex-wrap items-center gap-1.5">
        <span className="text-[11px] text-muted-foreground">
          Refunds and cancellations happen in the stores:
        </span>
        <ExternalLink
          href={process.env.NEXT_PUBLIC_APP_STORE_CONNECT_URL ?? 'https://appstoreconnect.apple.com/apps'}
        >
          App Store Connect
        </ExternalLink>
        <ExternalLink href={process.env.NEXT_PUBLIC_PLAY_CONSOLE_URL ?? 'https://play.google.com/console'}>
          Play Console
        </ExternalLink>
      </div>
    </>
  )
}
