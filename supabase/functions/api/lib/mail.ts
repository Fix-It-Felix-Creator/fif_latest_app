/**
 * Transactional email via Resend.
 *
 * The Cloud Functions used both nodemailer (SMTP) and the Resend SDK. Neither
 * runs on Deno, and Resend's REST API is a single POST, so it is called
 * directly — one less dependency in the bundle and no SMTP socket handling in
 * a serverless runtime.
 *
 * Secrets:
 *   RESEND_API_KEY   required to send at all
 *   FROM_EMAIL       defaults to no-reply@fixitfelixsoftwaresolutions.com
 *   FROM_NAME        defaults to "Fix It Felix Pro"
 */

export interface MailResult {
  ok: boolean;
  /** Set when sending was skipped rather than attempted. */
  skipped?: string;
  error?: string;
}

export function mailConfigured(): boolean {
  return Boolean(Deno.env.get('RESEND_API_KEY'));
}

export async function sendMail(args: {
  to: string;
  subject: string;
  html: string;
  replyTo?: string;
}): Promise<MailResult> {
  const key = Deno.env.get('RESEND_API_KEY');
  if (!key) {
    // Not configured is a deployment state, not a request failure — callers
    // decide whether that is fatal. The Cloud Functions made the same choice.
    console.warn('RESEND_API_KEY not set — email send skipped');
    return { ok: false, skipped: 'not_configured' };
  }

  const from = Deno.env.get('FROM_EMAIL') ??
    'no-reply@fixitfelixsoftwaresolutions.com';
  const name = Deno.env.get('FROM_NAME') ?? 'Fix It Felix Pro';

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `${name} <${from}>`,
        to: [args.to],
        subject: args.subject,
        html: args.html,
        ...(args.replyTo ? { reply_to: args.replyTo } : {}),
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      console.error('Resend send failed', res.status, body.slice(0, 300));
      return { ok: false, error: `resend_${res.status}` };
    }
    return { ok: true };
  } catch (e) {
    console.error('Resend send threw', String(e));
    return { ok: false, error: String(e) };
  }
}
