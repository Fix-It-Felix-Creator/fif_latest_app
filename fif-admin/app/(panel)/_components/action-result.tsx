import { cn } from '@/lib/utils'

export type Feedback = { tone: 'ok' | 'bad'; text: string; note?: string | null } | null

/**
 * What just happened, said plainly.
 *
 * `note` carries an audit-write failure. It is shown BESIDE a success rather
 * than turning it into an error, because the action did happen — a support
 * agent who is told "that failed" and retries would disable an account twice,
 * and the thing that actually failed is the record of it.
 */
export function ActionResult({ feedback }: { feedback: Feedback }) {
  if (!feedback) return null
  return (
    <div
      role="status"
      className={cn(
        'rounded border px-2 py-1.5 text-[11px]',
        feedback.tone === 'ok'
          ? 'border-success/40 bg-success/10 text-success'
          : 'border-destructive/40 bg-destructive/10 text-destructive',
      )}
    >
      {feedback.text}
      {feedback.note ? (
        <span className="mt-1 block text-warning">
          It was not written to the audit log: {feedback.note}
        </span>
      ) : null}
    </div>
  )
}
