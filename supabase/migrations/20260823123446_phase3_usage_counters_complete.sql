-- Phase 3 — the last three usage counters.
--
-- Phase 1 added 15 counters taken from resetUsage(). The authoritative list is
-- actually _getCountFieldName(), which maps all 20 UsageCountType values — and
-- three of them never appear in resetUsage(), so they were missed:
--   cancellationsThisMonth, tradesmanCancellationsThisMonth, scheduledVisitsCount
--
-- Without these, bump_usage() raises 'unknown field' the moment the app records
-- a cancellation or a scheduled visit.

alter table public.usage_counters
  add column if not exists cancellations_this_month           integer not null default 0,
  add column if not exists tradesman_cancellations_this_month integer not null default 0,
  add column if not exists scheduled_visits_count             integer not null default 0;

create or replace function public.bump_usage("p_field" text, "p_amount" integer default 1)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'bump_usage: not authenticated';
  end if;
  if p_field !~ '^[a-z_]+$' then
    raise exception 'bump_usage: invalid field %', p_field;
  end if;
  if p_field not in (
    'voice_seconds_used', 'suggestions_used', 'leads_viewed',
    'address_count', 'job_count', 'invoice_count', 'quotation_count',
    'template_count', 'service_count', 'customer_count',
    'job_applications_this_month', 'completed_jobs_count',
    'photo_upload_count', 'video_upload_count', 'staff_count',
    'freelance_hires_this_month', 'branch_count', 'projects_this_month',
    'cancellations_this_month', 'tradesman_cancellations_this_month',
    'scheduled_visits_count'
  ) then
    raise exception 'bump_usage: unknown field %', p_field;
  end if;

  insert into public.usage_counters (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  -- Counters reset via reset_usage() on subscription change, never on a
  -- calendar boundary — this mirrors the RTDB behaviour being replaced.
  -- greatest(...,0) keeps a decrement from driving a count negative, matching
  -- decrementUsageCount()'s floor.
  execute format(
    'update public.usage_counters set %I = greatest(%I + $1, 0) where owner_id = $2',
    p_field, p_field
  ) using p_amount, v_uid;
end
$$;

create or replace function public.reset_usage()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'reset_usage: not authenticated';
  end if;

  insert into public.usage_counters (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  -- Mirrors usage_repository.resetUsage() exactly. The three counters added
  -- above are intentionally NOT reset here: the app's resetUsage() does not
  -- clear them either, and changing that would silently hand users back
  -- allowance they had already spent.
  update public.usage_counters
     set address_count               = 0,
         job_count                   = 0,
         invoice_count               = 0,
         quotation_count             = 0,
         template_count              = 0,
         service_count               = 0,
         customer_count              = 0,
         job_applications_this_month = 0,
         completed_jobs_count        = 0,
         photo_upload_count          = 0,
         video_upload_count          = 0,
         staff_count                 = 0,
         freelance_hires_this_month  = 0,
         branch_count                = 0,
         projects_this_month         = 0,
         voice_seconds_used          = 0,
         suggestions_used            = 0,
         leads_viewed                = 0,
         period_start                = date_trunc('month', now())::date,
         reset_at                    = now()
   where owner_id = v_uid;
end
$$;

grant execute on function public.bump_usage(text, integer) to authenticated;
grant execute on function public.reset_usage() to authenticated;
