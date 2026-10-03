-- Identity moves into the leads application.
--
-- The application used to tell the reviewer that ID and qualifications were
-- "already on the account from signing up". They are not: every tradesperson
-- account on this project has null document_urls, null selfie_url, null
-- national_insurance_number and zero trade_qualifications rows. The signup
-- chain that collects them exists and is wired, but nothing has ever arrived,
-- so leads approval was being made on the strength of a self-typed scheme
-- number and nothing else.
--
-- Rather than fix a signup flow whose output nobody was reading, identity is
-- collected at the moment it actually matters — when somebody asks to be sent
-- into a stranger's home. That also makes the two admin queues one: there is
-- no longer a separate "verification" decision to make, because approving a
-- leads application IS the identity check.

alter table public.lead_applications
  add column if not exists document_type text,
  -- Storage object paths in the private `user-documents` bucket, not URLs: a
  -- signed URL expires, and a row that stores one becomes a row pointing at
  -- nothing. The panel signs them on demand.
  add column if not exists document_paths text[] not null default '{}',
  add column if not exists selfie_path text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'lead_applications_document_type_check'
  ) then
    alter table public.lead_applications
      add constraint lead_applications_document_type_check
      check (
        document_type is null
        or document_type in ('passport', 'driving_licence', 'id_card')
      );
  end if;
end
$$;

comment on column public.lead_applications.document_paths is
  'Objects in the private user-documents bucket. Paths, not URLs — signed URLs expire.';

-- ============================================================
-- Approving now verifies the person, too
-- ============================================================
--
-- One decision, both records. A reviewer who has just looked at a passport
-- and a selfie has done the identity check; making them go to a second page
-- and repeat it is how the second page ends up never being used — which is
-- exactly what happened.
--
-- Only ever set to 'verified' on approval. A rejected leads application is
-- not the same as a rejected identity: somebody can be perfectly real and
-- still be turned down for having no insurance, and marking them 'rejected'
-- on the profile would lock them out of the rest of the app for a reason that
-- has nothing to do with who they are.

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
    -- Stand the old approval down first, or the partial unique index rejects
    -- the new one.
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

    -- The identity half. Guarded on documents actually being present, so an
    -- application approved before this column existed does not silently mark
    -- somebody verified on no evidence.
    if cardinality(app.document_paths) > 0 and app.selfie_path is not null then
      -- verification_status is reserved by profiles_guard_server_columns.
      -- Transaction-local, so it cannot leak to the next statement on a
      -- pooled connection.
      perform set_config('fif.server_write', 'on', true);
      update public.profiles
      set verification_status = 'verified'
      where id = app.owner_id
        and coalesce(verification_status, '') <> 'verified';
      -- Closed again immediately. Transaction-local is not statement-local:
      -- left on, every later statement in the same transaction could write a
      -- server-reserved column. One statement needs it, so one statement gets
      -- it.
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
  end if;

  return app;
end;
$$;

revoke all on function public.decide_lead_application(uuid, boolean, uuid, text)
  from public, anon, authenticated;
grant execute on function public.decide_lead_application(uuid, boolean, uuid, text)
  to service_role;
