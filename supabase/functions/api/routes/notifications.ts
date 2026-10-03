import { admin, isAdmin, json } from '../lib/context.ts';
import type { Caller } from '../lib/context.ts';
import { fcmConfigured, sendToToken } from '../lib/fcm.ts';

/**
 * POST /notifications/send — admin broadcast.
 *
 * Writes an in-app record for every recipient and fans out a push. Admin-only:
 * the caller must be listed as active in `admin_roles`, which no client can
 * read or write.
 */
export async function sendNotification(
  req: Request,
  caller: Caller,
): Promise<Response> {
  if (!await isAdmin(caller.uid)) {
    return json({ success: false, message: 'Admin access required' }, 403);
  }

  try {
    const body = await req.json() as {
      title?: string;
      body?: string;
      type?: string;
      payload?: Record<string, unknown>;
      toAll?: boolean;
      toUserIds?: string[];
    };

    if (!body.title || !body.body) {
      return json(
        { success: false, message: 'title and body are required' },
        400,
      );
    }
    if (!body.toAll && !body.toUserIds?.length) {
      return json({
        success: false,
        message: 'Provide either toAll=true or a non-empty toUserIds array',
      }, 400);
    }

    let recipients: string[];
    if (body.toAll) {
      // Broadcast targets profiles, not auth.users: a profile row is what
      // makes an account real to this app, and it is one query rather than
      // paging the admin user list.
      const { data } = await admin().from('profiles').select('id');
      recipients = (data ?? []).map((r: { id: string }) => r.id);
    } else {
      recipients = body.toUserIds ?? [];
    }

    if (recipients.length === 0) {
      return json({ success: true, sent: 0, pushSent: 0, pushFailed: 0 });
    }

    // --- 1. In-app records ------------------------------------------------
    const rows = recipients.map((uid) => ({
      owner_id: uid,
      title: body.title,
      body: body.body,
      type: body.type ?? 'system',
      payload: body.payload ?? null,
      read: false,
    }));

    // Chunked: a broadcast to every user is one statement per 500 rows rather
    // than one giant insert that could exceed the request body limit.
    let sent = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const slice = rows.slice(i, i + 500);
      const { error } = await admin().from('notifications').insert(slice);
      if (error) {
        console.error('sendNotification: insert failed', error.message);
      } else {
        sent += slice.length;
      }
    }

    // --- 2. Push ----------------------------------------------------------
    let pushSent = 0;
    let pushFailed = 0;

    if (fcmConfigured()) {
      const data: Record<string, string> = { type: body.type ?? 'system' };
      for (const [k, v] of Object.entries(body.payload ?? {})) {
        if (v === null || v === undefined) continue;
        data[k] = typeof v === 'string' ? v : JSON.stringify(v);
      }

      const dead: string[] = [];
      for (let i = 0; i < recipients.length; i += 500) {
        const slice = recipients.slice(i, i + 500);
        const { data: tokens } = await admin()
          .from('fcm_tokens')
          .select('token')
          .in('owner_id', slice);

        await Promise.all((tokens ?? []).map(async (t: { token: string }) => {
          const result = await sendToToken(t.token, {
            title: body.title!,
            body: body.body!,
            data,
          });
          if (result === 'ok') pushSent++;
          else {
            pushFailed++;
            if (result === 'dead') dead.push(t.token);
          }
        }));
      }

      if (dead.length > 0) {
        await admin().from('fcm_tokens').delete().in('token', dead);
      }
    } else {
      console.warn('sendNotification: FCM not configured, in-app only');
    }

    return json({ success: true, sent, pushSent, pushFailed });
  } catch (err) {
    console.error('sendNotification failed', String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}
