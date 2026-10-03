/**
 * Re-serves the Supabase Edge Function's share pages with a correct
 * `Content-Type`.
 *
 * Supabase rewrites `text/html` to `text/plain` on the `*.supabase.co`
 * functions domain (anti-phishing on their shared domain — see
 * CUSTOM_DOMAIN.md), so the customer's browser shows page source instead of
 * the invoice, and iOS Safari offers it as a `.txt` download. The HTML itself
 * is fine; only the header is stripped. Proxying through a domain we control
 * and setting the header ourselves is enough to fix it, at no monthly cost.
 *
 * The URL shape deliberately matches the upstream exactly — `/q/:token`,
 * `/i/:token`, `/q/:token/respond` — because the quote page's Accept/Decline
 * buttons POST to a ROOT-RELATIVE `/q/<token>/respond` (render/quote.ts:810).
 * Serving the page under any path prefix would send that POST to a path that
 * does not exist.
 *
 * One deployment per environment; `UPSTREAM` selects which Supabase project.
 */

const UPSTREAM = process.env.UPSTREAM;

export default async function handler(req, res) {
  if (!UPSTREAM) {
    res.status(500).json({ error: 'UPSTREAM is not configured' });
    return;
  }

  const { kind, token, respond } = req.query;

  // The token is the entire authorisation for these pages, so refuse anything
  // that is not the shape we mint (base64url, 16 bytes) rather than passing
  // arbitrary path segments upstream.
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(token ?? '')) {
    res.status(400).send('Invalid link');
    return;
  }
  if (kind !== 'q' && kind !== 'i') {
    res.status(404).send('Not found');
    return;
  }

  const url = `${UPSTREAM}/${kind}/${encodeURIComponent(token)}` +
    (respond ? '/respond' : '');

  const init = { method: req.method, headers: {} };
  if (req.method === 'POST') {
    init.headers['content-type'] = 'application/json';
    // Vercel has already parsed a JSON body into req.body.
    init.body = JSON.stringify(req.body ?? {});
  }

  let upstream;
  try {
    upstream = await fetch(url, init);
  } catch (err) {
    res.status(502).send(`Could not reach the document service: ${err}`);
    return;
  }

  const body = await upstream.text();

  // The one thing this proxy exists to do. Upstream says text/plain because
  // the gateway rewrote it; the share routes only ever return HTML or JSON,
  // so anything that is not JSON is HTML.
  const upstreamType = upstream.headers.get('content-type') ?? '';
  const type = upstreamType.includes('json')
    ? 'application/json; charset=utf-8'
    : 'text/html; charset=utf-8';

  res.status(upstream.status);
  res.setHeader('Content-Type', type);
  // These pages are per-customer and revocable; never let a CDN hold them.
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Robots-Tag', 'noindex');
  res.send(body);
}
