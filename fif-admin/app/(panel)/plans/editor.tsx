'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { SidePanel } from '@/components/side-panel'
import { savePlan, type PlanInput } from './actions'
import { fmtMoney } from '@/lib/format'

export type PlanRow = {
  id: string
  account_type: string
  plan_type: string
  name: string
  tagline: string | null
  description: string
  features: string[]
  currency: string
  monthly_price: number
  yearly_price: number
  availability: string
  badge: string | null
  is_featured: boolean
  is_active: boolean
  sort_order: number
  trial_days: number
  transaction_fee: number | null
  limits: Record<string, unknown>
  tradesman_limits: Record<string, unknown> | null
  business_limits: Record<string, unknown> | null
  customer_limits: Record<string, unknown> | null
  product_id_monthly: string | null
  product_id_yearly: string | null
  updated_at: string | null
}

function scopedLimits(plan: PlanRow): Record<string, unknown> {
  if (plan.account_type === 'customer') return plan.customer_limits ?? {}
  if (plan.account_type === 'business') return plan.business_limits ?? {}
  return plan.tradesman_limits ?? {}
}

function initial(plan: PlanRow): PlanInput {
  return {
    id: plan.id,
    name: plan.name,
    tagline: plan.tagline ?? '',
    description: plan.description,
    // One per line. A repeater with add/remove buttons looks more like an
    // editor and is worse to use: reordering six bullets is a drag-and-drop
    // problem in one and a cut-and-paste in the other.
    featuresText: plan.features.join('\n'),
    monthlyPrice: String(plan.monthly_price),
    yearlyPrice: String(plan.yearly_price),
    availability: plan.availability,
    badge: plan.badge ?? '',
    isFeatured: plan.is_featured,
    isActive: plan.is_active,
    sortOrder: String(plan.sort_order),
    trialDays: String(plan.trial_days),
    transactionFee: plan.transaction_fee === null ? '' : String(plan.transaction_fee),
    productIdMonthly: plan.product_id_monthly ?? '',
    productIdYearly: plan.product_id_yearly ?? '',
    limitsText: JSON.stringify(plan.limits ?? {}, null, 2),
    scopedLimitsText: JSON.stringify(scopedLimits(plan), null, 2),
  }
}

export function PlanEditor({ plan, readOnly }: { plan: PlanRow; readOnly: boolean }) {
  const router = useRouter()
  const base = initial(plan)
  const [form, setForm] = useState<PlanInput>(base)
  const [open, setOpen] = useState(false)
  const [confirmingDiscard, setConfirmingDiscard] = useState(false)
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  const dirty = JSON.stringify(form) !== JSON.stringify(base)
  const set = <K extends keyof PlanInput>(key: K, value: PlanInput[K]) =>
    setForm((f) => ({ ...f, [key]: value }))

  function save() {
    start(async () => {
      const result = await savePlan(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        router.refresh()
        setOpen(false)
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  /**
   * Closing with unsaved edits asks first, in the footer.
   *
   * The panel is dismissed by Escape and by clicking the page behind it, both
   * easy to do by accident, and this form holds six bullets someone may have
   * just rewritten by hand.
   *
   * Not `window.confirm`: a native modal freezes the page it is asked from,
   * looks nothing like the rest of the panel, and on a dense admin screen the
   * question belongs where the buttons are rather than over the top of them.
   */
  function requestClose(): boolean {
    if (pending) return false
    if (dirty) {
      setConfirmingDiscard(true)
      return false
    }
    close()
    return true
  }

  function close() {
    setForm(base)
    setConfirmingDiscard(false)
    setOpen(false)
  }

  const featureCount = form.featuresText.split('\n').filter((l) => l.trim()).length

  return (
    <Card className={plan.is_featured ? 'border-primary/40' : undefined}>
      <CardHeader>
        <div className="flex min-w-0 items-center gap-1.5">
          <CardTitle>{plan.name}</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{plan.id}</span>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          {plan.badge ? <Badge tone={plan.is_featured ? 'primary' : 'muted'}>{plan.badge}</Badge> : null}
          {!plan.is_active ? <Badge tone="danger">Hidden</Badge> : null}
          {plan.availability === 'coming_soon' ? <Badge tone="warning">Coming soon</Badge> : null}
        </div>
      </CardHeader>

      <CardBody className="space-y-2">
        {/* The card as a reader sees it, before any of the form. */}
        <PlanPreview
          name={plan.name}
          currency={plan.currency}
          monthly={plan.monthly_price}
          yearly={plan.yearly_price}
          tagline={plan.tagline}
          features={plan.features}
        />

        {readOnly ? (
          <p className="text-[11px] text-muted-foreground">
            Read-only for your role. Only a super admin can change a plan card.
          </p>
        ) : (
          <Button size="sm" variant="outline" onClick={() => setOpen(true)}>
            Edit this plan
          </Button>
        )}

        <SidePanel
          open={open}
          onRequestClose={requestClose}
          width="lg"
          title={`${plan.name} · ${plan.account_type}`}
          subtitle={
            <>
              <span className="tabular">{plan.id}</span> · shown on the{' '}
              {plan.account_type === 'customer' ? 'customer app' : 'Pro app'} paywall
            </>
          }
          footer={
            <div className="flex flex-wrap items-center gap-1.5">
              {confirmingDiscard ? (
                <>
                  <span className="text-[11px] text-warning">Discard your changes?</span>
                  <Button size="sm" variant="destructive" onClick={close}>
                    Discard
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setConfirmingDiscard(false)}>
                    Keep editing
                  </Button>
                </>
              ) : (
                <>
                  <Button size="sm" onClick={save} disabled={pending || !dirty}>
                    {pending ? 'Saving…' : 'Save'}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={requestClose} disabled={pending}>
                    {dirty ? 'Discard' : 'Close'}
                  </Button>
                  {dirty ? (
                    <span className="text-[10px] text-warning">Unsaved</span>
                  ) : (
                    <span className="text-[10px] text-muted-foreground">No changes</span>
                  )}
                  <span className="ml-auto text-[10px] text-muted-foreground">
                    Reaches both apps at next launch
                  </span>
                </>
              )}
            </div>
          }
        >
          <div className="space-y-2">
            {/* The card, again, inside the panel. The preview on the page is
                behind the scrim once this is open, and editing copy without
                seeing the copy is how a stray bullet ships. */}
            <PlanPreview
              name={form.name || plan.name}
              currency={plan.currency}
              monthly={Number(form.monthlyPrice) || 0}
              yearly={Number(form.yearlyPrice) || 0}
              tagline={form.tagline}
              features={form.featuresText.split('\n').map((l) => l.trim()).filter(Boolean)}
            />

            <Field label="Title" hint="The heading on the card">
              <Input value={form.name} onChange={(e) => set('name', e.target.value)} />
            </Field>

            <Field label="Tagline" hint="Small line under the price. Blank hides it.">
              <Input value={form.tagline} onChange={(e) => set('tagline', e.target.value)} />
            </Field>

            <Field label="Description" hint="Longer copy. Not shown on the card itself.">
              <Textarea
                rows={2}
                value={form.description}
                onChange={(e) => set('description', e.target.value)}
              />
            </Field>

            <Field label={`Features (${featureCount})`} hint="One per line, in the order they appear">
              <Textarea
                rows={7}
                value={form.featuresText}
                onChange={(e) => set('featuresText', e.target.value)}
                className="font-mono"
              />
            </Field>

            <div className="grid gap-2 sm:grid-cols-2">
              <Field label={`Monthly (${plan.currency})`} hint="Display only — the store charges">
                <Input
                  inputMode="decimal"
                  value={form.monthlyPrice}
                  onChange={(e) => set('monthlyPrice', e.target.value)}
                />
              </Field>
              <Field label={`Yearly (${plan.currency})`} hint="0 hides the yearly line">
                <Input
                  inputMode="decimal"
                  value={form.yearlyPrice}
                  onChange={(e) => set('yearlyPrice', e.target.value)}
                />
              </Field>
            </div>

            <div className="grid gap-2 sm:grid-cols-2">
              <Field label="Availability" hint="coming_soon greys the card out">
                <Select
                  className="w-full"
                  value={form.availability}
                  onChange={(e) => set('availability', e.target.value)}
                >
                  <option value="live">Live</option>
                  <option value="coming_soon">Coming soon</option>
                  <option value="hidden">Hidden</option>
                </Select>
              </Field>
              <Field label="Badge" hint="e.g. MOST POPULAR. Blank hides it.">
                <Input value={form.badge} onChange={(e) => set('badge', e.target.value)} />
              </Field>
            </div>

            <div className="grid gap-2 sm:grid-cols-3">
              <Field label="Trial days" hint="0 for none">
                <Input value={form.trialDays} onChange={(e) => set('trialDays', e.target.value)} />
              </Field>
              <Field label="Transaction fee %" hint="Blank for n/a">
                <Input
                  value={form.transactionFee}
                  onChange={(e) => set('transactionFee', e.target.value)}
                />
              </Field>
              <Field label="Sort order" hint="Left to right">
                <Input value={form.sortOrder} onChange={(e) => set('sortOrder', e.target.value)} />
              </Field>
            </div>

            <div className="flex flex-wrap gap-4">
              <Check
                label="Featured"
                hint="Highlights the card"
                checked={form.isFeatured}
                onChange={(v) => set('isFeatured', v)}
              />
              <Check
                label="Active"
                hint="Off keeps it in the document as isActive:false"
                checked={form.isActive}
                onChange={(v) => set('isActive', v)}
              />
            </div>

            <details className="border-t border-border/60 pt-2">
              <summary className="cursor-pointer text-[11px] text-muted-foreground hover:text-foreground">
                Store product ids and limits
              </summary>
              <div className="mt-2 space-y-2">
                <div className="grid gap-2 sm:grid-cols-2">
                  <Field label="IAP product id — monthly" hint="What actually charges">
                    <Input
                      value={form.productIdMonthly}
                      onChange={(e) => set('productIdMonthly', e.target.value)}
                      className="font-mono"
                    />
                  </Field>
                  <Field label="IAP product id — yearly" hint="Must exist in both stores">
                    <Input
                      value={form.productIdYearly}
                      onChange={(e) => set('productIdYearly', e.target.value)}
                      className="font-mono"
                    />
                  </Field>
                </div>
                <Field label="Shared limits" hint="-1 means unlimited">
                  <Textarea
                    rows={9}
                    value={form.limitsText}
                    onChange={(e) => set('limitsText', e.target.value)}
                    className="font-mono text-[11px]"
                    spellCheck={false}
                  />
                </Field>
                <Field
                  label={`${plan.account_type} limits`}
                  hint="Only this app's enforcement reads these"
                >
                  <Textarea
                    rows={12}
                    value={form.scopedLimitsText}
                    onChange={(e) => set('scopedLimitsText', e.target.value)}
                    className="font-mono text-[11px]"
                    spellCheck={false}
                  />
                </Field>
              </div>
            </details>

            <ActionResult feedback={feedback} />
          </div>
        </SidePanel>

        <ActionResult feedback={feedback} />
      </CardBody>
    </Card>
  )
}

function Field({
  label,
  hint,
  children,
}: {
  label: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <label className="block space-y-1">
      <span className="flex items-baseline gap-1.5">
        <span className="text-[11px] font-medium text-muted-foreground">{label}</span>
        {hint ? <span className="text-[10px] text-muted-foreground/70">{hint}</span> : null}
      </span>
      {children}
    </label>
  )
}

function Check({
  label,
  hint,
  checked,
  onChange,
}: {
  label: string
  hint: string
  checked: boolean
  onChange: (value: boolean) => void
}) {
  return (
    <label className="flex items-center gap-1.5 text-[11px]">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="accent-primary"
      />
      <span className="font-medium">{label}</span>
      <span className="text-[10px] text-muted-foreground/70">{hint}</span>
    </label>
  )
}

/**
 * The card exactly as a paywall renders it.
 *
 * One component for two callers: the page shows it with the saved row, and the
 * side panel shows it with whatever is currently typed. That second use is the
 * point — a feature list is six lines of prose, and the only reliable way to
 * know it reads right is to see it set as a card while editing it.
 */
function PlanPreview({
  name,
  currency,
  monthly,
  yearly,
  tagline,
  features,
}: {
  name: string
  currency: string
  monthly: number
  yearly: number
  tagline?: string | null
  features: string[]
}) {
  const free = monthly === 0 && yearly === 0
  return (
    <div className="rounded-md border border-border bg-background p-2.5">
      <div className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {name || 'Untitled'}
      </div>
      <div className="tabular mt-0.5 text-xl font-semibold leading-tight">
        {free ? 'FREE' : `${fmtMoney(monthly, currency)}/mo`}
      </div>
      <div className="text-[10px] text-muted-foreground">
        {tagline || (yearly > 0 ? `or ${fmtMoney(yearly, currency)}/year` : ' ')}
      </div>
      <ul className="mt-1.5 space-y-0.5 border-t border-border/60 pt-1.5">
        {features.map((f, i) => (
          <li key={i} className="flex gap-1.5 text-[11px] text-muted-foreground">
            <span className="text-success">✓</span>
            <span>{f}</span>
          </li>
        ))}
        {features.length === 0 ? (
          <li className="text-[11px] text-muted-foreground">No features listed.</li>
        ) : null}
      </ul>
    </div>
  )
}
