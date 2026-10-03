'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { recoverAccount, setAccountStatus, startDeletion } from '@/app/(panel)/_actions/account'
import { ActionResult, type Feedback } from './action-result'
import { fmtDate } from '@/lib/format'
import { IS_PRODUCTION } from '@/lib/env'

/**
 * The account controls, in the order of how hard they are to undo.
 *
 * Disable is one click: it is reversible by the next click, and a support
 * agent stopping an account mid-incident should not have to type anything.
 * Starting a deletion asks for the email to be typed, because it hands the
 * person a countdown they have to notice in order to stop.
 */
export function AccountActions({
  userId,
  email,
  accountStatus,
  recoveryEndsAt,
}: {
  userId: string
  email: string | null
  accountStatus: string
  recoveryEndsAt: string | null
}) {
  const router = useRouter()
  const [confirm, setConfirm] = useState('')
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  const deleting = accountStatus === 'deletion_pending'
  const disabled = accountStatus === 'disabled'

  function run(action: (form: FormData) => Promise<Awaited<ReturnType<typeof recoverAccount>>>, extra?: Record<string, string>) {
    start(async () => {
      const form = new FormData()
      form.set('user_id', userId)
      Object.entries(extra ?? {}).forEach(([k, v]) => form.set(k, v))
      const result = await action(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        setConfirm('')
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <Card className={deleting ? 'border-destructive/40' : undefined}>
      <CardHeader>
        <CardTitle>Account actions</CardTitle>
        {IS_PRODUCTION ? (
          <span className="text-[10px] font-medium text-destructive">Production</span>
        ) : null}
      </CardHeader>
      <CardBody className="space-y-2">
        {deleting ? (
          <>
            <p className="text-[11px] leading-relaxed text-muted-foreground">
              Deletion is under way. They can still sign in and recover until{' '}
              <span className="font-medium text-foreground">{fmtDate(recoveryEndsAt)}</span> — which
              is why the login is still active.
            </p>
            <Button size="sm" onClick={() => run(recoverAccount)} disabled={pending}>
              Cancel the deletion
            </Button>
          </>
        ) : (
          <>
            <div className="flex flex-wrap items-center gap-1.5">
              {disabled ? (
                <Button
                  size="sm"
                  onClick={() => run(setAccountStatus, { status: 'active' })}
                  disabled={pending}
                >
                  Re-enable
                </Button>
              ) : (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => run(setAccountStatus, { status: 'disabled' })}
                  disabled={pending}
                >
                  Disable
                </Button>
              )}
            </div>
            <p className="text-[11px] leading-relaxed text-muted-foreground">
              Disabling blocks the account in the app. It does not end their current session — an
              already-signed-in device keeps working until its token expires.
            </p>

            <div className="border-t border-border/60 pt-2">
              <p className="mb-1.5 text-[11px] leading-relaxed text-muted-foreground">
                Starting a deletion sets the same clock the user&apos;s own request would: a recovery
                window, then a retention deadline. Nothing is erased today, and they can still sign
                in to stop it. Type{' '}
                <span className="font-medium text-foreground">{email ?? userId}</span> to confirm.
              </p>
              <div className="flex flex-wrap items-center gap-1.5">
                <Input
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  placeholder={email ?? userId}
                  aria-label="Type the email to confirm"
                  className="w-64"
                />
                <Button
                  size="sm"
                  variant="destructive"
                  onClick={() => run(startDeletion, { confirm })}
                  disabled={pending || !confirm.trim()}
                >
                  Start deletion
                </Button>
              </div>
            </div>
          </>
        )}

        <ActionResult feedback={feedback} />
      </CardBody>
    </Card>
  )
}
