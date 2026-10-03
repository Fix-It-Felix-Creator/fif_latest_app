'use client'

import { Button } from '@/components/ui/button'

export default function ErrorPage({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="mx-auto max-w-lg py-16 text-center">
      <h2 className="text-sm font-semibold">Something broke on the way to this page.</h2>
      {/* The message, not a friendly substitute for it: whoever is looking at
          an admin panel is the person who can act on the real error. */}
      <p className="mt-2 break-words text-xs text-muted-foreground">{error.message}</p>
      <Button className="mt-4" size="sm" onClick={reset}>
        Try again
      </Button>
    </div>
  )
}
