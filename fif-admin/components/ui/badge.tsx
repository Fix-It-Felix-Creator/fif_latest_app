import { cn } from '@/lib/utils'

const tones = {
  default: 'border-border bg-secondary text-secondary-foreground',
  muted: 'border-border bg-muted text-muted-foreground',
  primary: 'border-primary/40 bg-primary/10 text-primary',
  success: 'border-success/40 bg-success/10 text-success',
  warning: 'border-warning/40 bg-warning/10 text-warning',
  danger: 'border-destructive/40 bg-destructive/10 text-destructive',
  info: 'border-info/40 bg-info/10 text-info',
} as const

export type BadgeTone = keyof typeof tones

export function Badge({
  tone = 'default',
  className,
  ...props
}: React.ComponentProps<'span'> & { tone?: BadgeTone }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 whitespace-nowrap rounded border px-1.5 py-px text-[10px] font-medium leading-4',
        tones[tone],
        className,
      )}
      {...props}
    />
  )
}

/**
 * The tone a status word gets, in one place.
 *
 * Statuses arrive from seven tables in seven vocabularies — a job is
 * draft/active/completed/cancelled, an invoice is draft/sent/paid/overdue/
 * cancelled, a subscription is active/expired/cancelled/trial/pending — and a
 * reader scanning a page should not have to learn which green means what.
 *
 * Anything unrecognised stays neutral rather than guessing: a wrong colour on
 * a status is worse than no colour, and these vocabularies are CHECK
 * constraints that can gain a value without this file hearing about it.
 */
export function statusTone(value: string | null | undefined): BadgeTone {
  switch ((value ?? '').toLowerCase()) {
    // Arrived somewhere good.
    case 'active':
    case 'completed':
    case 'paid':
    case 'accepted':
    case 'verified':
    case 'available':
    case 'succeeded':
    case 'ok':
      return 'success'

    // In flight — someone is waiting on someone else. A posted job request is
    // exactly this: the customer is waiting for a tradesperson to appear.
    case 'waiting':
    case 'pending':
    case 'busy':
    case 'posted':
      return 'warning'

    // Wrong, and someone has to act.
    case 'overdue':
    case 'rejected':
    case 'failed':
    case 'error':
    case 'disabled':
    case 'deletion_pending':
      return 'danger'

    // Real but not yet anything. `draft` is deliberately quiet: it is the
    // most common status in every one of these tables, and colouring it would
    // light up the whole ledger.
    case 'draft':
    case 'expired':
    case 'cancelled':
    case 'unverified':
    case 'offline':
    case 'archived':
    case 'none':
      return 'muted'

    // Sent, seen, in progress.
    case 'sent':
    case 'viewed':
    case 'trial':
    case 'assigned':
    case 'in_progress':
      return 'info'

    default:
      return 'default'
  }
}

/**
 * Which app a person belongs to, at a glance.
 *
 * `account_type` is the only thing separating the two products — a tradesman
 * or business row is the Pro app, a customer row is the customer app — so it
 * earns a consistent colour wherever the two appear side by side.
 */
export function accountTypeTone(value: string | null | undefined): BadgeTone {
  switch ((value ?? '').toLowerCase()) {
    case 'tradesman':
      return 'primary'
    case 'business':
      return 'info'
    case 'customer':
      return 'success'
    default:
      return 'muted'
  }
}

export const ACCOUNT_TYPE_LABEL: Record<string, string> = {
  tradesman: 'Tradesperson',
  business: 'Business',
  customer: 'Customer',
}
