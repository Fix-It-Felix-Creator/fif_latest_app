'use server'

import { currentAdmin } from '@/lib/auth'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'
import { viewableUrls } from '@/lib/queries'

/**
 * Signed links to one person's identity photographs.
 *
 * A server action rather than signing every row with the page: a signed URL
 * expires, so signing links nobody opens is both waste and a shorter useful
 * life for the ones somebody does.
 *
 * Permission is resolved from the caller's own session here, not assumed from
 * the page that rendered the button. These are somebody's passport and face.
 */
export async function signedDocuments(userId: string): Promise<string[]> {
  const actor = await currentAdmin()
  if (!actor || !can(actor.role, 'reviewVerification')) return []

  const { data } = await supabaseAdmin()
    .from('profiles')
    .select('document_urls, selfie_url')
    .eq('id', userId)
    .maybeSingle()

  if (!data) return []

  const paths = [
    ...((data.document_urls as string[] | null) ?? []),
    ...(data.selfie_url ? [data.selfie_url as string] : []),
  ]
  const signed = await viewableUrls(paths, 'user-documents')
  return signed.map((s) => s.url).filter((u): u is string => Boolean(u))
}
