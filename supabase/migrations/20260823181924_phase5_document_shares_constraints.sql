-- Phase 5 — two document_shares constraints that contradict the code.
--
-- 1. document_shares_exactly_one required exactly one of quote_id/invoice_id
--    to be set. Withdrawing a document nulls that column (the FK is now
--    ON DELETE SET NULL so the tombstone survives), which leaves both null
--    and trips the check — the delete fails with a 500 after the tombstone
--    has already been written, leaving the share withdrawn but the document
--    still present.
--
--    Relaxed to: exactly one BEFORE the document is withdrawn, unconstrained
--    afterwards. A tombstone genuinely has no document to point at.
--
-- 2. document_shares_responded_action_check allowed only 'accepted'/'rejected'.
--    The code — the original Cloud Function, its ShareIndex type, and the
--    viewer that renders the locked state — all use 'accept'/'reject'.
--    Every customer accept/reject would have failed on this constraint.
--    Aligned to the code, which is the contract the public page is built on.

alter table public.document_shares
  drop constraint if exists document_shares_exactly_one;

alter table public.document_shares
  add constraint document_shares_exactly_one
  check (
    deleted_at is not null
    or ((quote_id is not null)::integer + (invoice_id is not null)::integer) = 1
  );

alter table public.document_shares
  drop constraint if exists document_shares_responded_action_check;

alter table public.document_shares
  add constraint document_shares_responded_action_check
  check (responded_action is null or responded_action in ('accept', 'reject'));
