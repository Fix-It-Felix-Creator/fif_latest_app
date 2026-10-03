import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Refreshes the Supabase session cookie on every request.
 *
 * Named `proxy` in a `proxy.ts`, which is what Next 16 renamed the middleware
 * convention to; a `middleware.ts` still runs but warns on every build.
 *
 * This middleware does NOT decide who gets in — it cannot, because the roster
 * lives in `admin_roles` and the Edge runtime has no business holding the
 * service role key. It keeps the token alive and bounces the signed-out;
 * `requireAdmin()` on each page is the actual gate. Two jobs, two places, and
 * the one that matters runs closest to the data.
 */
export default async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (list) => {
          list.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          list.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
        },
      },
    },
  )

  const {
    data: { user },
  } = await supabase.auth.getUser()

  // Signed out and asking for a page: send them to the login, remembering
  // where they were headed so the round trip is invisible.
  const path = request.nextUrl.pathname
  if (!user && path !== '/login') {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    url.searchParams.set('next', path + request.nextUrl.search)
    return NextResponse.redirect(url)
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
