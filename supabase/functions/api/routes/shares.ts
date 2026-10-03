import { admin, callerIp, html, json, rateLimit } from '../lib/context.ts';
import { notifyOneUser } from '../lib/notify.ts';
import {
  loadSharedInvoice,
  loadSharedQuote,
  markViewed,
} from '../data/shares.ts';
import * as Q from '../render/quote.ts';
import * as I from '../render/invoice.ts';

/**
 * Public share routes: `/q/:token`, `/q/:token/respond`, `/i/:token`.
 *
 * These are the URLs already sitting in customers' inboxes, so the paths and
 * the rendered HTML are preserved exactly.
 *
 * They are the only unauthenticated routes in the API. App Check used to sit
 * in front of them; it cannot gate Supabase, so each is rate-limited by IP
 * instead — a token is unguessable, but a leaked one should not be hammerable.
 */

const VIEW_LIMIT = 60; // per IP per minute
const RESPOND_LIMIT = 10; // responding is a once-per-quote action

export async function viewSharedQuote(
  req: Request,
  token: string,
): Promise<Response> {
  if (!token || token.length < 8) return html(Q.notFoundHtml(), 400);

  if (!await rateLimit(`q:view:${callerIp(req)}`, VIEW_LIMIT)) {
    return html(Q.errorHtml(), 429);
  }

  try {
    const share = await loadSharedQuote(token);
    if (!share) return html(Q.notFoundHtml(), 404);

    if (share.index.deletedAt) {
      return html(Q.deletedHtml(share.index.deletedAt), 410);
    }

    const page = Q.renderQuoteHtml(
      share.document,
      share.business,
      token,
      share.index,
    );

    // Fire-and-forget, only on first view. markViewed() updates
    // conditionally, so two simultaneous opens cannot both notify.
    if (!share.index.viewedAt) {
      queueMicrotask(async () => {
        try {
          const isFirst = await markViewed(token, 'quote', share.index.quoteId);
          if (!isFirst) return;
          await notifyOneUser({
            uid: share.index.uid,
            title: 'Quote opened',
            body: `${share.document.customer?.name ?? 'your customer'} just ` +
              `opened quote ${share.document.reference ?? '(no ref)'}.`,
            type: 'quote_opened',
            payload: { quoteId: share.index.quoteId, token },
          });
        } catch (err) {
          console.warn('Quote-opened notify failed', String(err));
        }
      });
    }

    return html(page);
  } catch (err) {
    console.error('viewSharedQuote failed', token, String(err));
    return html(Q.errorHtml(), 500);
  }
}

export async function viewSharedInvoice(
  req: Request,
  token: string,
): Promise<Response> {
  if (!token || token.length < 8) return html(I.notFoundHtml(), 400);

  if (!await rateLimit(`i:view:${callerIp(req)}`, VIEW_LIMIT)) {
    return html(I.errorHtml(), 429);
  }

  try {
    const share = await loadSharedInvoice(token);
    if (!share) return html(I.notFoundHtml(), 404);

    if (share.index.deletedAt) {
      return html(I.deletedHtml(share.index.deletedAt), 410);
    }

    const page = I.renderInvoiceHtml(
      share.document,
      share.business,
      token,
      share.index,
    );

    if (!share.index.viewedAt) {
      queueMicrotask(async () => {
        try {
          const isFirst = await markViewed(
            token,
            'invoice',
            share.index.quoteId,
          );
          if (!isFirst) return;
          await notifyOneUser({
            uid: share.index.uid,
            title: 'Invoice opened',
            body: `${share.document.customer?.name ?? 'your customer'} just ` +
              `opened invoice ${share.document.reference ?? '(no ref)'}.`,
            type: 'invoice_opened',
            payload: { invoiceId: share.index.quoteId, token },
          });
        } catch (err) {
          console.warn('Invoice-opened notify failed', String(err));
        }
      });
    }

    return html(page);
  } catch (err) {
    console.error('viewSharedInvoice failed', token, String(err));
    return html(I.errorHtml(), 500);
  }
}

/**
 * POST /q/:token/respond — the token IS the authorisation.
 *
 * Idempotent: a second response after the first is rejected with 409.
 */
export async function respondToShare(
  req: Request,
  token: string,
): Promise<Response> {
  if (!token || token.length < 8) {
    return json({ success: false, message: 'Invalid token' }, 400);
  }

  if (!await rateLimit(`q:respond:${callerIp(req)}`, RESPOND_LIMIT)) {
    return json({ success: false, message: 'Too many requests' }, 429);
  }

  let action: string | undefined;
  try {
    action = ((await req.json()) as { action?: string }).action;
  } catch {
    // falls through to validation below
  }

  if (action !== 'accept' && action !== 'reject') {
    return json(
      { success: false, message: "action must be 'accept' or 'reject'" },
      400,
    );
  }

  try {
    const share = await loadSharedQuote(token);
    if (!share) return json({ success: false, message: 'Quote not found' }, 404);

    if (share.index.deletedAt) {
      return json({
        success: false,
        message: 'This quote has been withdrawn by the tradesperson.',
      }, 410);
    }

    if (share.index.respondedAt) {
      return json({
        success: false,
        message: 'This quote has already been responded to.',
        status: share.index.respondedAction === 'reject'
          ? 'rejected'
          : 'accepted',
        respondedAt: share.index.respondedAt,
      }, 409);
    }

    const quote = share.document;

    // Don't allow further changes if the quote is already in a terminal state.
    if (quote.status === 'accepted' || quote.status === 'rejected') {
      return json({
        success: false,
        message: 'This quote is already finalised.',
        status: quote.status,
      }, 409);
    }

    const expiry = Q.quoteExpiry(quote.date, quote.expiry);
    if (expiry.expired) {
      return json({
        success: false,
        message:
          'This quote has expired. Please contact the tradesperson for an updated quote.',
        status: 'expired',
        expiresAt: expiry.expiresAt,
      }, 410);
    }

    const newStatus = action === 'accept' ? 'accepted' : 'rejected';
    const now = new Date().toISOString();

    // Guarded by `responded_at is null` so two clicks cannot both win. The
    // RTDB version read-then-wrote with no such guard.
    const { data: claimed } = await admin()
      .from('document_shares')
      .update({ responded_at: now, responded_action: action })
      .eq('token', token)
      .is('responded_at', null)
      .select('token');

    if (!(claimed ?? []).length) {
      return json({
        success: false,
        message: 'This quote has already been responded to.',
      }, 409);
    }

    // Mirror onto the quote — the owner's app reads status from there.
    await admin()
      .from('quotes')
      .update({ status: newStatus, responded_at: now })
      .eq('id', share.index.quoteId);

    const verb = action === 'accept' ? 'accepted' : 'declined';
    queueMicrotask(async () => {
      try {
        await notifyOneUser({
          uid: share.index.uid,
          title: `Quote ${verb}`,
          body: `${quote.customer?.name ?? 'your customer'} ${verb} quote ` +
            `${quote.reference ?? '(no ref)'}.`,
          type: 'quote_responded',
          payload: { quoteId: share.index.quoteId, token, status: newStatus },
        });
      } catch (err) {
        console.warn('respondToShare notify failed', String(err));
      }
    });

    return json({
      success: true,
      status: newStatus,
      respondedAt: Date.parse(now),
    });
  } catch (err) {
    console.error('respondToShare failed', token, String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}
