'use client'

import { createBrowserClient } from '@supabase/ssr'

/** The browser only ever signs in and out. Every read happens on the server. */
export function supabaseBrowser() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )
}
