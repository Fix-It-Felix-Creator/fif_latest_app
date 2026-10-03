import { admin } from '../lib/context.ts';
import type { QuoteRtdb, ShareIndex } from '../render/quote.ts';
import type { InvoiceRtdb } from '../render/invoice.ts';

/**
 * Loads shared documents by public token and reshapes them into the exact
 * objects the renderers expect.
 *
 * Two things disappeared in the move:
 *
 *  - `resolveEnvForPath` / `rebindEnv`. A token could have been minted by
 *    either the staging or production RTDB instance, so the old code had to
 *    probe both and rebind the request. Dev and prod are now separate Supabase
 *    projects with separate databases, so a token can only exist in the
 *    project serving the request. The whole cross-environment dance is gone.
 *
 *  - The `/quoteShares/{token}` index. It existed because RTDB cannot query
 *    across a node by a child value; `document_shares` is a table with `token`
 *    as its primary key, so the lookup is direct.
 */

const NUM = (v: unknown): number | undefined =>
  v == null ? undefined : Number(v);

const MS = (v: unknown): number | undefined =>
  v == null ? undefined : new Date(String(v)).getTime();

export interface LoadedShare<T> {
  index: ShareIndex;
  document: T;
  business: string;
  ownerEmail?: string;
}

/** Row from `document_shares`, mapped to the shape the renderers expect. */
function toIndex(row: Record<string, unknown>, documentId: string): ShareIndex {
  return {
    uid: String(row.owner_id),
    quoteId: documentId,
    createdAt: MS(row.created_at) ?? Date.now(),
    viewedAt: MS(row.viewed_at),
    respondedAt: MS(row.responded_at),
    respondedAction: (row.responded_action as 'accept' | 'reject') ?? undefined,
    deletedAt: MS(row.deleted_at),
  };
}

async function loadOwner(uid: string) {
  const { data } = await admin()
    .from('profiles')
    .select(
      'business_name, first_name, last_name, business_email, email, ' +
        'company_name, bank_name, bank_account_number, bank_sort_code',
    )
    .eq('id', uid)
    .maybeSingle();
  return data ?? {};
}

/** Child rows come back unordered; the renderers assume document order. */
function sorted<T extends { sort_order?: number }>(rows: T[] | null): T[] {
  return [...(rows ?? [])].sort(
    (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0),
  );
}

function mapLines(rows: Record<string, unknown>[]) {
  return sorted(rows as never).map((l: Record<string, unknown>) => ({
    quantity: NUM(l.quantity),
    rate: NUM(l.rate),
    unitMarkup: NUM(l.unit_markup),
    discount: NUM(l.discount),
    kind: l.kind as string | undefined,
    // Computed by Postgres as a GENERATED ALWAYS column, so it is the same
    // number the app shows. Passed through so the page cannot disagree with
    // the app about what a line costs.
    lineTotal: NUM(l.line_total),
    item: {
      name: (l.item_name as string) ?? '',
      itemCode: (l.item_code as string) ?? undefined,
    },
  }));
}

function mapLabour(rows: Record<string, unknown>[]) {
  return sorted(rows as never).map((s: Record<string, unknown>) => ({
    quantity: NUM(s.quantity),
    rate: NUM(s.rate),
    payType: s.pay_type as string | undefined,
    rateType: s.rate_type as string | undefined,
    lineTotal: NUM(s.line_total),
    staff: { name: (s.staff_name as string) ?? '' },
  }));
}

function mapTerms(rows: Record<string, unknown>[]) {
  return sorted(rows as never).map((t: Record<string, unknown>) => ({
    id: String(t.id ?? ''),
    name: (t.name as string) ?? '',
    details: (t.details as string) ?? '',
  }));
}

/**
 * The four `attached*` arrays were separate RTDB lists; they are one child
 * table split by `kind`, so they are partitioned back out here.
 */
function mapAttachments(rows: Record<string, unknown>[]) {
  const all = sorted(rows as never) as Record<string, unknown>[];
  const of = (kind: string) => all.filter((a) => a.kind === kind);

  return {
    attachedPhotos: of('photo').map((a) => ({
      id: String(a.id ?? ''),
      title: (a.title as string) ?? '',
      description: (a.description as string) ?? '',
      url: (a.url as string) ?? '',
    })),
    attachedVideos: of('video').map((a) => ({
      id: String(a.id ?? ''),
      title: (a.title as string) ?? '',
      description: (a.description as string) ?? '',
      url: (a.url as string) ?? '',
      thumbnailUrl: (a.thumbnail_url as string) ?? undefined,
    })),
    attachedFiles: of('file').map((a) => ({
      id: String(a.id ?? ''),
      title: (a.title as string) ?? '',
      description: (a.description as string) ?? '',
      url: (a.url as string) ?? '',
      fileName: (a.file_name as string) ?? undefined,
      mimeType: (a.mime_type as string) ?? undefined,
      sizeBytes: NUM(a.size_bytes),
    })),
    attachedNotes: of('note').map((a) => ({
      id: String(a.id ?? ''),
      title: (a.title as string) ?? '',
      body: (a.body as string) ?? '',
    })),
  };
}

const QUOTE_SELECT = `
*,
quote_lines(*),
quote_labour_lines(*),
quote_terms(*),
quote_attachments(*)
`;

const INVOICE_SELECT = `
*,
invoice_lines(*),
invoice_labour_lines(*),
invoice_terms(*),
invoice_attachments(*)
`;

/** Resolves `/q/:token`. Returns null when the token is unknown. */
export async function loadSharedQuote(
  token: string,
): Promise<LoadedShare<QuoteRtdb> | null> {
  const { data: share } = await admin()
    .from('document_shares')
    .select('*')
    .eq('token', token)
    .maybeSingle();

  if (!share) return null;

  const index = toIndex(share, String(share.quote_id ?? ''));

  // Checked BEFORE the document reference: withdrawing a quote nulls
  // `quote_id` (the FK is ON DELETE SET NULL) precisely so the tombstone
  // survives. The viewer shows "withdrawn" rather than "not found".
  if (index.deletedAt) return { index, document: {}, business: '' };

  if (!share.quote_id) return null;

  const { data: q } = await admin()
    .from('quotes')
    .select(QUOTE_SELECT)
    .eq('id', share.quote_id)
    .maybeSingle();

  if (!q) return null;

  const owner = await loadOwner(index.uid);
  const customer = (q.customer_snapshot ?? {}) as Record<string, unknown>;

  const document: QuoteRtdb = {
    reference: q.reference ?? undefined,
    title: q.title ?? undefined,
    status: q.status ?? undefined,
    date: MS(q.quote_date),
    expiry: q.expiry ?? undefined,
    total: NUM(q.total),
    createdAt: MS(q.created_at),
    customer: {
      name: customer.name as string | undefined,
      email: customer.email as string | undefined,
      phone: customer.phone as string | undefined,
    },
    lines: mapLines(q.quote_lines ?? []),
    staff: mapLabour(q.quote_labour_lines ?? []),
    terms: mapTerms(q.quote_terms ?? []),
    ...mapAttachments(q.quote_attachments ?? []),
  };

  return {
    index,
    document,
    business: pickBusiness(owner),
    ownerEmail: (owner.business_email ?? owner.email) as string | undefined,
  };
}

/** Resolves `/i/:token`. */
export async function loadSharedInvoice(
  token: string,
): Promise<LoadedShare<InvoiceRtdb> | null> {
  const { data: share } = await admin()
    .from('document_shares')
    .select('*')
    .eq('token', token)
    .maybeSingle();

  if (!share) return null;

  const index = toIndex(share, String(share.invoice_id ?? ''));
  if (index.deletedAt) return { index, document: {}, business: '' };

  if (!share.invoice_id) return null;

  const { data: inv } = await admin()
    .from('invoices')
    .select(INVOICE_SELECT)
    .eq('id', share.invoice_id)
    .maybeSingle();

  if (!inv) return null;

  const owner = await loadOwner(index.uid);
  const customer = (inv.customer_snapshot ?? {}) as Record<string, unknown>;
  const bank = (inv.bank_snapshot ?? {}) as Record<string, unknown>;

  const document: InvoiceRtdb = {
    reference: inv.reference ?? undefined,
    title: inv.title ?? undefined,
    status: inv.status ?? undefined,
    date: MS(inv.invoice_date),
    dueDate: MS(inv.due_date),
    total: NUM(inv.total),
    createdAt: MS(inv.created_at),
    paymentMethod: inv.payment_method ?? undefined,
    // Frozen at send time so a later change to the tradesperson's bank
    // details cannot alter an invoice the customer already received.
    bankSnapshot: {
      bankName: bank.bankName as string | undefined,
      accountNumber: bank.accountNumber as string | undefined,
      sortCode: bank.sortCode as string | undefined,
    },
    customer: {
      name: customer.name as string | undefined,
      email: customer.email as string | undefined,
      phone: customer.phone as string | undefined,
    },
    lines: mapLines(inv.invoice_lines ?? []),
    staff: mapLabour(inv.invoice_labour_lines ?? []),
    terms: mapTerms(inv.invoice_terms ?? []),
    ...mapAttachments(inv.invoice_attachments ?? []),
  } as InvoiceRtdb;

  return {
    index,
    document,
    business: pickBusiness(owner),
    ownerEmail: (owner.business_email ?? owner.email) as string | undefined,
  };
}

function pickBusiness(u: Record<string, unknown>): string {
  const business = (u.business_name ?? u.company_name) as string | undefined;
  if (business && business.trim().length > 0) return business.trim();
  const full = [u.first_name ?? '', u.last_name ?? '']
    .map((s) => String(s).trim())
    .filter((s) => s.length > 0)
    .join(' ');
  return full.length > 0 ? full : 'Your tradesperson';
}

/** Stamps first-view. Returns true when this was the first. */
export async function markViewed(
  token: string,
  kind: 'quote' | 'invoice',
  documentId: string,
): Promise<boolean> {
  const now = new Date().toISOString();

  // Conditional update: only the row whose viewed_at is still null is
  // touched, so two concurrent opens cannot both report "first view" and
  // double-notify the owner.
  const { data } = await admin()
    .from('document_shares')
    .update({ viewed_at: now })
    .eq('token', token)
    .is('viewed_at', null)
    .select('token');

  const isFirst = (data ?? []).length > 0;

  if (isFirst) {
    // Mirror onto the document so the owner's app can show "opened at" in the
    // activity timeline without needing read access to document_shares.
    await admin()
      .from(kind === 'quote' ? 'quotes' : 'invoices')
      .update({ viewed_at: now })
      .eq('id', documentId);
  }

  return isFirst;
}
