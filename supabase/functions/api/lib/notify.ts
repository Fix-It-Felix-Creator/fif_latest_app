import { admin } from './context.ts';
import { fcmConfigured, sendToToken } from './fcm.ts';

interface NotifyArgs {
  uid: string;
  title: string;
  body: string;
  type?: string;
  payload?: Record<string, unknown>;
}

/**
 * Drop one in-app notification AND fan out a native push to every device
 * registered for the user. Dead tokens are pruned on the way out.
 *
 * Ported from functions/src/lib/notify.ts. Two changes:
 *   - `notifications` and `fcm_tokens` are tables, so the push key no longer
 *     needs mangling and pruning is a plain delete.
 *   - A transient FCM failure no longer prunes the token; only an explicit
 *     UNREGISTERED does. The old code lumped invalid-argument in with dead
 *     tokens, which could unregister a working device on a malformed payload.
 */
export async function notifyOneUser(args: NotifyArgs): Promise<void> {
  const { uid, title, body, type = 'system', payload } = args;

  try {
    await admin().from('notifications').insert({
      owner_id: uid,
      title,
      body,
      type,
      payload: payload ?? null,
      read: false,
    });
  } catch (err) {
    console.warn('notifyOneUser: in-app record failed', uid, String(err));
  }

  if (!fcmConfigured()) {
    console.warn('notifyOneUser: FCM not configured, skipping push');
    return;
  }

  const { data: tokens } = await admin()
    .from('fcm_tokens')
    .select('token')
    .eq('owner_id', uid);

  if (!tokens?.length) return;

  const data: Record<string, string> = { type };
  if (payload) {
    for (const [k, v] of Object.entries(payload)) {
      if (v === null || v === undefined) continue;
      data[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }
  }

  const dead: string[] = [];
  await Promise.all(
    tokens.map(async (t: { token: string }) => {
      const result = await sendToToken(t.token, { title, body, data });
      if (result === 'dead') dead.push(t.token);
    }),
  );

  if (dead.length > 0) {
    await admin()
      .from('fcm_tokens')
      .delete()
      .eq('owner_id', uid)
      .in('token', dead);
  }
}
