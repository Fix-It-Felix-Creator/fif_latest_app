'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Select } from '@/components/ui/input'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { ADMIN_ROLES, ROLE_BLURB, ROLE_LABEL, type AdminRole } from '@/lib/roles'
import { grantRole, setActive } from './actions'
import { IS_PRODUCTION } from '@/lib/env'

export function GrantForm() {
  const router = useRouter()
  const [role, setRole] = useState<AdminRole>('support')
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const element = event.currentTarget
    start(async () => {
      const result = await grantRole(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        element.reset()
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <Card className={IS_PRODUCTION ? 'border-destructive/40' : undefined}>
      <CardHeader>
        <CardTitle>Give someone access</CardTitle>
        {IS_PRODUCTION ? (
          <span className="text-[10px] font-medium text-destructive">Production project</span>
        ) : null}
      </CardHeader>
      <CardBody>
        <form onSubmit={submit} className="space-y-2">
          <div className="grid gap-2 sm:grid-cols-3">
            <div className="space-y-1">
              <label htmlFor="grant-email" className="text-[11px] font-medium text-muted-foreground">
                Their account email
              </label>
              <Input
                id="grant-email"
                name="email"
                type="email"
                required
                placeholder="them@fixitfelixsoftwaresolutions.com"
              />
            </div>
            <div className="space-y-1">
              <label htmlFor="grant-name" className="text-[11px] font-medium text-muted-foreground">
                Name for the log
              </label>
              <Input id="grant-name" name="display_name" placeholder="Optional" />
            </div>
            <div className="space-y-1">
              <label htmlFor="grant-role" className="text-[11px] font-medium text-muted-foreground">
                Role
              </label>
              <Select
                id="grant-role"
                name="role"
                value={role}
                onChange={(e) => setRole(e.target.value as AdminRole)}
                className="w-full"
              >
                {ADMIN_ROLES.map((r) => (
                  <option key={r} value={r}>
                    {ROLE_LABEL[r]}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <p className="text-[11px] leading-relaxed text-muted-foreground">{ROLE_BLURB[role]}</p>

          <div className="flex flex-wrap items-center gap-2">
            <Button type="submit" size="sm" disabled={pending}>
              {pending ? 'Granting…' : 'Grant'}
            </Button>
            <span className="text-[10px] text-muted-foreground">
              {/* Each project holds its own roster, and this deployment reads
                  exactly one. Saying so stops "I added them" meaning staging
                  when the ticket was about production. */}
              This grants access to the {IS_PRODUCTION ? 'production' : 'staging'} project only.
              The other project has its own roster.
            </span>
          </div>

          <ActionResult feedback={feedback} />
        </form>
      </CardBody>
    </Card>
  )
}

export function RevokeButton({
  userId,
  active,
  isSelf,
}: {
  userId: string
  active: boolean
  isSelf: boolean
}) {
  const router = useRouter()
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  function toggle() {
    start(async () => {
      const form = new FormData()
      form.set('user_id', userId)
      form.set('active', String(!active))
      const result = await setActive(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Button
        size="sm"
        variant={active ? 'outline' : 'default'}
        onClick={toggle}
        disabled={pending || (isSelf && active)}
        title={isSelf && active ? 'You cannot revoke your own access' : undefined}
      >
        {pending ? '…' : active ? 'Revoke' : 'Restore'}
      </Button>
      {feedback ? (
        <div className="max-w-[18rem]">
          <ActionResult feedback={feedback} />
        </div>
      ) : null}
    </div>
  )
}
