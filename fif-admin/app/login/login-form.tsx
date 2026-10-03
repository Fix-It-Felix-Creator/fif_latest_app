'use client'

import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { supabaseBrowser } from '@/lib/supabase/client'

export function LoginForm({ next, initialError }: { next?: string; initialError?: string }) {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(initialError ?? null)
  const [busy, setBusy] = useState(false)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(null)

    const { error: signInError } = await supabaseBrowser().auth.signInWithPassword({
      email: email.trim(),
      password,
    })

    if (signInError) {
      setBusy(false)
      setError(signInError.message)
      return
    }

    // Signing in proves who they are, not that they belong here. The roster
    // check happens server-side; a valid tradesman account with no admin_roles
    // row lands back on this page rather than inside the panel.
    const res = await fetch('/api/session', { method: 'POST' })
    if (!res.ok) {
      await supabaseBrowser().auth.signOut()
      setBusy(false)
      setError('That account has no staff role on this project. Ask a super admin to add you.')
      return
    }

    router.replace(next || '/')
    router.refresh()
  }

  return (
    <Card>
      <CardBody className="pt-3">
        <form onSubmit={submit} className="space-y-3">
          <div className="space-y-1">
            <label htmlFor="email" className="text-[11px] font-medium text-muted-foreground">
              Email
            </label>
            <Input
              id="email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@fixitfelixsoftwaresolutions.com"
            />
          </div>
          <div className="space-y-1">
            <label htmlFor="password" className="text-[11px] font-medium text-muted-foreground">
              Password
            </label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
          </div>

          {error ? (
            <p
              role="alert"
              className="rounded border border-destructive/40 bg-destructive/10 px-2 py-1.5 text-[11px] text-destructive"
            >
              {error}
            </p>
          ) : null}

          <Button type="submit" size="lg" className="w-full" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </Button>
        </form>
      </CardBody>
    </Card>
  )
}
