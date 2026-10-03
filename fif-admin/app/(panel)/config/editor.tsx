'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Textarea } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { saveConfig } from './actions'
import { fmtAgo } from '@/lib/format'
import { IS_PRODUCTION } from '@/lib/env'

/**
 * One config key, as raw JSON.
 *
 * Deliberately not a generated form. These values have no schema anywhere —
 * they came from Firebase Remote Config, each key has a different shape, and
 * a form built from today's keys would silently drop tomorrow's. Raw JSON with
 * a parse check before saving is the honest editor for an untyped document.
 */
export function ConfigEditor({
  configKey,
  value,
  description,
  updatedAt,
  readOnly,
}: {
  configKey: string
  value: unknown
  description: string | null
  updatedAt: string | null
  readOnly: boolean
}) {
  const router = useRouter()
  const initial = JSON.stringify(value ?? {}, null, 2)
  const [draft, setDraft] = useState(initial)
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  const dirty = draft !== initial
  const dangerous = configKey.includes('maintenance') || configKey.includes('force_app_update')

  function save() {
    start(async () => {
      const result = await saveConfig(configKey, draft)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <Card className={dangerous ? 'border-warning/40' : undefined}>
      <CardHeader>
        <CardTitle>{configKey}</CardTitle>
        <span className="flex items-center gap-1.5">
          {dangerous ? <Badge tone="warning">Affects every install</Badge> : null}
          <span className="text-[10px] text-muted-foreground">
            {updatedAt ? fmtAgo(updatedAt) : 'never changed'}
          </span>
        </span>
      </CardHeader>
      <CardBody className="space-y-2">
        {description ? (
          <p className="text-[11px] text-muted-foreground">{description}</p>
        ) : null}

        <Textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          rows={Math.min(24, Math.max(6, initial.split('\n').length + 1))}
          spellCheck={false}
          readOnly={readOnly}
          aria-label={`${configKey} value`}
          className="font-mono text-[11px] leading-relaxed"
        />

        {readOnly ? (
          <p className="text-[11px] text-muted-foreground">
            Read-only for your role. Only a super admin can change what the apps read at launch.
          </p>
        ) : (
          <div className="flex flex-wrap items-center gap-1.5">
            <Button size="sm" onClick={save} disabled={pending || !dirty}>
              {pending ? 'Saving…' : dangerous && IS_PRODUCTION ? 'Save to production' : 'Save'}
            </Button>
            {dirty ? (
              <Button size="sm" variant="ghost" onClick={() => setDraft(initial)} disabled={pending}>
                Discard
              </Button>
            ) : (
              <span className="text-[10px] text-muted-foreground">No changes</span>
            )}
          </div>
        )}

        <ActionResult feedback={feedback} />
      </CardBody>
    </Card>
  )
}
