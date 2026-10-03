import { requireUser, json } from '../_shared/auth.ts';

/**
 * Permanently deletes the caller's own account.
 *
 * Supabase has no client-side "delete my account" call — removing an auth user
 * requires the service role. Deleting the auth user cascades to `profiles`
 * (FK ON DELETE CASCADE) and from there to every owner_id-scoped table.
 *
 * Storage objects are removed by the client (deleteUserDocuments) before this
 * is invoked, since the storage RLS policies already scope a user to their own
 * prefix.
 */
Deno.serve(async (req: Request) => {
  try {
    const { userId, admin } = await requireUser(req);

    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) return json({ error: error.message }, 400);

    return json({ ok: true, deleted: userId });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});
