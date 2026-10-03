/**
 * Transactional email templates.
 *
 * Lifted VERBATIM from the Cloud Functions (quotes/sendEmail.ts and
 * invoices/sendEmail.ts). Pure string builders with no data access, so the
 * email a customer receives is byte-identical to what they got before.
 */

/**
 * Base for assets embedded in emails (currently the logo).
 *
 * The templates were lifted verbatim and referenced a `PUBLIC_BASE_URL`
 * constant defined in the Cloud Function file — an external dependency the
 * lift silently dropped, which surfaced as a 500 on the first real send.
 *
 * It points at Firebase Hosting, which stays alive as the redirect shim for
 * share links already in customers' inboxes. Overridable so it can follow a
 * custom domain later; an email client cannot read a private Supabase bucket,
 * so the asset has to live somewhere publicly reachable.
 */
const PUBLIC_BASE_URL = Deno.env.get('EMAIL_ASSET_BASE_URL') ??
  'https://fifcloud.web.app';

/**
 * Support address shown in the email footer.
 *
 * The Cloud Function hardcoded `info@fixitfelixsoftwaresolution.com` —
 * SINGULAR "solution". Every other reference in the app, including the
 * privacy-policy and terms URLs and the `supportEmail` in remote config, uses
 * the PLURAL `fixitfelixsoftwaresolutions.com`. The singular looks like a
 * long-standing typo, which means customers replying to a quote email have
 * been writing to a domain that probably does not accept mail.
 *
 * Corrected to the plural and made overridable. If the singular domain really
 * is live, set EMAIL_SUPPORT_ADDRESS to restore it.
 */
const SUPPORT_EMAIL = Deno.env.get('EMAIL_SUPPORT_ADDRESS') ??
  'info@fixitfelixsoftwaresolutions.com';

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function renderQuoteEmail(args: {
  businessName: string;
  customerName: string;
  reference: string;
  url: string;
  message: string;
  validUntil: string | null;
  total: string | null;
}): string {
  const business = escapeHtml(args.businessName);
  const customer = escapeHtml(args.customerName);
  const ref = escapeHtml(args.reference);
  const url = escapeHtml(args.url);
  const userMsg = args.message
    ? `<tr><td style="padding:0 28px 18px;color:#D1D5DB;font-size:14px;line-height:1.55;">${escapeHtml(
        args.message
      ).replace(/\n/g, "<br>")}</td></tr>`
    : "";

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(`Your quote from ${args.businessName}`)}</title>
</head>
<body style="margin:0;padding:0;background:#0F172A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0F172A;">
  <tr>
    <td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
        <tr>
          <td align="center" style="padding-bottom:18px;">
            <img src="${PUBLIC_BASE_URL}/logo.jpg" width="64" height="64" alt="Fix It Felix Pro" style="display:block;width:64px;height:64px;border-radius:14px;border:0;outline:none;text-decoration:none;" />
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:0 16px 28px;">
            <div style="font-size:20px;font-weight:700;color:#F8FAFC;line-height:1.35;">
              Your quote from ${business} is ready to view
            </div>
          </td>
        </tr>
        <tr>
          <td>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#1E293B;border:1px solid #334155;border-radius:14px;">
              <tr>
                <td style="padding:24px 28px 8px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="font-size:18px;font-weight:700;color:#F8FAFC;">
                        Quote${ref ? ` #${ref}` : ""}
                      </td>
                      <td align="right">
                        <span style="display:inline-block;padding:5px 10px;background:#064E3B;color:#34D399;font-size:11px;font-weight:700;border-radius:999px;letter-spacing:0.4px;">Ready for review</span>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="padding:6px 28px 4px;color:#E2E8F0;font-size:14px;font-weight:600;">
                  ${customer}
                </td>
              </tr>
              ${args.validUntil ? `
              <tr>
                <td style="padding:0 28px 18px;color:#94A3B8;font-size:13px;">
                  Valid until ${escapeHtml(args.validUntil)}${args.total ? ` &nbsp;·&nbsp; <span style="color:#E2E8F0;font-weight:600;">${escapeHtml(args.total)}</span>` : ""}
                </td>
              </tr>` : args.total ? `
              <tr>
                <td style="padding:0 28px 18px;color:#E2E8F0;font-size:13px;font-weight:600;">
                  ${escapeHtml(args.total)}
                </td>
              </tr>` : `<tr><td style="padding-bottom:8px;"></td></tr>`}
              ${userMsg}
              <tr>
                <td align="center" style="padding:6px 28px 28px;">
                  <a href="${url}" style="display:inline-block;background:#F64C13;color:#FFFFFF;text-decoration:none;font-weight:700;font-size:15px;padding:14px 38px;border-radius:999px;">View your quote</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:24px 16px 0;color:#94A3B8;font-size:12px;line-height:1.55;">
            This email was sent by Fix It Felix Pro on behalf of ${business}.<br>
            You're receiving this because you requested a quote from this tradesperson.
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:14px 16px 0;color:#94A3B8;font-size:12px;line-height:1.55;">
            Need help? Contact us at
            <a href="mailto:${SUPPORT_EMAIL}" style="color:#E2E8F0;text-decoration:none;font-weight:600;">${SUPPORT_EMAIL}</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
}

export function renderInvoiceEmail(args: {
  businessName: string;
  customerName: string;
  reference: string;
  url: string;
  message: string;
  dueDate: string | null;
  total: string | null;
}): string {
  const business = escapeHtml(args.businessName);
  const customer = escapeHtml(args.customerName);
  const ref = escapeHtml(args.reference);
  const url = escapeHtml(args.url);
  const userMsg = args.message
    ? `<tr><td style="padding:0 28px 18px;color:#D1D5DB;font-size:14px;line-height:1.55;">${escapeHtml(
        args.message
      ).replace(/\n/g, "<br>")}</td></tr>`
    : "";

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(`Your invoice from ${args.businessName}`)}</title>
</head>
<body style="margin:0;padding:0;background:#0F172A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0F172A;">
  <tr>
    <td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
        <tr>
          <td align="center" style="padding-bottom:18px;">
            <img src="${PUBLIC_BASE_URL}/logo.jpg" width="64" height="64" alt="Fix It Felix Pro" style="display:block;width:64px;height:64px;border-radius:14px;border:0;outline:none;text-decoration:none;" />
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:0 16px 28px;">
            <div style="font-size:20px;font-weight:700;color:#F8FAFC;line-height:1.35;">
              Your invoice from ${business} is ready to view
            </div>
          </td>
        </tr>
        <tr>
          <td>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#1E293B;border:1px solid #334155;border-radius:14px;">
              <tr>
                <td style="padding:24px 28px 8px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="font-size:18px;font-weight:700;color:#F8FAFC;">
                        Invoice${ref ? ` #${ref}` : ""}
                      </td>
                      <td align="right">
                        <span style="display:inline-block;padding:5px 10px;background:#1E3A8A;color:#93C5FD;font-size:11px;font-weight:700;border-radius:999px;letter-spacing:0.4px;">Due</span>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="padding:6px 28px 4px;color:#E2E8F0;font-size:14px;font-weight:600;">
                  ${customer}
                </td>
              </tr>
              ${args.dueDate ? `
              <tr>
                <td style="padding:0 28px 18px;color:#94A3B8;font-size:13px;">
                  Due by ${escapeHtml(args.dueDate)}${args.total ? ` &nbsp;·&nbsp; <span style="color:#E2E8F0;font-weight:600;">${escapeHtml(args.total)}</span>` : ""}
                </td>
              </tr>` : args.total ? `
              <tr>
                <td style="padding:0 28px 18px;color:#E2E8F0;font-size:13px;font-weight:600;">
                  ${escapeHtml(args.total)}
                </td>
              </tr>` : `<tr><td style="padding-bottom:8px;"></td></tr>`}
              ${userMsg}
              <tr>
                <td align="center" style="padding:6px 28px 28px;">
                  <a href="${url}" style="display:inline-block;background:#F64C13;color:#FFFFFF;text-decoration:none;font-weight:700;font-size:15px;padding:14px 38px;border-radius:999px;">View your invoice</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:24px 16px 0;color:#94A3B8;font-size:12px;line-height:1.55;">
            This email was sent by Fix It Felix Pro on behalf of ${business}.<br>
            You're receiving this because this tradesperson has issued you an invoice.
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:14px 16px 0;color:#94A3B8;font-size:12px;line-height:1.55;">
            Need help? Contact us at
            <a href="mailto:${SUPPORT_EMAIL}" style="color:#E2E8F0;text-decoration:none;font-weight:600;">${SUPPORT_EMAIL}</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
}

