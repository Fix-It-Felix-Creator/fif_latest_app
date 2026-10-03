-- Job requests: what a homeowner posts, and what tradespeople get offered.
--
-- This is deliberately NOT the existing `jobs` table. That one is a
-- tradesperson's own record of work they are doing — owner_id is the
-- tradesperson, it carries a reference number, a clock, line items, quotes and
-- invoices. A homeowner posting "my boiler is leaking" owns nothing of the
-- sort: it is a lead, it belongs to the customer, and its whole lifecycle is
-- about finding someone. Folding the two together would mean every column of
-- each is null for the other, and every policy would need to ask which kind of
-- row it is looking at before it could answer.
--
-- The two do meet: when a tradesperson accepts a request, that is when a
-- `jobs` row gets created against their account. `job_requests.accepted_job_id`
-- is where that link lives.

-- ============================================================
-- 1. The table
-- ============================================================

create table if not exists public.job_requests (
  id uuid primary key default gen_random_uuid(),

  -- The homeowner. Their auth account, so RLS is a plain auth.uid() check.
  customer_id uuid not null references auth.users (id) on delete cascade,

  -- ---- what ---------------------------------------------------------------
  --
  -- Both the id and the name. The id is the live link to the catalogue; the
  -- name is a snapshot, because a service can be renamed or retired and a job
  -- posted last March must still say what it was posted for. A ledger that
  -- rewrites its own history when a lookup table changes is not a ledger.
  service_id   text references public.services (id) on delete set null,
  service_name text not null,

  -- The path taken through the service's question tree, outermost first:
  -- [{"id": "...", "name": "Heating & Hot Water"}, ...]. Stored as the trail
  -- rather than just the leaf because the leaf alone ("Combi boiler") is not a
  -- job description — the route to it is.
  selections jsonb not null default '[]'::jsonb,

  -- Whatever the customer typed in their own words.
  description text not null default '',

  urgency text not null default 'soon',

  -- ---- where --------------------------------------------------------------
  --
  -- Snapshotted onto the row, not read through to profiles. The job is at a
  -- place; if someone moves house and updates their profile, the boiler they
  -- reported last week did not move with them.
  formatted_address text not null default '',
  address_line1     text,
  address_line2     text,
  city              text,
  county            text,
  postcode          text,

  -- What the matching runs on. Nullable because an address can be typed
  -- without ever being geocoded, and a request with no coordinates is still a
  -- real request — it just cannot be offered by distance until someone
  -- geocodes it. See `job_requests_missing_coords` below.
  latitude  double precision,
  longitude double precision,

  -- ---- lifecycle ----------------------------------------------------------
  status text not null default 'posted',

  -- Set when a tradesperson takes it on. The profile is who; the job is the
  -- record they now keep on their own side.
  accepted_by     uuid references public.profiles (id) on delete set null,
  accepted_job_id uuid references public.jobs (id) on delete set null,
  accepted_at     timestamptz,

  cancelled_at  timestamptz,
  completed_at  timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint job_requests_urgency_check
    check (urgency in ('flexible', 'soon', 'urgent')),

  constraint job_requests_status_check
    check (status in ('posted', 'assigned', 'in_progress', 'completed', 'cancelled')),

  constraint job_requests_selections_is_array
    check (jsonb_typeof(selections) = 'array'),

  -- Coordinates arrive as a pair or not at all. A latitude on its own is not
  -- half a location, it is a bug that would silently place the job on the
  -- prime meridian.
  constraint job_requests_coords_are_paired
    check ((latitude is null) = (longitude is null)),

  constraint job_requests_latitude_range
    check (latitude is null or latitude between -90 and 90),

  constraint job_requests_longitude_range
    check (longitude is null or longitude between -180 and 180)
);

comment on table public.job_requests is
  'A job a homeowner posted. Distinct from public.jobs, which is a tradesperson''s own work record.';

-- ============================================================
-- 2. Indexes
-- ============================================================

-- The customer's own list, newest first — the Jobs tab's only query.
create index if not exists job_requests_customer_idx
  on public.job_requests (customer_id, created_at desc);

-- The badge, and the admin queue. Partial, because "open" is the only status
-- anything counts and it is a small slice of a table that only grows.
create index if not exists job_requests_open_idx
  on public.job_requests (status, created_at desc)
  where status not in ('completed', 'cancelled');

-- Distance matching prefilters on a bounding box before it does any
-- trigonometry, so the useful index is on the pair.
create index if not exists job_requests_coords_idx
  on public.job_requests (latitude, longitude)
  where latitude is not null;

create index if not exists job_requests_accepted_by_idx
  on public.job_requests (accepted_by)
  where accepted_by is not null;

-- Tradespeople are matched by where they are, so the same prefilter needs an
-- index on their side too.
create index if not exists profiles_coords_idx
  on public.profiles (latitude, longitude)
  where latitude is not null and account_type <> 'customer';

-- ============================================================
-- 3. Row level security
-- ============================================================

alter table public.job_requests enable row level security;

-- The customer owns their requests outright.
drop policy if exists "customer reads own job_requests" on public.job_requests;
create policy "customer reads own job_requests"
  on public.job_requests for select
  using (auth.uid() = customer_id);

drop policy if exists "customer creates own job_requests" on public.job_requests;
create policy "customer creates own job_requests"
  on public.job_requests for insert
  with check (auth.uid() = customer_id);

drop policy if exists "customer updates own job_requests" on public.job_requests;
create policy "customer updates own job_requests"
  on public.job_requests for update
  using (auth.uid() = customer_id)
  with check (auth.uid() = customer_id);

drop policy if exists "customer deletes own job_requests" on public.job_requests;
create policy "customer deletes own job_requests"
  on public.job_requests for delete
  using (auth.uid() = customer_id);

-- A tradesperson sees a request once it is theirs, and not before.
--
-- Discovery — "which open jobs are near me" — is deliberately NOT a policy.
-- A policy that let any tradesperson select open requests would hand every
-- signed-in account the address and postcode of every homeowner who has ever
-- posted. Offering a job is a push, done by an edge function under the service
-- role, which sends the tradesperson a notification rather than opening the
-- table to them.
drop policy if exists "accepted tradesman reads job_request" on public.job_requests;
create policy "accepted tradesman reads job_request"
  on public.job_requests for select
  using (auth.uid() = accepted_by);

-- ============================================================
-- 4. Bookkeeping the app should not have to remember
-- ============================================================

create or replace trigger job_requests_touch_updated_at
  before update on public.job_requests
  for each row execute function public.touch_updated_at();

-- Stamps the timestamp that matches the status it was just moved to.
--
-- In a trigger rather than in the app because three clients will eventually
-- write this table — the customer app cancelling, a tradesperson's app
-- completing, and staff doing either from the panel — and a status whose
-- timestamp depends on which one of them made the change is a status you
-- cannot report on.
create or replace function public.job_requests_stamp_status()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'cancelled' and new.cancelled_at is null then
      new.cancelled_at := now();
    elsif new.status = 'completed' and new.completed_at is null then
      new.completed_at := now();
    end if;
  end if;

  if new.accepted_by is distinct from old.accepted_by
     and new.accepted_by is not null
     and new.accepted_at is null then
    new.accepted_at := now();
  end if;

  return new;
end;
$$;

create or replace trigger job_requests_stamp_status
  before update on public.job_requests
  for each row execute function public.job_requests_stamp_status();

-- ============================================================
-- 5. Finding the nearest tradespeople
-- ============================================================
--
-- Haversine in plain SQL rather than PostGIS. Neither project has the
-- extension enabled, and turning it on for one distance query is a large
-- dependency to take on for arithmetic that fits in a dozen lines. If matching
-- ever needs polygons, service areas or routing, that is the point to revisit
-- it — not before.
--
-- The bounding box is what makes it cheap: it is a sargable comparison the
-- index on (latitude, longitude) can use, so the trigonometry only ever runs
-- on the handful of rows already known to be roughly close. Without it this
-- would compute a great-circle distance for every tradesperson in the country.

create or replace function public.tradesmen_near(
  in_latitude   double precision,
  in_longitude  double precision,
  in_radius_km  double precision default 25,
  in_service_id text default null,
  in_limit      integer default 50
)
returns table (
  profile_id  uuid,
  distance_km double precision
)
language sql
stable
security definer
set search_path = public
as $$
  with box as (
    select
      in_radius_km / 111.045 as d_lat,
      -- A degree of longitude narrows towards the poles. Guard the cosine
      -- against a latitude of exactly ±90, where it is zero and the division
      -- would fail.
      in_radius_km / greatest(
        111.045 * cos(radians(in_latitude)),
        0.000001
      ) as d_lng
  )
  select
    p.id,
    -- Great-circle distance, earth radius 6371km.
    6371 * 2 * asin(
      sqrt(
        power(sin(radians(p.latitude - in_latitude) / 2), 2)
        + cos(radians(in_latitude)) * cos(radians(p.latitude))
        * power(sin(radians(p.longitude - in_longitude) / 2), 2)
      )
    ) as distance_km
  from public.profiles p, box
  where p.account_type <> 'customer'
    and p.latitude is not null
    and p.longitude is not null
    -- The prefilter. Cheap, index-backed, and generous: it selects a square
    -- around the circle, so the distance test below still has to reject the
    -- corners.
    and p.latitude between in_latitude - box.d_lat and in_latitude + box.d_lat
    and p.longitude between in_longitude - box.d_lng and in_longitude + box.d_lng
    -- profiles.trade holds the same ids as services.id ('plumber',
    -- 'electrician'). Passing null matches on distance alone, which is the
    -- only thing that works for the eleven services no tradesperson can
    -- register for — car_service, mot, tv_mounting, help_moving and the rest
    -- exist in the customer catalogue but not in the Pro app's trade list.
    and (in_service_id is null or in_service_id = any (p.trade))
    -- The box selects a square around the circle, so its corners are further
    -- than the radius asked for. This is the test that actually answers the
    -- question; the box above only made it cheap.
    and 6371 * 2 * asin(
      sqrt(
        power(sin(radians(p.latitude - in_latitude) / 2), 2)
        + cos(radians(in_latitude)) * cos(radians(p.latitude))
        * power(sin(radians(p.longitude - in_longitude) / 2), 2)
      )
    ) <= in_radius_km
  order by distance_km
  limit greatest(in_limit, 1);
$$;

comment on function public.tradesmen_near is
  'Tradespeople within in_radius_km of a point, nearest first. Called by the offer edge function under the service role.';

-- Not granted to authenticated. It reads across every profile, so letting a
-- signed-in user call it directly would be a way to enumerate where
-- tradespeople live.
revoke all on function public.tradesmen_near(
  double precision, double precision, double precision, text, integer
) from public, anon, authenticated;

grant execute on function public.tradesmen_near(
  double precision, double precision, double precision, text, integer
) to service_role;

-- ============================================================
-- 6. What the panel needs to watch
-- ============================================================
--
-- A posted request with no coordinates cannot be offered to anyone by
-- distance — it will sit there looking posted and reach nobody. That is a
-- support question, so it needs to be answerable from the panel.

create or replace view public.job_requests_missing_coords as
  select id, customer_id, service_name, formatted_address, postcode, created_at
  from public.job_requests
  where latitude is null
    and status not in ('completed', 'cancelled');

comment on view public.job_requests_missing_coords is
  'Open requests that no distance search can ever return. Should be empty.';
