-- Phase 3 — atomic save for the three multi-table documents.
--
-- In RTDB a quote was ONE node: parent fields plus nested `lines`, `staff`,
-- `terms` and `attached*` arrays, written with a single `.set()`. The
-- normalised schema splits each into a parent row plus four child tables, so
-- the naive port is five separate statements — and a failure partway through
-- leaves a quote with some of its line items, which silently corrupts totals.
--
-- These functions take the whole document as jsonb and write it in one
-- transaction. Children are replaced wholesale (delete + insert) because that
-- is exactly what `.set()` meant: the payload is the complete new state.
--
-- SECURITY INVOKER (the default) is deliberate — RLS still applies, so a
-- caller can only write documents they own. The function adds atomicity, not
-- privilege.

-- ============================================================
-- save_quote
-- ============================================================
create or replace function public.save_quote(p jsonb)
returns uuid
language plpgsql
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid := coalesce((p->>'id')::uuid, gen_random_uuid());
begin
  if v_uid is null then
    raise exception 'save_quote: not authenticated';
  end if;

  insert into public.quotes (
    id, owner_id, reference, title, status, quote_date, expiry, total,
    customer_id, customer_snapshot, share_token, sent_at, viewed_at, responded_at
  ) values (
    v_id, v_uid,
    coalesce(p->>'reference', ''),
    coalesce(p->>'title', ''),
    coalesce(p->>'status', 'draft'),
    coalesce((p->>'quote_date')::date, current_date),
    coalesce(p->>'expiry', 'days14'),
    coalesce((p->>'total')::numeric, 0),
    nullif(p->>'customer_id', '')::uuid,
    p->'customer_snapshot',
    nullif(p->>'share_token', ''),
    (p->>'sent_at')::timestamptz,
    (p->>'viewed_at')::timestamptz,
    (p->>'responded_at')::timestamptz
  )
  on conflict (id) do update set
    reference         = excluded.reference,
    title             = excluded.title,
    status            = excluded.status,
    quote_date        = excluded.quote_date,
    expiry            = excluded.expiry,
    total             = excluded.total,
    customer_id       = excluded.customer_id,
    customer_snapshot = excluded.customer_snapshot,
    -- Never let a save blank a server-minted share token: the public viewer
    -- and the delete tombstone both depend on it surviving a round-trip
    -- through the edit form.
    share_token       = coalesce(excluded.share_token, public.quotes.share_token),
    sent_at           = excluded.sent_at,
    viewed_at         = excluded.viewed_at,
    responded_at      = excluded.responded_at,
    updated_at        = now();

  delete from public.quote_lines        where quote_id = v_id;
  delete from public.quote_labour_lines where quote_id = v_id;
  delete from public.quote_terms        where quote_id = v_id;
  delete from public.quote_attachments  where quote_id = v_id;

  insert into public.quote_lines (
    quote_id, sort_order, kind, pricing_item_id, item_name, item_code,
    rate, unit_markup, discount, quantity, line_total
  )
  select v_id, (ord - 1)::int,
         coalesce(e->>'kind', 'material'),
         nullif(e->>'pricing_item_id', '')::uuid,
         coalesce(e->>'item_name', ''),
         nullif(e->>'item_code', ''),
         coalesce((e->>'rate')::numeric, 0),
         coalesce((e->>'unit_markup')::numeric, 0),
         coalesce((e->>'discount')::numeric, 0),
         coalesce((e->>'quantity')::int, 1),
         coalesce((e->>'line_total')::numeric, 0)
  from jsonb_array_elements(coalesce(p->'lines', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.quote_labour_lines (
    quote_id, sort_order, staff_id, staff_name, pay_type, rate_type,
    rate, quantity, line_total
  )
  select v_id, (ord - 1)::int,
         nullif(e->>'staff_id', '')::uuid,
         coalesce(e->>'staff_name', ''),
         coalesce(e->>'pay_type', 'day'),
         coalesce(e->>'rate_type', 'standard'),
         coalesce((e->>'rate')::numeric, 0),
         coalesce((e->>'quantity')::numeric, 0),
         coalesce((e->>'line_total')::numeric, 0)
  from jsonb_array_elements(coalesce(p->'staff', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.quote_terms (quote_id, sort_order, term_id, name, details)
  select v_id, (ord - 1)::int,
         nullif(e->>'term_id', '')::uuid,
         coalesce(e->>'name', ''),
         coalesce(e->>'details', '')
  from jsonb_array_elements(coalesce(p->'terms', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.quote_attachments (
    quote_id, sort_order, kind, tool_asset_id, title, description, body, url,
    storage_path, file_name, mime_type, size_bytes, thumbnail_url,
    thumbnail_storage_path
  )
  select v_id, (ord - 1)::int,
         coalesce(e->>'kind', 'file'),
         nullif(e->>'tool_asset_id', '')::uuid,
         coalesce(e->>'title', ''),
         coalesce(e->>'description', ''),
         e->>'body',
         e->>'url',
         e->>'storage_path',
         e->>'file_name',
         e->>'mime_type',
         coalesce((e->>'size_bytes')::bigint, 0),
         e->>'thumbnail_url',
         e->>'thumbnail_storage_path'
  from jsonb_array_elements(coalesce(p->'attachments', '[]'::jsonb)) with ordinality as t(e, ord);

  return v_id;
end
$$;

-- ============================================================
-- save_invoice
-- ============================================================
create or replace function public.save_invoice(p jsonb)
returns uuid
language plpgsql
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid := coalesce((p->>'id')::uuid, gen_random_uuid());
begin
  if v_uid is null then
    raise exception 'save_invoice: not authenticated';
  end if;

  insert into public.invoices (
    id, owner_id, reference, title, status, invoice_date, due_date, total,
    customer_id, customer_snapshot, payment_method, bank_snapshot,
    share_token, sent_at, viewed_at, paid_at
  ) values (
    v_id, v_uid,
    coalesce(p->>'reference', ''),
    coalesce(p->>'title', ''),
    coalesce(p->>'status', 'draft'),
    coalesce((p->>'invoice_date')::date, current_date),
    coalesce((p->>'due_date')::date, current_date),
    coalesce((p->>'total')::numeric, 0),
    nullif(p->>'customer_id', '')::uuid,
    p->'customer_snapshot',
    coalesce(p->>'payment_method', 'cash'),
    p->'bank_snapshot',
    nullif(p->>'share_token', ''),
    (p->>'sent_at')::timestamptz,
    (p->>'viewed_at')::timestamptz,
    (p->>'paid_at')::timestamptz
  )
  on conflict (id) do update set
    reference         = excluded.reference,
    title             = excluded.title,
    status            = excluded.status,
    invoice_date      = excluded.invoice_date,
    due_date          = excluded.due_date,
    total             = excluded.total,
    customer_id       = excluded.customer_id,
    customer_snapshot = excluded.customer_snapshot,
    payment_method    = excluded.payment_method,
    bank_snapshot     = excluded.bank_snapshot,
    share_token       = coalesce(excluded.share_token, public.invoices.share_token),
    sent_at           = excluded.sent_at,
    viewed_at         = excluded.viewed_at,
    paid_at           = excluded.paid_at,
    updated_at        = now();

  delete from public.invoice_lines        where invoice_id = v_id;
  delete from public.invoice_labour_lines where invoice_id = v_id;
  delete from public.invoice_terms        where invoice_id = v_id;
  delete from public.invoice_attachments  where invoice_id = v_id;

  insert into public.invoice_lines (
    invoice_id, sort_order, kind, pricing_item_id, item_name, item_code,
    rate, unit_markup, discount, quantity, line_total
  )
  select v_id, (ord - 1)::int,
         coalesce(e->>'kind', 'material'),
         nullif(e->>'pricing_item_id', '')::uuid,
         coalesce(e->>'item_name', ''),
         nullif(e->>'item_code', ''),
         coalesce((e->>'rate')::numeric, 0),
         coalesce((e->>'unit_markup')::numeric, 0),
         coalesce((e->>'discount')::numeric, 0),
         coalesce((e->>'quantity')::int, 1),
         coalesce((e->>'line_total')::numeric, 0)
  from jsonb_array_elements(coalesce(p->'lines', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.invoice_labour_lines (
    invoice_id, sort_order, staff_id, staff_name, pay_type, rate_type,
    rate, quantity, line_total
  )
  select v_id, (ord - 1)::int,
         nullif(e->>'staff_id', '')::uuid,
         coalesce(e->>'staff_name', ''),
         coalesce(e->>'pay_type', 'day'),
         coalesce(e->>'rate_type', 'standard'),
         coalesce((e->>'rate')::numeric, 0),
         coalesce((e->>'quantity')::numeric, 0),
         coalesce((e->>'line_total')::numeric, 0)
  from jsonb_array_elements(coalesce(p->'staff', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.invoice_terms (invoice_id, sort_order, term_id, name, details)
  select v_id, (ord - 1)::int,
         nullif(e->>'term_id', '')::uuid,
         coalesce(e->>'name', ''),
         coalesce(e->>'details', '')
  from jsonb_array_elements(coalesce(p->'terms', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.invoice_attachments (
    invoice_id, sort_order, kind, tool_asset_id, title, description, body, url,
    storage_path, file_name, mime_type, size_bytes, thumbnail_url,
    thumbnail_storage_path
  )
  select v_id, (ord - 1)::int,
         coalesce(e->>'kind', 'file'),
         nullif(e->>'tool_asset_id', '')::uuid,
         coalesce(e->>'title', ''),
         coalesce(e->>'description', ''),
         e->>'body',
         e->>'url',
         e->>'storage_path',
         e->>'file_name',
         e->>'mime_type',
         coalesce((e->>'size_bytes')::bigint, 0),
         e->>'thumbnail_url',
         e->>'thumbnail_storage_path'
  from jsonb_array_elements(coalesce(p->'attachments', '[]'::jsonb)) with ordinality as t(e, ord);

  return v_id;
end
$$;

-- ============================================================
-- save_job
-- ============================================================
create or replace function public.save_job(p jsonb)
returns uuid
language plpgsql
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid := coalesce((p->>'id')::uuid, gen_random_uuid());
begin
  if v_uid is null then
    raise exception 'save_job: not authenticated';
  end if;

  insert into public.jobs (
    id, owner_id, reference, title, description, status, start_date,
    customer_id, customer_snapshot, clock_in_at
  ) values (
    v_id, v_uid,
    coalesce(p->>'reference', ''),
    coalesce(p->>'title', ''),
    coalesce(p->>'description', ''),
    coalesce(p->>'status', 'draft'),
    coalesce((p->>'start_date')::date, current_date),
    nullif(p->>'customer_id', '')::uuid,
    p->'customer_snapshot',
    (p->>'clock_in_at')::timestamptz
  )
  on conflict (id) do update set
    reference         = excluded.reference,
    title             = excluded.title,
    description       = excluded.description,
    status            = excluded.status,
    start_date        = excluded.start_date,
    customer_id       = excluded.customer_id,
    customer_snapshot = excluded.customer_snapshot,
    clock_in_at       = excluded.clock_in_at,
    updated_at        = now();

  delete from public.job_attachments where job_id = v_id;
  delete from public.job_links       where job_id = v_id;

  -- Time entries and expenses are NOT replaced here. They accumulate through
  -- their own flows (clock-out, expense capture) and a document save must not
  -- wipe hours already logged against the job.

  insert into public.job_attachments (
    job_id, sort_order, kind, tool_asset_id, title, description, body, url,
    storage_path, file_name, mime_type, size_bytes, thumbnail_url,
    thumbnail_storage_path
  )
  select v_id, (ord - 1)::int,
         coalesce(e->>'kind', 'file'),
         nullif(e->>'tool_asset_id', '')::uuid,
         coalesce(e->>'title', ''),
         coalesce(e->>'description', ''),
         e->>'body',
         e->>'url',
         e->>'storage_path',
         e->>'file_name',
         e->>'mime_type',
         coalesce((e->>'size_bytes')::bigint, 0),
         e->>'thumbnail_url',
         e->>'thumbnail_storage_path'
  from jsonb_array_elements(coalesce(p->'attachments', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.job_links (job_id, quote_id, invoice_id)
  select v_id,
         nullif(e->>'quote_id', '')::uuid,
         nullif(e->>'invoice_id', '')::uuid
  from jsonb_array_elements(coalesce(p->'links', '[]'::jsonb)) as e
  on conflict do nothing;

  return v_id;
end
$$;

grant execute on function public.save_quote(jsonb)   to authenticated;
grant execute on function public.save_invoice(jsonb) to authenticated;
grant execute on function public.save_job(jsonb)     to authenticated;
