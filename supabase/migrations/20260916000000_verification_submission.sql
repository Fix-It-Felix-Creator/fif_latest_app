-- Verification becomes a thing in its own right.
--
-- `profiles.verification_status` has existed since the first migration and has
-- never gated anything. Nothing in the app reads it to make a decision: the
-- auth gate checks onboarding and subscription and lets everybody else
-- through, the two screens built for it are registered in routes.dart and
-- reachable from nowhere, and the one `isVerified` flag in the widget tree is
-- never passed a value. It is a column, a badge nobody renders, and two dead
-- screens.
--
-- It was also briefly folded into the leads application, which made "are you a
-- real tradesperson" a sub-question of "would you like more work". That is the
-- wrong shape: identity is what earns access to anything a member of the
-- public can see, and live leads are only one of those things.
--
-- No new table. profiles already carries document_type, document_urls,
-- selfie_url and verification_status; what was missing was a way for the app
-- to fill them, because verification_status is reserved by
-- profiles_guard_server_columns and a client cannot set it.

-- ============================================================
-- 1. Submitting
-- ============================================================

create or replace function public.submit_verification(
  in_document_type  text,
  in_document_paths text[],
  in_selfie_path    text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  me     uuid := auth.uid();
  result public.profiles;
  current text;
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  if in_document_type not in ('passport', 'driving_licence', 'id_card') then
    raise exception 'Unknown document type' using errcode = '22023';
  end if;

  if coalesce(cardinality(in_document_paths), 0) = 0 then
    raise exception 'At least one document photo is required'
      using errcode = '22023';
  end if;

  if coalesce(trim(in_selfie_path), '') = '' then
    raise exception 'A selfie is required' using errcode = '22023';
  end if;

  select verification_status into current from public.profiles where id = me;

  -- Re-submitting while already verified would take somebody backwards for no
  -- reason. Re-submitting while waiting is harmless and is what somebody does
  -- when they realise the first photo was blurred, so it is allowed.
  if current = 'verified' then
    raise exception 'This account is already verified' using errcode = 'P0001';
  end if;

  -- The column is reserved. Transaction-local, and closed again immediately
  -- below: transaction-local is not statement-local, and left open every
  -- later statement in the same transaction could write a reserved column.
  perform set_config('fif.server_write', 'on', true);

  update public.profiles
  set document_type       = in_document_type,
      document_urls       = in_document_paths,
      selfie_url          = in_selfie_path,
      verification_status = 'waiting',
      -- Cleared, or a resubmission still shows the reason the last one was
      -- turned down and the applicant thinks nothing happened.
      rejection_reason    = null
  where id = me
  returning * into result;

  perform set_config('fif.server_write', 'off', true);

  return result;
end;
$$;

revoke all on function public.submit_verification(text, text[], text)
  from public, anon;
grant execute on function public.submit_verification(text, text[], text)
  to authenticated;

-- ============================================================
-- 2. The gate itself
-- ============================================================
--
-- One place that answers "may this account be seen by a member of the
-- public", so the app, the edge functions and any future policy all ask the
-- same question and cannot drift apart on the answer.

create or replace function public.is_verified(in_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select verification_status = 'verified' from public.profiles where id = in_owner),
    false
  );
$$;

comment on function public.is_verified is
  'Whether this account may do anything a customer can see. The single source of that answer.';

grant execute on function public.is_verified(uuid) to authenticated, service_role;

-- ============================================================
-- 3. Leads now require it
-- ============================================================
--
-- The dependency runs this way round and not the other: an unverified person
-- should never be offered work, but somebody can be perfectly verified and
-- simply not want leads.
--
-- Enforced in the matching function rather than only at application time,
-- because verification can be REVOKED after an application was approved — a
-- lapsed document, a support decision — and a gate that is only checked once
-- is a gate that stops working the moment anything changes.

create or replace function public.candidates_for_job_request(
  in_request_id uuid
)
returns table (
  tradesman_id uuid,
  distance_km  double precision,
  plan_type    text,
  radius_miles integer
)
language sql
stable
security definer
set search_path = public
as $$
  with req as (
    select id, latitude, longitude, service_id
    from public.job_requests
    where id = in_request_id
  ),
  eligible as (
    select
      p.id as profile_id,
      la.base_latitude  as latitude,
      la.base_longitude as longitude,
      la.services       as trades,
      sp.plan_type,
      coalesce(
        (sp.tradesman_limits ->> 'serviceRadiusMiles')::int,
        (sp.business_limits  ->> 'serviceRadiusMiles')::int,
        0
      ) as radius_miles
    from public.profiles p
    join public.lead_applications la
      on la.owner_id = p.id and la.status = 'approved'
    join public.subscriptions s
      on s.owner_id = p.id and s.status in ('active', 'trial')
    join lateral (
      select sp.*
      from public.subscription_plans sp
      where sp.plan_type = s.plan_type
        and sp.account_type in (p.account_type, 'tradesman')
      order by (sp.account_type = p.account_type) desc
      limit 1
    ) sp on true
    where p.account_type <> 'customer'
      -- The new condition. Checked here, every time, not once at approval.
      and p.verification_status = 'verified'
      and la.base_latitude is not null
      and la.base_longitude is not null
  )
  select
    eligible.profile_id,
    dist.km,
    eligible.plan_type,
    eligible.radius_miles
  from req, eligible,
  lateral (
    select 6371 * 2 * asin(sqrt(
      power(sin(radians(eligible.latitude - req.latitude) / 2), 2)
      + cos(radians(req.latitude)) * cos(radians(eligible.latitude))
      * power(sin(radians(eligible.longitude - req.longitude) / 2), 2)
    )) as km
  ) dist
  where req.latitude is not null
    and (req.service_id is null or req.service_id = any (eligible.trades))
    and (eligible.radius_miles = -1
         or dist.km <= eligible.radius_miles * 1.609344)
  order by dist.km;
$$;

revoke all on function public.candidates_for_job_request(uuid)
  from public, anon, authenticated;
grant execute on function public.candidates_for_job_request(uuid) to service_role;

-- ============================================================
-- 4. Approving a leads application no longer verifies anybody
-- ============================================================
--
-- It did for one afternoon, when identity lived inside the leads application.
-- Now that verification is its own decision made on its own evidence, a leads
-- reviewer silently flipping an identity flag would be a second, invisible
-- route to the same conclusion — and the one thing worse than an ungated
-- feature is two gates that disagree.

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
    if not public.is_verified(app.owner_id) then
      raise exception 'This account is not verified yet'
        using errcode = 'P0001';
    end if;

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
