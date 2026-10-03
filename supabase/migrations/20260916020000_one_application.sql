-- One application, one decision.
--
-- Verification and leads approval were split into two flows and two queues on
-- the reasoning that identity gates more than leads do. The gating part was
-- right and stays. The splitting part was wrong: a tradesperson fills in ONE
-- application — who they are, how they work, what they do, where, and who
-- insures them — and approving it is what makes them a verified tradesperson.
--
-- Splitting it meant somebody opening the flow was shown a camera and nothing
-- else, with the trade, coverage and insurance screens stranded behind a gate
-- they could not yet pass.
--
-- So approving the application verifies the person again — as it briefly did —
-- but this time verification keeps its broad meaning: it gates everything a
-- customer can see, not just leads.

create or replace function public.decide_lead_application(
  in_application_id uuid,
  in_approve        boolean,
  in_reviewer_id    uuid,
  in_reason         text default null
)
returns public.lead_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  app public.lead_applications;
begin
  select * into app from public.lead_applications where id = in_application_id;
  if app.id is null then
    raise exception 'No such application' using errcode = 'P0002';
  end if;

  if app.status <> 'submitted' then
    raise exception 'That application has already been decided (%)' , app.status
      using errcode = 'P0001';
  end if;

  if in_approve then
    update public.lead_applications
    set status = 'superseded'
    where owner_id = app.owner_id
      and status = 'approved'
      and id <> app.id;

    update public.lead_applications
    set status = 'approved',
        reviewed_at = now(),
        reviewed_by = in_reviewer_id,
        rejection_reason = null
    where id = app.id
    returning * into app;

    -- The identity half of the same decision.
    --
    -- Guarded on documents actually being present: an application sent before
    -- identity was collected must not mark somebody verified on no evidence.
    -- verification_status is reserved by profiles_guard_server_columns, hence
    -- the flag — closed again immediately, because transaction-local is not
    -- statement-local and every later statement would otherwise inherit it.
    if cardinality(app.document_paths) > 0 and app.selfie_path is not null then
      perform set_config('fif.server_write', 'on', true);
      update public.profiles
      set verification_status = 'verified',
          rejection_reason = null
      where id = app.owner_id;
      perform set_config('fif.server_write', 'off', true);
    end if;
  else
    if coalesce(trim(in_reason), '') = '' then
      raise exception 'A rejection needs a reason' using errcode = '22023';
    end if;

    update public.lead_applications
    set status = 'rejected',
        reviewed_at = now(),
        reviewed_by = in_reviewer_id,
        rejection_reason = in_reason
    where id = app.id
    returning * into app;

    -- A rejected application is a rejected identity too, now that they are
    -- the same decision — but only when it was identity we were looking at.
    -- Somebody turned down for having no insurance is not somebody whose
    -- passport was wrong, and marking them 'rejected' would say so.
    if cardinality(app.document_paths) > 0 then
      perform set_config('fif.server_write', 'on', true);
      update public.profiles
      set verification_status = 'rejected',
          rejection_reason = in_reason
      where id = app.owner_id
        and coalesce(verification_status, '') <> 'verified';
      perform set_config('fif.server_write', 'off', true);
    end if;
  end if;

  return app;
end;
$$;

revoke all on function public.decide_lead_application(uuid, boolean, uuid, text)
  from public, anon, authenticated;
grant execute on function public.decide_lead_application(uuid, boolean, uuid, text)
  to service_role;
