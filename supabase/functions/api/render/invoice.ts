/**
 * Public invoice viewer — presentation layer.
 *
 * Lifted VERBATIM from functions/src/invoices/viewSharedInvoice.ts, for the
 * same reason as render/quote.ts: these are pure string builders, so keeping
 * them byte-identical means the page a customer opens is unchanged. Only the
 * loader feeding them moved.
 */

export interface ShareIndex {
  uid: string;
  invoiceId: string;
  createdAt: number;
  viewedAt?: number;
  deletedAt?: number;
}

export interface InvoiceRtdb {
  reference?: string;
  title?: string;
  status?: string;
  date?: number;
  dueDate?: number;
  total?: number;
  createdAt?: number;
  paymentMethod?: string;
  bankSnapshot?: {
    bankName?: string;
    accountNumber?: string;
    sortCode?: string;
  };
  customer?: {
    name?: string;
    email?: string;
    phone?: string;
  };
  lines?: Array<{
    quantity?: number;
    rate?: number;
    unitMarkup?: number;
    discount?: number;
    kind?: string;
    /** Authoritative total, computed by the database. */
    lineTotal?: number;
    item?: { name?: string; itemCode?: string };
  }>;
  staff?: Array<{
    quantity?: number;
    rate?: number;
    unitMarkup?: number;
    payType?: string;
    rateType?: string;
    /** Authoritative total, computed by the database. */
    lineTotal?: number;
    staff?: { name?: string };
  }>;
  terms?: Array<{
    id?: string;
    name?: string;
    details?: string;
  }>;
  attachedPhotos?: Array<{
    id?: string;
    title?: string;
    description?: string;
    url?: string;
  }>;
  attachedVideos?: Array<{
    id?: string;
    title?: string;
    description?: string;
    url?: string;
    thumbnailUrl?: string;
  }>;
  attachedFiles?: Array<{
    id?: string;
    title?: string;
    description?: string;
    url?: string;
    fileName?: string;
    mimeType?: string;
    sizeBytes?: number;
  }>;
  attachedNotes?: Array<{
    id?: string;
    title?: string;
    body?: string;
  }>;
}

export function pickBusinessName(u: {
  businessName?: string;
  firstName?: string;
  lastName?: string;
}): string {
  if (u.businessName && u.businessName.trim().length > 0) {
    return u.businessName.trim();
  }
  const full = [u.firstName ?? "", u.lastName ?? ""]
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .join(" ");
  return full.length > 0 ? full : "Your tradesperson";
}

function fmtMoney(v: number | undefined | null): string {
  const n = typeof v === "number" && Number.isFinite(v) ? v : 0;
  return `£${n.toFixed(2)}`;
}

function fmtDate(ms: number | undefined | null): string {
  if (typeof ms !== "number" || !Number.isFinite(ms)) return "—";
  const d = new Date(ms);
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function lineTotal(l: NonNullable<InvoiceRtdb["lines"]>[number]): number {
  // Prefer the database's value. It is a GENERATED ALWAYS column using the
  // same formula as QuoteLineDraft.lineTotal in the app, so preferring it
  // guarantees the page and the app agree.
  //
  // The fallback below previously read `gross - discount`, treating a
  // PERCENTAGE as an absolute amount: a 10% discount on £750 rendered as £740
  // instead of £675. The invoice viewer already had the correct formula, so
  // quotes and invoices disagreed with each other as well as with the app.
  if (typeof l.lineTotal === "number" && Number.isFinite(l.lineTotal)) {
    return Math.max(0, l.lineTotal);
  }
  const qty = l.quantity ?? 1;
  const rate = l.rate ?? 0;
  const markup = l.unitMarkup ?? 0;
  const discount = l.discount ?? 0;
  const gross = (rate + markup) * qty;
  const pct = Math.max(0, Math.min(100, discount)) / 100;
  return Math.max(0, gross * (1 - pct));
}

function staffTotal(s: NonNullable<InvoiceRtdb["staff"]>[number]): number {
  if (typeof s.lineTotal === "number" && Number.isFinite(s.lineTotal)) {
    return Math.max(0, s.lineTotal);
  }
  const qty = s.quantity ?? 1;
  const rate = s.rate ?? 0;
  return rate * qty;
}

/// Human label for the stored labour rate method wire value.
function labourRateLabel(wire?: string): string {
  switch ((wire ?? "").toLowerCase()) {
    case "weekend":
      return "Weekend";
    case "emergency":
      return "Emergency";
    case "sociable":
      return "Sociable";
    default:
      return "Standard";
  }
}

function sortCodeFormatted(raw: string | undefined): string {
  const d = (raw ?? "").replace(/-/g, "");
  if (d.length !== 6) return d;
  return `${d.substring(0, 2)}-${d.substring(2, 4)}-${d.substring(4, 6)}`;
}

function renderPaymentBlock(
  invoice: InvoiceRtdb,
  reference: string
): string {
  const method = (invoice.paymentMethod ?? "cash").toLowerCase();
  if (method === "bankdeposit") {
    const snap = invoice.bankSnapshot;
    if (!snap || !(snap.bankName || snap.accountNumber || snap.sortCode)) {
      return `<div class="section-title">Payment</div>
        <div class="card"><div class="payment-note">
          Pay by bank deposit. Bank details to follow.
        </div></div>`;
    }
    const bankName = escapeHtml(snap.bankName ?? "—");
    const account = escapeHtml(snap.accountNumber ?? "—");
    const sort = escapeHtml(sortCodeFormatted(snap.sortCode));
    const refStr = escapeHtml(reference);
    return `<div class="section-title">Bank deposit details</div>
      <div class="card pay-card">
        <div class="pay-row"><span class="pay-label">Bank</span><span class="pay-value">${bankName}</span></div>
        <div class="pay-row"><span class="pay-label">Account number</span><span class="pay-value">${account}</span></div>
        <div class="pay-row"><span class="pay-label">Sort code</span><span class="pay-value">${sort}</span></div>
        <div class="pay-note">Please reference invoice <strong>${refStr}</strong> when paying.</div>
      </div>`;
  }
  return `<div class="section-title">Payment</div>
    <div class="card"><div class="payment-note">
      Pay in cash on completion of the work.
    </div></div>`;
}

export function renderInvoiceHtml(
  inv: InvoiceRtdb,
  businessName: string,
  token: string
): string {
  const ref = escapeHtml(inv.reference ?? "");
  const title = escapeHtml(inv.title ?? "Invoice");
  const customerName = escapeHtml(inv.customer?.name ?? "Customer");
  const customerEmail = inv.customer?.email
    ? escapeHtml(inv.customer.email)
    : "";
  const issueDate = escapeHtml(fmtDate(inv.date));
  const dueDate = escapeHtml(fmtDate(inv.dueDate));
  const business = escapeHtml(businessName);
  const total = escapeHtml(fmtMoney(inv.total));

  const status = (inv.status ?? "sent").toLowerCase();
  const statusBadge =
    status === "paid"
      ? '<div class="badge badge-ok">Paid</div>'
      : status === "cancelled"
      ? '<div class="badge badge-stale">Cancelled</div>'
      : '<div class="badge">Due</div>';

  const lines = inv.lines ?? [];
  const staff = inv.staff ?? [];

  const itemsRows = lines
    .map((l) => {
      const name = escapeHtml(l.item?.name ?? "Item");
      const qty = l.quantity ?? 1;
      const kind =
        (l.kind ?? "").toLowerCase() === "material" ? "Material" : "Service";
      const t = escapeHtml(fmtMoney(lineTotal(l)));
      return `<tr>
        <td>
          <div class="item-name">${name}</div>
          <div class="item-meta">${kind} · Qty ${qty}</div>
        </td>
        <td class="num">${t}</td>
      </tr>`;
    })
    .join("");

  const staffRows = staff
    .map((s) => {
      const name = escapeHtml(s.staff?.name ?? "Labour");
      const qty = s.quantity ?? 1;
      const pay = (s.payType ?? "hour").toLowerCase();
      const unit = pay === "day" ? "day" : "hour";
      const plural = qty === 1 ? "" : "s";
      const method = escapeHtml(labourRateLabel(s.rateType));
      const unitRate = escapeHtml(fmtMoney(s.rate ?? 0));
      const t = escapeHtml(fmtMoney(staffTotal(s)));
      return `<tr>
        <td>
          <div class="item-name">${name}</div>
          <div class="item-meta">
            <span class="rate-badge">${method} rate</span>
            ${qty} ${unit}${plural} × ${unitRate}
          </div>
        </td>
        <td class="num">${t}</td>
      </tr>`;
    })
    .join("");

  const termsBlock = renderTermsBlock(inv.terms ?? []);
  const paymentBlock = renderPaymentBlock(inv, inv.reference ?? "");
  const attachmentsBlock = renderAttachmentsBlock(
    token,
    inv.attachedPhotos ?? [],
    inv.attachedVideos ?? [],
    inv.attachedFiles ?? []
  );
  const notesBlock = renderNotesBlock(inv.attachedNotes ?? []);

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="robots" content="noindex" />
<title>Invoice ${ref} — ${business}</title>
<style>
  :root {
    --brand: #F64C13;
    --bg: #F5F5F7;
    --card: #FFFFFF;
    --line: #E5E7EB;
    --ink: #1F2937;
    --muted: #6B7280;
    --soft: #9CA3AF;
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    background: var(--bg);
    color: var(--ink);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .wrap { max-width: 640px; margin: 0 auto; padding: 24px 16px 56px; }
  .header { text-align: center; margin-bottom: 18px; }
  .from {
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 0.7px;
    color: var(--muted);
    margin-bottom: 4px;
  }
  .business { font-size: 18px; font-weight: 700; color: var(--ink); }
  .card {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--line);
    padding: 18px;
    margin-bottom: 14px;
  }
  .ref-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin-bottom: 10px;
  }
  .ref {
    font-size: 11px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--muted);
    font-weight: 600;
  }
  .badge {
    background: rgba(246, 76, 19, 0.1);
    color: var(--brand);
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 999px;
    letter-spacing: 0.4px;
  }
  .badge-ok { background: #D1FAE5; color: #065F46; }
  .badge-stale { background: #E5E7EB; color: #4B5563; }
  .title {
    font-size: 22px;
    font-weight: 800;
    line-height: 1.25;
    margin: 4px 0 14px;
  }
  .meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px 16px;
  }
  .meta-label {
    font-size: 11px;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 2px;
  }
  .meta-value { font-size: 14px; color: var(--ink); font-weight: 600; }
  .section-title {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.7px;
    color: var(--muted);
    font-weight: 700;
    margin: 0 0 8px 4px;
  }
  table { width: 100%; border-collapse: collapse; }
  td {
    padding: 12px 0;
    border-bottom: 1px solid var(--line);
    vertical-align: top;
  }
  tr:last-child td { border-bottom: 0; }
  td.num {
    text-align: right;
    font-weight: 600;
    color: var(--brand);
    white-space: nowrap;
  }
  .item-name { font-size: 14px; font-weight: 600; color: var(--ink); }
  .item-meta { font-size: 11px; color: var(--muted); margin-top: 2px; }
  .rate-badge { display: inline-block; font-size: 10px; font-weight: 700; color: #f64c13; background: rgba(246, 76, 19, 0.12); border-radius: 4px; padding: 1px 6px; margin-right: 6px; vertical-align: middle; }
  .labour-note { font-size: 11px; color: var(--muted); margin: 6px 2px 0; line-height: 1.4; }
  .total-card {
    background: rgba(246, 76, 19, 0.08);
    border: 1px solid rgba(246, 76, 19, 0.2);
  }
  .total-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .total-label { font-size: 15px; font-weight: 700; color: var(--ink); }
  .total-value { font-size: 22px; font-weight: 800; color: var(--brand); }
  .pay-card { padding: 16px 18px; }
  .pay-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    padding: 8px 0;
    border-bottom: 1px solid var(--line);
  }
  .pay-row:last-of-type { border-bottom: 0; }
  .pay-label {
    font-size: 12px;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }
  .pay-value { font-size: 14px; font-weight: 700; color: var(--ink); }
  .pay-note {
    margin-top: 10px;
    font-size: 12px;
    color: var(--muted);
    line-height: 1.4;
  }
  .payment-note { color: var(--muted); font-size: 14px; }
  .terms-card {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--line);
    padding: 4px 0;
    margin-top: 14px;
  }
  details.term { border-bottom: 1px solid var(--line); }
  details.term:last-child { border-bottom: 0; }
  details.term > summary {
    cursor: pointer;
    list-style: none;
    padding: 14px 16px;
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 14px;
    font-weight: 600;
    color: var(--ink);
  }
  details.term > summary::-webkit-details-marker { display: none; }
  details.term > summary::after {
    content: "";
    margin-left: auto;
    width: 8px;
    height: 8px;
    border-right: 2px solid var(--soft);
    border-bottom: 2px solid var(--soft);
    transform: rotate(45deg);
    transition: transform 0.15s ease;
  }
  details.term[open] > summary::after { transform: rotate(-135deg); }
  details.term > .term-body {
    padding: 0 16px 14px;
    font-size: 13px;
    line-height: 1.55;
    color: var(--muted);
    white-space: pre-wrap;
  }
  .footer {
    text-align: center;
    margin-top: 24px;
    color: var(--soft);
    font-size: 11px;
  }
  .photo-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px;
  }
  .photo-cell {
    position: relative;
    aspect-ratio: 1 / 1;
    border-radius: 8px;
    overflow: hidden;
    background: #f3f4f6;
    border: 1px solid var(--line);
  }
  .photo-cell img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .photo-cell .dl {
    position: absolute;
    right: 6px;
    bottom: 6px;
    background: rgba(0,0,0,0.6);
    color: #fff;
    font-size: 11px;
    font-weight: 700;
    padding: 4px 8px;
    border-radius: 999px;
    text-decoration: none;
  }
  .att-card {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--line);
    padding: 14px 16px;
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
  }
  .att-card:last-child { margin-bottom: 0; }
  .att-thumb {
    width: 76px;
    height: 52px;
    border-radius: 8px;
    background: #e5e7eb;
    flex-shrink: 0;
    overflow: hidden;
    position: relative;
  }
  .att-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .att-thumb .play {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-size: 18px;
    text-shadow: 0 1px 2px rgba(0,0,0,0.6);
  }
  .att-icon {
    width: 40px;
    height: 40px;
    border-radius: 10px;
    background: rgba(20, 184, 166, 0.12);
    color: #14B8A6;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    font-weight: 800;
    flex-shrink: 0;
  }
  .att-meta { flex: 1; min-width: 0; }
  .att-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--ink);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .att-sub {
    font-size: 11px;
    color: var(--muted);
    margin-top: 2px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .att-dl {
    background: var(--brand);
    color: #fff;
    font-size: 12px;
    font-weight: 700;
    padding: 8px 12px;
    border-radius: 8px;
    text-decoration: none;
    flex-shrink: 0;
  }
  .note-card {
    background: var(--card);
    border-radius: 14px;
    border: 1px solid var(--line);
    padding: 14px 16px;
    margin-bottom: 8px;
  }
  .note-card:last-child { margin-bottom: 0; }
  .note-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--ink);
    margin-bottom: 6px;
  }
  .note-body {
    font-size: 13px;
    line-height: 1.55;
    color: var(--muted);
    white-space: pre-wrap;
  }
</style>
</head>
<body>
  <div class="wrap">
    <div class="header">
      <div class="from">Invoice from</div>
      <div class="business">${business}</div>
    </div>

    <div class="card">
      <div class="ref-row">
        <div class="ref">${ref}</div>
        ${statusBadge}
      </div>
      <div class="title">${title}</div>
      <div class="meta-grid">
        <div>
          <div class="meta-label">Bill to</div>
          <div class="meta-value">${customerName}</div>
          ${customerEmail
            ? `<div class="item-meta">${customerEmail}</div>`
            : ""}
        </div>
        <div>
          <div class="meta-label">Issued</div>
          <div class="meta-value">${issueDate}</div>
        </div>
        <div>
          <div class="meta-label">Due</div>
          <div class="meta-value">${dueDate}</div>
        </div>
      </div>
    </div>

    ${itemsRows.length > 0
      ? `<div class="section-title">Services &amp; Materials</div>
         <div class="card"><table><tbody>${itemsRows}</tbody></table></div>`
      : ""}

    ${staffRows.length > 0
      ? `<div class="section-title">Labour charges</div>
         <div class="card"><table><tbody>${staffRows}</tbody></table></div>
         <div class="labour-note">Each labour charge shows the rate method
         applied and the price per ${(staff[0]?.payType ?? "hour").toLowerCase() === "day" ? "day" : "hour"} —
         no hidden markup.</div>`
      : ""}

    <div class="card total-card">
      <div class="total-row">
        <div class="total-label">Total due</div>
        <div class="total-value">${total}</div>
      </div>
    </div>

    ${paymentBlock}

    ${attachmentsBlock}

    ${notesBlock}

    ${termsBlock}

    <div class="footer">
      Sent securely via Fix It Felix Pro
    </div>
  </div>
</body>
</html>`;
}

function renderTermsBlock(
  terms: NonNullable<InvoiceRtdb["terms"]>
): string {
  if (!terms || terms.length === 0) return "";
  const items = terms
    .map((t) => {
      const name = escapeHtml(t.name ?? "Term");
      const details = (t.details ?? "").trim();
      return `<details class="term">
        <summary>${name}</summary>
        <div class="term-body">${
          details ? escapeHtml(details) : "No additional details."
        }</div>
      </details>`;
    })
    .join("");
  return `<div class="section-title">Terms &amp; Conditions</div>
  <div class="terms-card">${items}</div>`;
}

function renderAttachmentsBlock(
  token: string,
  photos: NonNullable<InvoiceRtdb["attachedPhotos"]>,
  videos: NonNullable<InvoiceRtdb["attachedVideos"]>,
  files: NonNullable<InvoiceRtdb["attachedFiles"]>
): string {
  const hasAny = photos.length > 0 || videos.length > 0 || files.length > 0;
  if (!hasAny) return "";

  // All asset URLs go through the proxy under the same token. The
  // raw Firebase Storage URL never appears in the rendered HTML.
  const t = encodeURIComponent(token);
  const view = (kind: string, id: string): string =>
    `/i/${t}/v/${kind}/${encodeURIComponent(id)}`;
  const dl = (kind: string, id: string): string =>
    `/i/${t}/d/${kind}/${encodeURIComponent(id)}`;

  let out = `<div class="section-title">Attachments</div>`;

  if (photos.length > 0) {
    const cells = photos
      .map((p) => {
        const id = (p.id ?? "").trim();
        if (!id) return "";
        const title = escapeAttr(p.title ?? "photo");
        return `<div class="photo-cell">
          <img src="${view("photo", id)}" alt="${title}" loading="lazy" />
          <a class="dl" href="${dl("photo", id)}">Download</a>
        </div>`;
      })
      .join("");
    out += `<div class="photo-grid">${cells}</div>`;
  }

  if (videos.length > 0) {
    const cards = videos
      .map((v) => {
        const id = (v.id ?? "").trim();
        if (!id) return "";
        const title = escapeHtml(v.title ?? "Video");
        const desc = (v.description ?? "").trim();
        const thumbHtml =
          v.thumbnailUrl !== undefined && v.thumbnailUrl !== null
            ? `<img src="${view("thumb", id)}" alt="" loading="lazy" />`
            : "";
        return `<div class="att-card">
          <div class="att-thumb">${thumbHtml}<div class="play">▶</div></div>
          <div class="att-meta">
            <div class="att-title">${title}</div>
            ${desc ? `<div class="att-sub">${escapeHtml(desc)}</div>` : ""}
          </div>
          <a class="att-dl" href="${dl("video", id)}">Download</a>
        </div>`;
      })
      .join("");
    out += `<div style="margin-top:14px">${cards}</div>`;
  }

  if (files.length > 0) {
    const cards = files
      .map((f) => {
        const id = (f.id ?? "").trim();
        if (!id) return "";
        const title = escapeHtml(f.title || f.fileName || "File");
        const fname = (f.fileName ?? "").trim();
        const size = fmtBytes(f.sizeBytes);
        const sub = [fname, size].filter(Boolean).join(" · ");
        const fam = guessFamily(f.mimeType, f.fileName);
        return `<div class="att-card">
          <div class="att-icon">${fam}</div>
          <div class="att-meta">
            <div class="att-title">${title}</div>
            ${sub ? `<div class="att-sub">${escapeHtml(sub)}</div>` : ""}
          </div>
          <a class="att-dl" href="${dl("file", id)}">Download</a>
        </div>`;
      })
      .join("");
    out += `<div style="margin-top:14px">${cards}</div>`;
  }

  return out;
}

function renderNotesBlock(
  notes: NonNullable<InvoiceRtdb["attachedNotes"]>
): string {
  if (!notes || notes.length === 0) return "";
  const cards = notes
    .map((n) => {
      const title = escapeHtml((n.title ?? "").trim() || "Note");
      const body = (n.body ?? "").trim();
      return `<div class="note-card">
        <div class="note-title">${title}</div>
        ${body ? `<div class="note-body">${escapeHtml(body)}</div>` : ""}
      </div>`;
    })
    .join("");
  return `<div class="section-title">Notes</div>${cards}`;
}

function escapeAttr(s: string): string {
  return escapeHtml(s);
}

function fmtBytes(b?: number): string {
  if (!b || b <= 0) return "";
  if (b < 1024 * 1024) return `${Math.round(b / 1024)} KB`;
  return `${(b / (1024 * 1024)).toFixed(1)} MB`;
}

function guessFamily(mime?: string, name?: string): string {
  const m = (mime ?? "").toLowerCase();
  const n = (name ?? "").toLowerCase();
  if (m.includes("pdf") || n.endsWith(".pdf")) return "PDF";
  if (m.includes("image")) return "IMG";
  if (m.includes("word") || n.endsWith(".docx") || n.endsWith(".doc")) {
    return "DOC";
  }
  if (m.includes("sheet") || n.endsWith(".xlsx") || n.endsWith(".xls")) {
    return "XLS";
  }
  if (m.includes("zip") || n.endsWith(".zip")) return "ZIP";
  return "FILE";
}

export function deletedHtml(deletedAt: number): string {
  const when = fmtDate(deletedAt);
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Invoice no longer available</title>
<style>
  body {
    margin: 0;
    background: #F5F5F7;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    color: #1F2937;
  }
  .box { text-align: center; padding: 32px; max-width: 380px; }
  h1 { font-size: 20px; margin: 0 0 8px; color: #B91C1C; }
  p { color: #6B7280; font-size: 14px; line-height: 1.5; margin: 0 0 4px; }
  .meta { font-size: 12px; color: #9CA3AF; margin-top: 12px; }
</style></head>
<body><div class="box">
  <h1>Invoice withdrawn</h1>
  <p>The tradesperson removed this invoice.</p>
  <p>If you still need a copy, get in touch with them directly.</p>
  <div class="meta">Withdrawn on ${when}</div>
</div></body></html>`;
}

export function notFoundHtml(): string {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Invoice unavailable</title>
<style>
  body {
    margin: 0;
    background: #F5F5F7;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    color: #1F2937;
  }
  .box { text-align: center; padding: 32px; max-width: 360px; }
  h1 { font-size: 20px; margin: 0 0 8px; }
  p { color: #6B7280; font-size: 14px; line-height: 1.5; margin: 0; }
</style></head>
<body><div class="box">
  <h1>Invoice unavailable</h1>
  <p>This invoice link is no longer valid. Ask the sender to share a fresh link.</p>
</div></body></html>`;
}

export function errorHtml(): string {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Something went wrong</title>
<style>
  body {
    margin: 0;
    background: #F5F5F7;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    color: #1F2937;
  }
  .box { text-align: center; padding: 32px; max-width: 360px; }
  h1 { font-size: 20px; margin: 0 0 8px; }
  p { color: #6B7280; font-size: 14px; line-height: 1.5; margin: 0; }
</style></head>
<body><div class="box">
  <h1>Something went wrong</h1>
  <p>We couldn't load this invoice right now. Please try again in a moment.</p>
</div></body></html>`;
}
