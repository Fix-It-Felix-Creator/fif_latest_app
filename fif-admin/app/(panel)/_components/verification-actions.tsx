'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { setVerification } from '@/app/(panel)/_actions/account'
import { ActionResult, type Feedback } from './action-result'

/**
 * Approve, reject, or send someone back to the queue.
 *
 * The reject box is always visible rather than revealed by clicking Reject.
 * On a review screen the reason is part of the decision, not a confirmation
 * step after it — and a reviewer who has already typed why should not have
 * their sentence thrown away by a mis-click on Approve.
 */
export function VerificationActions({
  userId,
  current,
  compact = false,
}: {
  userId: string
  current: string | null
  compact?: boolean
}) {
  const router = useRouter()
  const [reason, setReason] = useState('')
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  function run(status: 'verified' | 'rejected' | 'waiting' | 'unverified') {
    start(async () => {
      const form = new FormData()
      form.set('user_id', userId)
      form.set('status', status)
      form.set('reason', reason)
      const result = await setVerification(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        if (status !== 'rejected') setReason('')
        router.refresh()
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-1.5">
        <Button
          size="sm"
          onClick={() => run('verified')}
          disabled={pending || current === 'verified'}
        >
          Approve
        </Button>
        <Button
          size="sm"
          variant="destructive"
          onClick={() => run('rejected')}
          disabled={pending || !reason.trim()}
          title={reason.trim() ? undefined : 'Give a reason first'}
        >
          Reject
        </Button>
        {!compact ? (
          <>
            <Button
              size="sm"
              variant="outline"
              onClick={() => run('waiting')}
              disabled={pending || current === 'waiting'}
            >
              Back to queue
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => run('unverified')}
              disabled={pending || current === 'unverified'}
            >
              Clear
            </Button>
          </>
        ) : null}
      </div>

      <Input
        value={reason}
        onChange={(e) => setReason(e.target.value)}
        placeholder="Why it was rejected — they see this in the app"
        aria-label="Rejection reason"
        maxLength={300}
      />

      <ActionResult feedback={feedback} />
    </div>
  )
}
