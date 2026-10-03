/**
 * Display helpers. Everything here answers the same question — how does this
 * value read to a person scanning a table of a hundred rows.
 */

export function fmtDate(value: string | null | undefined): string {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

export function fmtDateTime(value: string | null | undefined): string {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * "3 days ago" — the form that matters on an operations page, where the
 * question is almost always how stale something is rather than its date.
 */
export function fmtAgo(value: string | null | undefined): string {
  if (!value) return '—'
  const then = new Date(value).getTime()
  if (Number.isNaN(then)) return '—'
  const secs = Math.round((Date.now() - then) / 1000)
  if (secs < 0) return 'in the future'
  if (secs < 60) return 'just now'
  const mins = Math.round(secs / 60)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  if (days < 30) return `${days}d ago`
  const months = Math.round(days / 30)
  if (months < 12) return `${months}mo ago`
  return `${Math.round(months / 12)}y ago`
}

/**
 * How long until a deadline, as a countdown.
 *
 * The deletion pages are read to answer "how long have I got" — a date makes
 * the reader do the subtraction, and an overdue one should say so rather than
 * quietly reading as a normal date.
 */
export function fmtUntil(value: string | null | undefined): string {
  if (!value) return '—'
  const then = new Date(value).getTime()
  if (Number.isNaN(then)) return '—'
  const secs = Math.round((then - Date.now()) / 1000)
  if (secs <= 0) return 'overdue'
  const hours = Math.round(secs / 3600)
  if (hours < 24) return `${hours}h left`
  const days = Math.round(hours / 24)
  if (days < 60) return `${days}d left`
  return `${Math.round(days / 30)}mo left`
}

export function fmtNum(value: number | string | null | undefined, digits = 0): string {
  if (value === null || value === undefined || value === '') return '—'
  const n = typeof value === 'string' ? Number(value) : value
  if (!Number.isFinite(n)) return '—'
  return n.toLocaleString('en-GB', { minimumFractionDigits: digits, maximumFractionDigits: digits })
}

/**
 * Money, in pounds.
 *
 * Both apps are GBP-only in practice (`profiles.currency` defaults to GBP and
 * nothing sets it otherwise), but the column exists — so where a row carries
 * one, pass it rather than assuming.
 */
export function fmtMoney(
  value: number | string | null | undefined,
  currency = 'GBP',
): string {
  if (value === null || value === undefined || value === '') return '—'
  const n = typeof value === 'string' ? Number(value) : value
  if (!Number.isFinite(n)) return '—'
  try {
    return n.toLocaleString('en-GB', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  } catch {
    // An unknown currency code from the database must not white-screen a page.
    return `${currency} ${n.toFixed(2)}`
  }
}

/** Seconds of tracked work, as a tradesperson would read them off a timesheet. */
export function fmtDuration(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds)) return '—'
  const total = Math.max(0, Math.round(seconds))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  if (h === 0 && m === 0) return '<1m'
  if (h === 0) return `${m}m`
  return `${h}h ${m}m`
}

export function fmtBytes(value: number | null | undefined): string {
  if (!value || !Number.isFinite(value)) return '—'
  const units = ['B', 'KB', 'MB', 'GB']
  let n = value
  let i = 0
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024
    i++
  }
  return `${n.toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

/**
 * snake_case and camelCase as words, for values that came from an enum.
 *
 * Takes `unknown` rather than `string` ON PURPOSE. Callers read out of a
 * `Record<string, unknown>` row and write `as string` to get here, and that
 * cast is a lie TypeScript accepts without checking — `profiles.trade` is a
 * Postgres ARRAY, and the compiler is perfectly happy to hand it to
 * `.replace()`. A display helper cannot be the thing that white-screens a
 * page, so anything that is not a string goes to fmtAny instead.
 */
export function humanise(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (Array.isArray(value)) {
    const parts = value.map(humanise).filter((part) => part !== '—')
    return parts.length ? parts.join(', ') : '—'
  }
  if (typeof value !== 'string') return fmtAny(value)
  return value
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2') // superAdmin, bankDeposit
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase())
}

/** Long ids and share tokens, shortened for a cell but still recognisable. */
export function shortId(value: string | null | undefined): string {
  if (!value) return '—'
  return value.length <= 12 ? value : `${value.slice(0, 8)}…`
}

/**
 * Anything at all, as one line of a table cell.
 *
 * Several tables carry jsonb whose shape differs per row (customer snapshots,
 * notification payloads, subscription metadata), and a table needs SOMETHING
 * readable in the cell rather than "[object Object]".
 */
export function fmtAny(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  if (typeof value === 'number') return fmtNum(value, Number.isInteger(value) ? 0 : 2)
  if (Array.isArray(value)) return value.length ? value.map(fmtAny).join(', ') : '—'
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
    if (!entries.length) return '—'
    return entries.map(([k, v]) => `${humanise(k)}: ${fmtAny(v)}`).join(' · ')
  }
  return String(value)
}

/** A share as a whole percent, for the funnel hints. */
export function pct(part: number, whole: number): number {
  if (!whole) return 0
  return Math.max(0, Math.min(100, Math.round((part / whole) * 100)))
}

export function initials(name: string | null | undefined, email: string | null | undefined): string {
  const source = (name ?? '').trim() || (email ?? '').split('@')[0] || '?'
  const parts = source.split(/[\s._-]+/).filter(Boolean)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return source.slice(0, 2).toUpperCase()
}

/** First name + last name, or nothing rather than a stray space. */
export function fullName(
  first: string | null | undefined,
  last: string | null | undefined,
): string | null {
  const name = [first, last].filter((p) => p && p.trim()).join(' ').trim()
  return name || null
}

/** The one-line address a table cell can hold. */
export function shortAddress(row: {
  formatted_address?: string | null
  address_line1?: string | null
  city?: string | null
  postcode?: string | null
}): string {
  if (row.formatted_address) return row.formatted_address
  const parts = [row.address_line1, row.city, row.postcode].filter(Boolean)
  return parts.length ? parts.join(', ') : '—'
}
