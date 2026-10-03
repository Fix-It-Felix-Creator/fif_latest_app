-- Phase 5 — a share tombstone must outlive the document it pointed at.
--
-- document_shares.quote_id / invoice_id were ON DELETE CASCADE, so deleting a
-- quote deleted its share row. That silently defeats the reason deletes go
-- through the backend at all: the public viewer is meant to show
-- "this quote has been withdrawn by the tradesperson" (410) to a customer who
-- already has the link, and with the row gone it can only show a bare
-- "not found" (404).
--
-- SET NULL instead: the share row survives with `deleted_at` set and its
-- document reference cleared. A tombstone does not need the document — the
-- viewer only reads `deleted_at` — and the route (/q/ vs /i/) already says
-- which renderer to use.

alter table public.document_shares
  drop constraint if exists document_shares_quote_id_fkey;

alter table public.document_shares
  add constraint document_shares_quote_id_fkey
  foreign key (quote_id) references public.quotes (id) on delete set null;

alter table public.document_shares
  drop constraint if exists document_shares_invoice_id_fkey;

alter table public.document_shares
  add constraint document_shares_invoice_id_fkey
  foreign key (invoice_id) references public.invoices (id) on delete set null;

comment on column public.document_shares.deleted_at is
  'Tombstone. Set when the owner withdraws the document; the row outlives the document so the public viewer can say "withdrawn" rather than "not found".';
