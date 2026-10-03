import { requireUser, json } from '../_shared/auth.ts';

/**
 * Disables the caller's own account.
 *
 * Called from the delete-account dialog after the user re-authenticates.
 * `account_status` is server-owned — a direct client update is rejected by
 * profiles_guard_server_columns — so the write happens here under the service
 * role. The dialog signs the user out immediately afterwards.
 */
Deno.serve(async (req: Request) => {
  try {
    const { userId, admin } = await requireUser(req);

    const { error } = await admin
      .from('profiles')
      .update({
        account_status: 'disabled',
        deletion_requested_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) return json({ error: error.message }, 400);

    return json({ ok: true, status: 'disabled' });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});
