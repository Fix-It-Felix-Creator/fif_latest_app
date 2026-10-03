'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Send, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Select, Textarea } from '@/components/ui/input'
import { ACCOUNT_TYPE_LABEL, Badge, accountTypeTone } from '@/components/ui/badge'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { findRecipients, sendNotification } from './actions'
import { fmtNum } from '@/lib/format'
import { IS_PRODUCTION } from '@/lib/env'

type Recipient = { id: string; label: string; accountType: string }

/**
 * The compose box.
 *
 * Two things here are not decoration. A broadcast states its live recipient
 * count and then asks for the word BROADCAST to be typed — `toAll` reaches
 * every profile in the project, across both apps, and there is no unsend. And
 * recipients are picked by searching for a person rather than pasting a uuid,
 * because a wrong uuid produces a message delivered silently to a stranger.
 */
export function Composer({
  canBroadcast,
  reach,
  types,
}: {
  canBroadcast: boolean
  reach: { profiles: number; tokens: number }
  types: string[]
}) {
  const router = useRouter()
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [type, setType] = useState('system')
  const [toAll, setToAll] = useState(false)
  const [confirm, setConfirm] = useState('')
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Recipient[]>([])
  const [picked, setPicked] = useState<Recipient[]>([])
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()
  const [searching, startSearch] = useTransition()

  function search(event: React.FormEvent) {
    event.preventDefault()
    startSearch(async () => setResults(await findRecipients(query)))
  }

  function add(person: Recipient) {
    setPicked((current) => (current.some((p) => p.id === person.id) ? current : [...current, person]))
  }

  const blocked = toAll && confirm.trim().toUpperCase() !== 'BROADCAST'
  const ready = title.trim() && body.trim() && (toAll ? !blocked : picked.length > 0)

  function send() {
    start(async () => {
      const result = await sendNotification({
        title,
        body,
        type,
        toAll,
        recipients: picked.map((p) => p.id),
      })
      if (result.ok) {
        setFeedback({
          tone: 'ok',
          text: `Written to ${fmtNum(result.sent)} ${result.sent === 1 ? 'inbox' : 'inboxes'}. Push: ${fmtNum(result.pushSent)} delivered, ${fmtNum(result.pushFailed)} failed.`,
          note: result.auditError,
        })
        setTitle('')
        setBody('')
        setPicked([])
        setToAll(false)
        setConfirm('')
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Compose</CardTitle>
        <span className="text-[10px] text-muted-foreground">
          Sent by the api function · in-app record plus a push
        </span>
      </CardHeader>
      <CardBody className="space-y-2">
        <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
          <div className="space-y-1">
            <label htmlFor="notif-title" className="text-[11px] font-medium text-muted-foreground">
              Title
            </label>
            <Input
              id="notif-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Short — it is the push notification's first line"
              maxLength={80}
            />
          </div>
          <div className="space-y-1">
            <label htmlFor="notif-type" className="text-[11px] font-medium text-muted-foreground">
              Type
            </label>
            <Select
              id="notif-type"
              value={type}
              onChange={(e) => setType(e.target.value)}
              className="w-40"
            >
              {/* Whatever has actually been sent before, plus the default the
                  api function falls back to. A fixed list here would go stale
                  the first time the app introduces a new one. */}
              {[...new Set(['system', 'general', ...types])].map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </Select>
          </div>
        </div>

        <div className="space-y-1">
          <label htmlFor="notif-body" className="text-[11px] font-medium text-muted-foreground">
            Body
          </label>
          <Textarea
            id="notif-body"
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={3}
            placeholder="Anything past about 140 characters opens the detail view in the app rather than fitting on the card."
          />
        </div>

        <div className="border-t border-border/60 pt-2">
          <div className="mb-1.5 flex flex-wrap items-center gap-2">
            <label className="flex items-center gap-1.5 text-[11px]">
              <input
                type="radio"
                name="audience"
                checked={!toAll}
                onChange={() => setToAll(false)}
                className="accent-primary"
              />
              Named recipients
            </label>
            <label
              className={`flex items-center gap-1.5 text-[11px] ${canBroadcast ? '' : 'opacity-50'}`}
              title={canBroadcast ? undefined : 'Your role cannot broadcast'}
            >
              <input
                type="radio"
                name="audience"
                checked={toAll}
                disabled={!canBroadcast}
                onChange={() => setToAll(true)}
                className="accent-primary"
              />
              Everyone
            </label>
          </div>

          {toAll ? (
            <div className="space-y-1.5 rounded border border-destructive/40 bg-destructive/10 p-2">
              <p className="text-[11px] leading-relaxed text-destructive">
                This reaches <span className="font-medium">{fmtNum(reach.profiles)}</span> accounts —
                every tradesperson, business and customer on{' '}
                {IS_PRODUCTION ? 'production' : 'staging'} — and pushes to{' '}
                <span className="font-medium">{fmtNum(reach.tokens)}</span> devices. There is no
                unsend. Type BROADCAST to confirm.
              </p>
              <Input
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                placeholder="BROADCAST"
                aria-label="Type BROADCAST to confirm"
                className="w-48"
              />
            </div>
          ) : (
            <div className="space-y-1.5">
              <form onSubmit={search} className="flex items-center gap-1.5">
                <Input
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Find someone by name, company or email…"
                  aria-label="Find a recipient"
                  className="w-72"
                />
                <Button type="submit" size="sm" variant="outline" disabled={searching}>
                  {searching ? 'Searching…' : 'Search'}
                </Button>
              </form>

              {results.length > 0 ? (
                <div className="scroll-thin max-h-40 overflow-y-auto rounded border border-border">
                  {results.map((r) => (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => add(r)}
                      className="flex w-full items-center gap-2 px-2 py-1 text-left text-[11px] transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    >
                      <Badge tone={accountTypeTone(r.accountType)}>
                        {ACCOUNT_TYPE_LABEL[r.accountType] ?? r.accountType}
                      </Badge>
                      <span className="truncate">{r.label}</span>
                    </button>
                  ))}
                </div>
              ) : null}

              {picked.length > 0 ? (
                <div className="flex flex-wrap gap-1">
                  {picked.map((p) => (
                    <span
                      key={p.id}
                      className="inline-flex items-center gap-1 rounded border border-border bg-secondary px-1.5 py-px text-[10px]"
                    >
                      {p.label}
                      <button
                        type="button"
                        onClick={() => setPicked((c) => c.filter((x) => x.id !== p.id))}
                        className="text-muted-foreground transition-colors hover:text-destructive focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                      >
                        <X className="h-2.5 w-2.5" />
                        <span className="sr-only">Remove {p.label}</span>
                      </button>
                    </span>
                  ))}
                </div>
              ) : (
                <p className="text-[11px] text-muted-foreground">Nobody picked yet.</p>
              )}
            </div>
          )}
        </div>

        <div className="flex items-center gap-2 border-t border-border/60 pt-2">
          <Button size="sm" onClick={send} disabled={pending || !ready}>
            <Send className="h-3 w-3" />
            {pending
              ? 'Sending…'
              : toAll
                ? `Send to ${fmtNum(reach.profiles)} accounts`
                : `Send to ${picked.length || 'nobody'}`}
          </Button>
          <span className="text-[10px] text-muted-foreground">
            An account with no push token still gets the in-app record.
          </span>
        </div>

        <ActionResult feedback={feedback} />
      </CardBody>
    </Card>
  )
}
