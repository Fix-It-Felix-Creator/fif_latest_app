import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { countRows } from '@/lib/queries'
import { supabaseAdmin } from '@/lib/supabase/server'
import { PageHeader } from '@/components/page-header'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Stat } from '@/components/ui/stat'
import { Badge } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { PlanEditor, type PlanRow } from './editor'
import { fmtAgo, fmtMoney, fmtNum } from '@/lib/format'

export const metadata = { title: 'Subscription plans · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

const APPS = [
  {
    key: 'tradesman',
    title: 'Fix It Felix Pro — tradespeople',
    blurb: 'Shown on the Pro app paywall. Standard is the only tier the stores currently sell.',
  },
  {
    key: 'business',
    title: 'Fix It Felix Pro — businesses',
    blurb: 'Business accounts use the Pro app. No tiers are defined for them yet.',
  },
  {
    key: 'customer',
    title: 'Fix It Felix — homeowners',
    blurb: 'Shown on the customer app. Nothing charges yet — the customer app has no in-app purchase wiring.',
  },
] as const

/**
 * The plan cards both apps show.
 *
 * The table is the source of truth and a trigger republishes
 * `app_config.subscriptions` on every write, which is the document both apps
 * already read. So a price changed here reaches a phone at its next launch,
 * with no release and no store submission — because the number is display
 * copy. The store owns what anybody is actually charged, which is why the
 * price fields say so and why the IAP product ids sit beside them.
 */
export default async function PlansPage() {
  const admin = await requirePermission('viewPlans')
  const editable = can(admin.role, 'editPlans')

  const [{ data, error }, subscribers] = await Promise.all([
    supabaseAdmin()
      .from('subscription_plans')
      .select('*')
      .order('account_type')
      .order('sort_order'),
    countRows('subscriptions', { status: 'active' }),
  ])

  if (error) {
    throw new Error(
      `Loading plans failed: ${error.message}. If it says the relation does not exist, migration 20260914120000_subscription_plans.sql has not been applied to this project.`,
    )
  }

  const plans = (data ?? []) as PlanRow[]
  const live = plans.filter((p) => p.availability === 'live' && p.is_active)
  const paid = plans.filter((p) => p.monthly_price > 0)
  const sellable = plans.filter((p) => p.product_id_monthly)

  return (
    <>
      <PageHeader
        title="Subscription plans"
        subtitle="What both apps show on their paywalls. Editing a card here changes every install at its next launch."
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Stat label="Plans" value={fmtNum(plans.length)} hint="Across both apps" />
        <Stat label="Live" value={fmtNum(live.length)} tone="success" />
        <Stat label="Paid tiers" value={fmtNum(paid.length)} hint={`${fmtNum(sellable.length)} wired to a store`} />
        <Stat label="Active subscribers" value={fmtNum(subscribers)} />
      </div>

      {/* The gap between "we advertise this" and "a store will take money for
          it" is the thing most likely to produce a support ticket, so it is
          stated once here rather than implied per card. */}
      <Card className="mb-2">
        <CardHeader>
          <CardTitle>What these prices do</CardTitle>
        </CardHeader>
        <CardBody>
          <p className="text-[11px] leading-relaxed text-muted-foreground">
            Nothing here charges anybody. Billing is native in-app purchase, so the real price lives
            in App Store Connect and Play Console and the number on the card is copy that has to be
            kept in step with it by hand. A tier with no product id cannot be bought at all,
            whatever its card says —{' '}
            {sellable.length === 0
              ? 'none currently have one.'
              : `${sellable.map((p) => p.name + ' (' + p.account_type + ')').join(', ')} ${sellable.length === 1 ? 'is the only one that does' : 'are the only ones that do'}.`}
          </p>
        </CardBody>
      </Card>

      {plans.length === 0 ? (
        <Card>
          <CardBody className="py-8 text-center">
            <p className="text-xs text-muted-foreground">
              No plans. They are seeded by migration rather than created here, so an empty table
              means the seed did not run.
            </p>
          </CardBody>
        </Card>
      ) : (
        APPS.map((app) => {
          const group = plans.filter((p) => p.account_type === app.key)
          return (
            <section key={app.key} className="mb-4">
              <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
                <h2 className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                  {app.title}
                </h2>
                <p className="text-[11px] text-muted-foreground">{app.blurb}</p>
              </div>

              {group.length === 0 ? (
                <Card>
                  <CardBody className="py-4">
                    <p className="text-[11px] text-muted-foreground">
                      No tiers defined. The launch campaign covers tradespeople and homeowners only,
                      so nothing was invented here — a business account falls back to the app&apos;s
                      built-in default limits.
                    </p>
                  </CardBody>
                </Card>
              ) : (
                <>
                  <div className="grid gap-2 lg:grid-cols-3">
                    {group.map((plan) => (
                      <PlanEditor key={plan.id} plan={plan} readOnly={!editable} />
                    ))}
                  </div>
                  <Comparison plans={group} />
                </>
              )}
            </section>
          )
        })
      )}
    </>
  )
}

/**
 * The tiers side by side.
 *
 * The cards above are what a customer sees; this is the question staff
 * actually have — what is different between them. Rows are derived from the
 * union of every plan's limit keys, so a limit added to one tier shows up as a
 * dash on the others rather than silently not appearing.
 */
function Comparison({ plans }: { plans: PlanRow[] }) {
  function scoped(plan: PlanRow): Record<string, unknown> {
    if (plan.account_type === 'customer') return plan.customer_limits ?? {}
    if (plan.account_type === 'business') return plan.business_limits ?? {}
    return plan.tradesman_limits ?? {}
  }

  const keys = [
    ...new Set(plans.flatMap((p) => [...Object.keys(p.limits ?? {}), ...Object.keys(scoped(p))])),
  ].sort()

  function value(plan: PlanRow, key: string): React.ReactNode {
    const raw = (plan.limits as Record<string, unknown>)?.[key] ?? scoped(plan)[key]
    if (raw === undefined || raw === null) return <span className="text-muted-foreground">—</span>
    if (typeof raw === 'boolean') return raw ? '✓' : <span className="text-muted-foreground">—</span>
    if (raw === -1) return 'Unlimited'
    if (raw === 0) return <span className="text-muted-foreground">—</span>
    return fmtNum(raw as number)
  }

  return (
    <TableWrap className="mt-2">
      <Table>
        <THead>
          <TR>
            <TH>Limit</TH>
            {plans.map((p) => (
              <TH key={p.id} className="text-right">
                {p.name}
              </TH>
            ))}
          </TR>
        </THead>
        <TBody>
          {keys.length === 0 ? (
            <Empty colSpan={plans.length + 1}>No limits configured on any tier.</Empty>
          ) : (
            keys.map((key) => (
              <TR key={key}>
                <TD className="font-medium">{humaniseLimit(key)}</TD>
                {plans.map((p) => (
                  <TD key={p.id} className="tabular text-right">
                    {value(p, key)}
                  </TD>
                ))}
              </TR>
            ))
          )}
          <TR>
            <TD className="font-medium">Price</TD>
            {plans.map((p) => (
              <TD key={p.id} className="tabular text-right">
                {p.monthly_price === 0 && p.yearly_price === 0 ? (
                  'FREE'
                ) : (
                  <>
                    {fmtMoney(p.monthly_price, p.currency)}/mo
                    {p.yearly_price > 0 ? (
                      <span className="text-muted-foreground">
                        {' · '}
                        {fmtMoney(p.yearly_price, p.currency)}/yr
                      </span>
                    ) : null}
                  </>
                )}
              </TD>
            ))}
          </TR>
          <TR>
            <TD className="font-medium">Transaction fee</TD>
            {plans.map((p) => (
              <TD key={p.id} className="tabular text-right">
                {p.transaction_fee === null ? (
                  <span className="text-muted-foreground">—</span>
                ) : p.transaction_fee === 0 ? (
                  'None'
                ) : (
                  `${p.transaction_fee}%`
                )}
              </TD>
            ))}
          </TR>
          <TR>
            <TD className="font-medium">Buyable</TD>
            {plans.map((p) => (
              <TD key={p.id} className="text-right">
                {p.product_id_monthly ? (
                  <Badge tone="success">In store</Badge>
                ) : (
                  <Badge tone="muted">No product id</Badge>
                )}
              </TD>
            ))}
          </TR>
          <TR>
            <TD className="font-medium">Last changed</TD>
            {plans.map((p) => (
              <TD key={p.id} className="text-right text-muted-foreground">
                {fmtAgo(p.updated_at)}
              </TD>
            ))}
          </TR>
        </TBody>
      </Table>
    </TableWrap>
  )
}

/** `maxPhotoUploads` → `Max photo uploads`, without the generic humanise's title casing. */
function humaniseLimit(key: string): string {
  const words = key.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/[_-]+/g, ' ').toLowerCase()
  return words.charAt(0).toUpperCase() + words.slice(1)
}
