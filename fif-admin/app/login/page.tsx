import { redirect } from 'next/navigation'
import { currentAdmin } from '@/lib/auth'
import { ThemeToggle } from '@/components/theme-toggle'
import { ENV_LABEL, FIF_ENV, IS_PRODUCTION, projectRef } from '@/lib/env'
import { cn } from '@/lib/utils'
import { LoginForm } from './login-form'

export const metadata = { title: 'Sign in · Fix It Felix Admin' }

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>
}) {
  const params = await searchParams
  if (await currentAdmin()) redirect(params.next || '/')

  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded bg-primary text-sm font-bold text-primary-foreground">
            F
          </div>
          <div className="flex-1">
            <h1 className="text-sm font-semibold leading-tight">Fix It Felix Admin</h1>
            <p className="text-[11px] text-muted-foreground">Staff access only</p>
          </div>
          {/* Here too: the login page is the one screen someone sees before
              they have a session, and it is where a wrong theme is most
              jarring. */}
          <ThemeToggle />
        </div>

        {/* Named before sign-in, not after. Which project a set of credentials
            is about to open is the thing someone most needs to know while they
            still have the option of closing the tab. */}
        <p
          className={cn(
            'mb-2 text-[11px]',
            IS_PRODUCTION ? 'font-medium text-destructive' : 'text-muted-foreground',
          )}
        >
          {ENV_LABEL[FIF_ENV]} · {projectRef()}
        </p>

        <LoginForm next={params.next} initialError={params.error} />

        <p className="mt-3 text-[11px] leading-relaxed text-muted-foreground">
          Sign in with the Fix It Felix account that holds your staff role. An app account with no
          role on this project cannot open the panel.
        </p>
      </div>
    </main>
  )
}
