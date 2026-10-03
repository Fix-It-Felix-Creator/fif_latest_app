'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { SidePanel } from '@/components/side-panel'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { humanise, fmtDate } from '@/lib/format'
import { approveLeadApplication, rejectLeadApplication } from '../_actions/lead-applications'
import { signedDocuments } from './actions'

/**
 * Whichever decision is due for this person.
 *
 * One component rather than two, because a reviewer works down one list and
 * should not have to notice which kind of row they are on before they know
 * which buttons to expect. The stage decides what is shown; the reviewer just
 * opens the next one.
 */

/** Schemes whose public register can be opened to check a number. */
const REGISTERS: Record<string, { label: string; url: string }> = {
  gas_engineer: {
    label: 'Gas Safe',
    url: 'https://www.gassaferegister.co.uk/find-an-engineer-or-check-the-register/check-an-engineer/',
  },
  boiler_repair: {
    label: 'Gas Safe',
    url: 'https://www.gassaferegister.co.uk/find-an-engineer-or-check-the-register/check-an-engineer/',
  },
  central_heating: {
    label: 'Gas Safe',
    url: 'https://www.gassaferegister.co.uk/find-an-engineer-or-check-the-register/check-an-engineer/',
  },
  electrician: {
    label: 'Competent person register',
    url: 'https://www.electricalcompetentperson.co.uk/',
  },
  glazier: { label: 'FENSA', url: 'https://www.fensa.org.uk/fensa-approved-installer-search' },
}

const WASTE_REGISTER =
  'https://environment.data.gov.uk/public-register/view/search-waste-carriers-brokers'

export function Decide({
  row,
  canLeads,
}: {
  row: Record<string, unknown>
  canLeads: boolean
}) {
  const router = useRouter()
  const [open, setOpen] = useState(false)
  const [rejecting, setRejecting] = useState(false)
  const [reason, setReason] = useState('')
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [docs, setDocs] = useState<string[] | null>(null)
  const [pending, start] = useTransition()

  const stage = row.stage as string
  const id = row.id as string
  const applicationId = row.application_id as string | null
  const name =
    [row.first_name, row.last_name].filter(Boolean).join(' ') ||
    (row.email as string) ||
    'this person'

  // Identity is the decision when they are waiting on it; leads when they are
  // verified and have applied. Everything else is a row to read, not act on.
  // One application, one decision: approving it verifies the person AND turns
  // their leads on. There is no separate identity decision to make here any
  // more, so there is no separate branch for it either.
  const actionable = stage === 'to_review' && canLeads

  async function show() {
    setOpen(true)
    // Signed on demand, not with the page. A signed URL expires, and signing
    // every document in the table on every load would be a lot of links
    // nobody opens.
    if (docs === null) setDocs(await signedDocuments(id))
  }

  function decide(approve: boolean) {
    const form = new FormData()
    form.set('application_id', applicationId ?? '')
    if (!approve) form.set('reason', reason)
    start(async () => {
      const result = approve
        ? await approveLeadApplication(form)
        : await rejectLeadApplication(form)
      finish(result)
    })
  }

  function finish(result: { ok: boolean; message?: string; error?: string }) {
    if (result.ok) {
      setFeedback({ tone: 'ok', text: result.message ?? 'Done.' })
      setOpen(false)
      setRejecting(false)
      setReason('')
      router.refresh()
    } else {
      setFeedback({ tone: 'bad', text: result.error ?? 'That did not work.' })
    }
  }

  const registrations = (row.registrations as Record<string, string> | null) ?? {}
  const services = (row.services as string[] | null) ?? []
  const expires = row.policy_expires_at as string | null
  const expired = expires ? new Date(expires) < new Date() : false

  return (
    <>
      <Button size="sm" variant={actionable ? 'default' : 'secondary'} onClick={show}>
        {actionable ? 'Review' : 'Open'}
      </Button>
      <ActionResult feedback={feedback} />

      <SidePanel
        open={open}
        title={`${name} — ${humanise(stage)}`}
        onRequestClose={() => {
          setOpen(false)
          setRejecting(false)
        }}
      >
        <div className="grid gap-4 text-xs">
          <section className="grid gap-1.5">
            <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
              Identity — does the face match the document?
            </h3>
            {docs === null ? (
              <p className="text-muted-foreground">Loading documents…</p>
            ) : docs.length === 0 ? (
              <p className="text-muted-foreground">
                Nothing uploaded. They have not been through verification yet.
              </p>
            ) : (
              <>
                <p className="text-muted-foreground">
                  {row.document_type ? humanise(row.document_type) : 'Document'} and
                  selfie. Links expire in an hour.
                </p>
                <div className="flex flex-wrap gap-2">
                  {docs.map((url, i) => (
                    <a key={url} href={url} target="_blank" rel="noreferrer noopener">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={url}
                        alt={i === docs.length - 1 ? 'Selfie' : 'ID document'}
                        className="h-28 w-28 rounded-md border border-border object-cover transition hover:opacity-80"
                      />
                    </a>
                  ))}
                </div>
              </>
            )}
            {row.verification_rejection_reason ? (
              <p className="text-muted-foreground">
                Last turned down: {row.verification_rejection_reason as string}
              </p>
            ) : null}
          </section>

          {row.application_status ? (
            <>
              <section className="grid gap-1.5">
                <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                  Leads application — {humanise(row.application_status)}
                </h3>
                <p className="text-muted-foreground">
                  {humanise(row.applicant_type)} · {services.map(humanise).join(', ') || '—'}
                </p>
                <p className="text-muted-foreground">{(row.base_address as string) || '—'}</p>
                {Object.entries(registrations).map(([service, number]) => {
                  const lookup = REGISTERS[service]
                  return (
                    <div
                      key={service}
                      className="flex items-center justify-between gap-2 rounded-md border border-border px-2.5 py-1.5"
                    >
                      <div>
                        <div className="font-medium">{humanise(service)}</div>
                        <div className="tabular text-muted-foreground">{number}</div>
                      </div>
                      {lookup ? (
                        <a
                          href={lookup.url}
                          target="_blank"
                          rel="noreferrer noopener"
                          className="whitespace-nowrap text-primary hover:underline"
                        >
                          Check {lookup.label} ↗
                        </a>
                      ) : null}
                    </div>
                  )
                })}
                {row.moves_waste ? (
                  <div className="flex items-center justify-between gap-2 rounded-md border border-border px-2.5 py-1.5">
                    <span className="tabular">
                      {(row.waste_carrier_number as string) || 'No waste carrier number'}
                    </span>
                    <a
                      href={WASTE_REGISTER}
                      target="_blank"
                      rel="noreferrer noopener"
                      className="whitespace-nowrap text-primary hover:underline"
                    >
                      Check EA register ↗
                    </a>
                  </div>
                ) : null}
                <div>
                  {row.has_own_insurance === false ? (
                    <Badge tone="warning">Under someone else&rsquo;s cover</Badge>
                  ) : expired ? (
                    <Badge tone="danger">Insurance expired {fmtDate(expires!)}</Badge>
                  ) : expires ? (
                    <span className="text-muted-foreground">
                      {(row.insurer as string) || 'Insurer not given'} · to {fmtDate(expires)}
                    </span>
                  ) : (
                    <Badge tone="warning">No insurance expiry given</Badge>
                  )}
                </div>
                {row.application_rejection_reason ? (
                  <p className="text-muted-foreground">
                    Last turned down: {row.application_rejection_reason as string}
                  </p>
                ) : null}
              </section>

              <section className="grid gap-1.5">
                <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                  What customers will see
                </h3>
                <div className="rounded-md border border-border px-2.5 py-2">
                  <div className="font-medium">{(row.headline as string) || '—'}</div>
                  <p className="mt-1 leading-relaxed text-muted-foreground">
                    {(row.about as string) || '—'}
                  </p>
                </div>
              </section>
            </>
          ) : null}

          {!actionable ? (
            <p className="border-t border-border pt-3 text-muted-foreground">
              Nothing to decide at this stage — this application has already
              been decided, withdrawn, or never sent.
            </p>
          ) : rejecting ? (
            <section className="grid gap-2">
              <label
                className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
                htmlFor="reason"
              >
                Why — they read this in the app
              </label>
              <Textarea
                id="reason"
                rows={4}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={
                  'e.g. The photo of your passport is too dark to read the number, and the Gas Safe number did not match the name on the account.'
                }
              />
              <p className="text-muted-foreground">
                Write it as something they can act on. &ldquo;Rejected&rdquo; on its own
                becomes a support ticket.
              </p>
              <div className="flex gap-2">
                <Button
                  variant="destructive"
                  disabled={pending || reason.trim().length === 0}
                  onClick={() => decide(false)}
                >
                  {pending ? 'Sending…' : 'Reject and notify'}
                </Button>
                <Button variant="ghost" onClick={() => setRejecting(false)} disabled={pending}>
                  Back
                </Button>
              </div>
            </section>
          ) : (
            <div className="flex gap-2 border-t border-border pt-3">
              <Button
                disabled={pending}
                onClick={() => decide(true)}
              >
                {pending ? 'Saving…' : 'Verify and approve'}
              </Button>
              <Button variant="secondary" disabled={pending} onClick={() => setRejecting(true)}>
                Reject…
              </Button>
            </div>
          )}
        </div>
      </SidePanel>
    </>
  )
}
