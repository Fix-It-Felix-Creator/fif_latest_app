import { NextResponse } from 'next/server'
import { currentAdmin } from '@/lib/auth'
import { supabaseAdmin } from '@/lib/supabase/server'

/**
 * "Is the account I just signed in as actually staff?"
 *
 * The login form asks this instead of guessing, because the answer lives in
 * `admin_roles` — a table with RLS on and no policies, which the browser
 * cannot read at all. A tradesman signing in with their app credentials gets a
 * 403 and is signed straight back out, so an ordinary user account never
 * leaves a half-open session sitting on the panel's origin.
 */
export async function POST() {
  const admin = await currentAdmin()
  if (!admin) return NextResponse.json({ ok: false }, { status: 403 })

  // Last seen is stamped here rather than on every page render: this route
  // fires once per sign-in, which is exactly the granularity the roster page
  // reports. Failure is ignored — nobody should be locked out because a
  // bookkeeping column did not update.
  await supabaseAdmin()
    .from('admin_roles')
    .update({ last_seen_at: new Date().toISOString() })
    .eq('user_id', admin.userId)

  return NextResponse.json({ ok: true, role: admin.role })
}
