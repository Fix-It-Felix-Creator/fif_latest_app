import { admin, json } from '../lib/context.ts';
import type { Caller } from '../lib/context.ts';
import { mailConfigured, sendMail } from '../lib/mail.ts';
import { renderInvoiceEmail, renderQuoteEmail } from '../render/email.ts';

/**
 * POST /quotes/send-email, POST /invoices/send-email
 *
 * Mints the share token if missing (same shape as share-link), flips a draft
 * to `sent`, and emails the customer the public link.
 *
 * The order matters: the token and status are committed BEFORE the send. If
 * the email fails the customer still has a valid link the tradesperson can
 * copy manually, whereas sending first and failing to persist would leave a
 * live link the app does not know about.
 */

function publicBaseUrl(): string {
  const explicit = Deno.env.get('PUBLIC_SHARE_BASE_URL');
  if (explicit) return explicit.replace(/\/+$/, '');
  return `${Deno.env.get('SUPABASE_URL')}/functions/v1/api`;
}

function mintToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const money = (v: unknown): string | null =>
  typeof v === 'number' || typeof v === 'string'
    ? `£${Number(v).toFixed(2)}`
    : null;

function fmtDate(v: unknown): string | null {
  if (!v) return null;
  const d = new Date(String(v));
  if (Number.isNaN(d.getTime())) return null;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${d.getUTCDate()} ${months[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

export async function sendDocumentEmail(
  req: Request,
  caller: Caller,
  kind: 'quote' | 'invoice',
): Promise<Response> {
  const table = kind === 'quote' ? 'quotes' : 'invoices';
  const idCol = kind === 'quote' ? 'quote_id' : 'invoice_id';
  const path = kind === 'quote' ? 'q' : 'i';

  if (!mailConfigured()) {
    return json({
      success: false,
      message: 'Email is not configured on this backend.',
    }, 503);
  }

  let id: string | undefined;
  let message = '';
  try {
    const body = await req.json() as Record<string, string>;
    id = body.quoteId ?? body.invoiceId;
    message = (body.message ?? '').trim();
  } catch { /* validated below */ }

  if (!id) {
    return json({ success: false, message: `${kind}Id is required` }, 400);
  }

  try {
    const { data: doc } = await admin()
      .from(table)
      .select('*')
      .eq('id', id)
      .eq('owner_id', caller.uid)
      .maybeSingle();

    if (!doc) {
      return json({ success: false, message: 'Not found' }, 404);
    }

    const customer = (doc.customer_snapshot ?? {}) as Record<string, string>;
    const to = customer.email;
    if (!to) {
      return json({
        success: false,
        message: 'This customer has no email address.',
      }, 400);
    }

    // Mint the share token if missing — same shape as getShareLink.
    let token = doc.share_token as string | null;
    if (!token) {
      token = mintToken();
      const { error } = await admin().from('document_shares').insert({
        token,
        owner_id: caller.uid,
        [idCol]: id,
      });
      if (error) return json({ success: false, message: error.message }, 500);
      await admin().from(table).update({ share_token: token }).eq('id', id);
    }

    // Flip a draft to sent, leaving customer-locked states alone.
    const status = String(doc.status ?? '');
    const terminal = kind === 'quote'
      ? ['sent', 'accepted', 'rejected']
      : ['sent', 'paid'];
    if (!terminal.includes(status)) {
      await admin()
        .from(table)
        .update({ status: 'sent', sent_at: new Date().toISOString() })
        .eq('id', id);
    }

    const { data: owner } = await admin()
      .from('profiles')
      .select('business_name, company_name, first_name, last_name, ' +
        'business_email, email')
      .eq('id', caller.uid)
      .maybeSingle();

    const businessName = (owner?.business_name || owner?.company_name ||
      [owner?.first_name, owner?.last_name].filter(Boolean).join(' ') ||
      'Your tradesperson') as string;

    const url = `${publicBaseUrl()}/${path}/${token}`;
    const reference = String(doc.reference ?? '');

    const html = kind === 'quote'
      ? renderQuoteEmail({
        businessName,
        customerName: customer.name ?? 'there',
        reference,
        url,
        message,
        validUntil: fmtDate(doc.quote_date),
        total: money(doc.total),
      })
      : renderInvoiceEmail({
        businessName,
        customerName: customer.name ?? 'there',
        reference,
        url,
        message,
        dueDate: fmtDate(doc.due_date),
        total: money(doc.total),
      });

    const subject = kind === 'quote'
      ? `Your quote from ${businessName}${reference ? ` — ${reference}` : ''}`
      : `Your invoice from ${businessName}${reference ? ` — ${reference}` : ''}`;

    const sent = await sendMail({
      to,
      subject,
      html,
      // Replies go to the tradesperson, not the no-reply sender.
      replyTo: (owner?.business_email || owner?.email) as string | undefined,
    });

    if (!sent.ok) {
      // The link and status are already committed, so the tradesperson can
      // still share it manually — say so rather than implying nothing happened.
      return json({
        success: false,
        message: 'The link was created but the email could not be sent.',
        url,
      }, 502);
    }

    return json({ success: true, url });
  } catch (err) {
    console.error(`send ${kind} email failed`, String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}
