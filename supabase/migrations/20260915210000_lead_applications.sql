-- Lead applications: being allowed to receive work, as opposed to paying for it.
--
-- Two separate gates, deliberately. A plan decides how far somebody is seen;
-- an approved application decides whether they are seen at all. Conflating
-- them would mean either paying customers who were never checked getting live
-- leads, or a vetted tradesperson losing their approval by downgrading. Both
-- are wrong, and they are wrong in opposite directions.
--
-- Everything the application collects that is NOT already on the profile lives
-- here. ID, selfie, National Insurance, qualifications and address were taken
-- at signup and are not asked for again.

-- ============================================================
-- 1. The table
-- ============================================================

create table if not exists public.lead_applications (
  id uuid primary key default gen_random_uuid(),

  owner_id uuid not null references auth.users (id) on delete cascade,

  -- 'solo' | 'business'. Not profiles.account_type: somebody can hold a
  -- business account and apply as a sole trader, and the thing being reviewed
  -- is how they intend to take work.
  applicant_type text not null,

  -- Service ids, the same vocabulary as profiles.trade and services.id.
  --
  -- THIS, not profiles.trade, is what matching uses once approved. trade is
  -- self-declared at signup and never checked; this array is what somebody
  -- actually reviewed.
  services text[] not null default '{}',

  -- { "<service_id>": "<scheme number>" }. The reviewer checks these against
  -- the scheme's own register.
  registrations jsonb not null default '{}'::jsonb,

  -- Whether they carry waste away, and their Environment Agency number if so.
  -- Its own columns rather than another entry in `registrations` because it is
  -- not per-trade — it is one fact about the business.
  moves_waste          boolean,
  waste_carrier_number text,

  -- ---- coverage -----------------------------------------------------------
  --
  -- Where they set off FROM. Separate from profiles' address: a tradesperson
  -- may live in one town and work out of a yard in another, and the yard is
  -- what distance should be measured from.
  base_address   text not null default '',
  base_latitude  double precision,
  base_longitude double precision,

  -- ISO weekday numbers, 1 = Monday.
  working_days integer[] not null default '{1,2,3,4,5}',
  takes_emergencies boolean not null default false,

  -- ---- insurance ----------------------------------------------------------
  has_own_insurance boolean not null default true,
  insurer           text,
  policy_number     text,
  cover_amount      text,
  -- Kept as its own column rather than buried in jsonb because it is the one
  -- field anything will ever query: "whose cover lapses this month".
  policy_expires_at date,

  -- ---- public profile -----------------------------------------------------
  headline         text not null default '',
  about            text not null default '',
  years_experience integer,

  -- ---- lifecycle ----------------------------------------------------------
  --
  -- submitted → approved | rejected, or withdrawn by the applicant at any
  -- point. `superseded` is set when a newer application is approved in its
  -- place, so history survives instead of being overwritten.
  status text not null default 'submitted',

  submitted_at timestamptz not null default now(),
  reviewed_at  timestamptz,
  -- Not a FK. A reviewer's account may be deleted; who decided this is still
  -- part of the record.
  reviewed_by  uuid,
  rejection_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint lead_applications_type_check
    check (applicant_type in ('solo', 'business')),

  constraint lead_applications_status_check
    check (status in ('submitted', 'approved', 'rejected', 'withdrawn', 'superseded')),

  -- A rejection has to say why. An applicant told only "no" cannot fix
  -- anything, and will ask support what to do — which is the same work, done
  -- twice, more slowly.
  constraint lead_applications_rejection_has_reason
    check (status <> 'rejected' or coalesce(trim(rejection_reason), '') <> ''),

  constraint lead_applications_services_not_empty
    check (cardinality(services) > 0),

  constraint lead_applications_coords_are_paired
    check ((base_latitude is null) = (base_longitude is null))
);

comment on table public.lead_applications is
  'A tradesperson asking to receive live leads. Approval is a separate gate from the subscription plan.';

-- At most one application in play per person.
--
-- Without this, tapping Send twice — or a retry on a flaky connection —
-- produces two identical applications and two reviewers doing the same work
-- and reaching different answers.
create unique index if not exists lead_applications_one_open_idx
  on public.lead_applications (owner_id)
  where status = 'submitted';

-- ...and at most one live approval. A newer approval supersedes the old one
-- rather than sitting alongside it, so "which application is in force" is
-- never a judgement call.
create unique index if not exists lead_applications_one_approved_idx
  on public.lead_applications (owner_id)
  where status = 'approved';

create index if not exists lead_applications_queue_idx
  on public.lead_applications (status, submitted_at);

create index if not exists lead_applications_owner_idx
  on public.lead_applications (owner_id, submitted_at desc);

-- Whose cover is about to lapse. An approval whose insurance expired is worse
-- than no approval, because we vouched for them.
create index if not exists lead_applications_expiry_idx
  on public.lead_applications (policy_expires_at)
  where status = 'approved' and policy_expires_at is not null;

create or replace trigger lead_applications_touch_updated_at
  before update on public.lead_applications
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 2. Row level security
-- ============================================================

alter table public.lead_applications enable row level security;

drop policy if exists "owner reads own lead_applications" on public.lead_applications;
create policy "owner reads own lead_applications"
  on public.lead_applications for select
  using (auth.uid() = owner_id);

drop policy if exists "owner creates own lead_applications" on public.lead_applications;
create policy "owner creates own lead_applications"
  on public.lead_applications for insert
  with check (
    auth.uid() = owner_id
    -- An applicant may only ever create a pending application. Inserting one
    -- that is already 'approved' would be self-approval, and a hidden button
    -- is not a check.
    and status = 'submitted'
  );

-- Withdrawing is the only change an applicant may make, and only from a live
-- state. Everything else — approving, rejecting, the reason — is staff work
-- done through the panel under the service role.
drop policy if exists "owner withdraws own lead_applications" on public.lead_applications;
create policy "owner withdraws own lead_applications"
  on public.lead_applications for update
  using (auth.uid() = owner_id and status in ('submitted', 'approved'))
  with check (auth.uid() = owner_id and status = 'withdrawn');

-- ============================================================
-- 3. Telling them what happened
-- ============================================================
--
-- In a trigger rather than in whichever client made the change. Three
-- different things will move this column — the panel approving, the panel
-- rejecting, the app withdrawing — and a notification that depends on the
-- caller remembering to send it is a notification that goes missing the first
-- time somebody adds a fourth caller.

create or replace function public.lead_applications_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  -- Withdrawing is the applicant's own doing. Telling somebody what they just
  -- did themselves is noise.
  if new.status = 'withdrawn' then
    return new;
  end if;

  if new.status = 'approved' then
    insert into public.notifications (owner_id, type, title, body, payload)
    values (
      new.owner_id,
      'lead_application',
      'You are approved for live leads',
      'Matching jobs near you will start arriving in your Leads inbox.',
      jsonb_build_object('applicationId', new.id, 'status', new.status)
    );
  elsif new.status = 'rejected' then
    insert into public.notifications (owner_id, type, title, body, payload)
    values (
      new.owner_id,
      'lead_application',
      'Your leads application needs attention',
      coalesce(new.rejection_reason, 'Please open the app for details.'),
      jsonb_build_object(
        'applicationId', new.id,
        'status', new.status,
        'reason', new.rejection_reason
      )
    );
  end if;

  return new;
end;
$$;

create or replace trigger lead_applications_notify
  after update on public.lead_applications
  for each row execute function public.lead_applications_notify();

-- ============================================================
-- 4. Approving, and what it displaces
-- ============================================================
--
-- One function rather than the panel writing the row directly, because
-- approving is two writes that must not come apart: this application becomes
-- live, and any previously approved one stops being. Two statements from the
-- panel would leave a window where a tradesperson has two live approvals, and
-- the unique index above would reject the second write anyway — turning a race
-- into a 500 rather than into correct behaviour.

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

-- ============================================================
-- 5. Matching now requires an approval
-- ============================================================
--
-- The whole point of the application. Replaces the version from
-- 20260915190000, which asked only "does their plan reach this job".
--
-- Three things now have to be true, and they come from three different places:
--   the plan says how far        (subscription_plans.serviceRadiusMiles)
--   the approval says they may   (lead_applications.status = 'approved')
--   the approval says what from  (base_latitude/longitude, services)
--
-- Coordinates come from the APPLICATION, not the profile. Somebody may live in
-- one town and work out of a yard in another, and the yard is the one they
-- were approved on.

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
    -- Prefer the plan row for this account's own type, falling back to the
    -- tradesman row. There are no rows with account_type = 'business', so a
    -- plain equality join would silently exclude every business account.
    join lateral (
      select sp.*
      from public.subscription_plans sp
      where sp.plan_type = s.plan_type
        and sp.account_type in (p.account_type, 'tradesman')
      order by (sp.account_type = p.account_type) desc
      limit 1
    ) sp on true
    where p.account_type <> 'customer'
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
    -- -1 is unlimited; 0 excludes, which is how Standard is kept out by
    -- arithmetic rather than by a special case somebody has to remember.
    and (eligible.radius_miles = -1
         or dist.km <= eligible.radius_miles * 1.609344)
  order by dist.km;
$$;

comment on function public.candidates_for_job_request is
  'Approved tradespeople whose plan radius covers this job, measured from the base address on their application. Service role only.';

revoke all on function public.candidates_for_job_request(uuid)
  from public, anon, authenticated;
grant execute on function public.candidates_for_job_request(uuid) to service_role;
