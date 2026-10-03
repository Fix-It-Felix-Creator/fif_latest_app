-- Phase 3 (corrective) — save_job must replace expenses, but never time entries.
--
-- The first cut excluded both, reasoning that each "accumulates through its own
-- flow". That is true of time entries — clockOut() appends one — but wrong for
-- expenses: they are edited inside the job form (new_job_screen.dart:210) and
-- persisted by update(job), exactly like line items on a quote. Leaving them out
-- meant an added expense would simply never save.
--
-- Time entries stay excluded. clockOut() inserts directly into job_time_entries,
-- and a document save must not wipe hours already logged against the job.

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
  delete from public.job_expenses    where job_id = v_id;

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
         e->>'body', e->>'url', e->>'storage_path', e->>'file_name',
         e->>'mime_type',
         coalesce((e->>'size_bytes')::bigint, 0),
         e->>'thumbnail_url', e->>'thumbnail_storage_path'
  from jsonb_array_elements(coalesce(p->'attachments', '[]'::jsonb)) with ordinality as t(e, ord);

  insert into public.job_expenses (
    id, job_id, title, amount, expense_date, description,
    receipt_tool_asset_id, receipt_snapshot
  )
  select coalesce(nullif(e->>'id', '')::uuid, gen_random_uuid()),
         v_id,
         coalesce(e->>'title', ''),
         coalesce((e->>'amount')::numeric, 0),
         coalesce((e->>'expense_date')::date, current_date),
         coalesce(e->>'description', ''),
         nullif(e->>'receipt_tool_asset_id', '')::uuid,
         e->'receipt_snapshot'
  from jsonb_array_elements(coalesce(p->'expenses', '[]'::jsonb)) as e;

  insert into public.job_links (job_id, quote_id, invoice_id)
  select v_id,
         nullif(e->>'quote_id', '')::uuid,
         nullif(e->>'invoice_id', '')::uuid
  from jsonb_array_elements(coalesce(p->'links', '[]'::jsonb)) as e
  on conflict do nothing;

  return v_id;
end
$$;

grant execute on function public.save_job(jsonb) to authenticated;
