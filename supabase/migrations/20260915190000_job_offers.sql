-- Job offers: the lead itself.
--
-- `job_requests` records what a customer asked for. Nothing yet records that a
-- particular job was put in front of a particular tradesperson — and without
-- that row there is no inbox to draw, nothing to count against
-- maxVisibleLeadsPerMonth, and no accept to turn into work. This is that row.
--
-- It is also where two lines of the campaign's comparison table turn out to be
-- one feature:
--
--   "Visibility — Standard / up to 100 miles / UK wide"
--   "CRM & live leads — — / ✓ / ✓ Unlimited"
--
-- Visibility IS the radius passed to tradesmen_near(). A lead IS a row that
-- call produced. Built as two features they would be the same code twice.

-- ============================================================
-- 1. The table
-- ============================================================

create table if not exists public.job_offers (
  id uuid primary key default gen_random_uuid(),

  job_request_id uuid not null
    references public.job_requests (id) on delete cascade,

  -- Who it was offered to. profiles rather than auth.users because everything
  -- the fan-out matches on — trade, coordinates, account_type — lives there.
  tradesman_id uuid not null
    references public.profiles (id) on delete cascade,

  -- How far they were from the job WHEN IT WAS OFFERED. Snapshotted, not
  -- recomputed on read: a tradesperson who later moves, or widens their radius
  -- on a new plan, must not retroactively change the distance shown on a lead
  -- they already answered.
  distance_km double precision,

  -- The plan that earned them this lead, and the radius it allowed. Kept for
  -- the same reason: "why did I get this one and not that one" is a support
  -- question, and it cannot be answered from a plan that has since changed.
  plan_type      text,
  radius_miles   integer,

  status text not null default 'offered',

  offered_at   timestamptz not null default now(),
  -- Set the first time the tradesperson actually opens it. This is the moment
  -- that costs them a lead against their monthly allowance, which is why it is
  -- a timestamp and not a boolean — burning the allowance twice for one lead
  -- because a list re-rendered would be a billing bug.
  viewed_at    timestamptz,
  responded_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint job_offers_status_check
    check (status in ('offered', 'viewed', 'declined', 'accepted', 'withdrawn')),

  -- One offer per job per tradesperson. The fan-out is allowed to run again —
  -- a retry, a widened radius, a re-post — and must not produce a second copy
  -- in someone's inbox.
  constraint job_offers_unique_per_tradesman
    unique (job_request_id, tradesman_id)
);

comment on table public.job_offers is
  'One lead: a job_request put in front of one tradesperson. Written by the fan-out edge function, never by a client.';

create index if not exists job_offers_tradesman_idx
  on public.job_offers (tradesman_id, offered_at desc);

-- The inbox only ever asks for the live ones.
create index if not exists job_offers_open_idx
  on public.job_offers (tradesman_id, offered_at desc)
  where status in ('offered', 'viewed');

create index if not exists job_offers_request_idx
  on public.job_offers (job_request_id);

-- ============================================================
-- 2. How many people a request reached
-- ============================================================
--
-- A count on the request rather than letting the customer read the offer rows.
--
-- "Has anybody seen my job" is a fair question and the panel needs to answer
-- it. But the rows themselves name every tradesperson who was offered the work
-- and, once they respond, every one who turned it down. A homeowner has no
-- business with that list. A number answers the question and names nobody.

alter table public.job_requests
  add column if not exists offers_sent integer not null default 0;

create or replace function public.job_requests_recount_offers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.job_requests jr
  set offers_sent = (
    select count(*) from public.job_offers o where o.job_request_id = jr.id
  )
  where jr.id in (select job_request_id from changed);
  return null;
end;
$$;

-- Statement triggers over a transition table, not row triggers. The fan-out
-- inserts the whole batch in one statement, and a row trigger would re-run the
-- same count once per offer — fifty counts of a table it is halfway through
-- writing. Both triggers name the transition table `changed` so one function
-- serves both.
drop trigger if exists job_offers_recount on public.job_offers;

create or replace trigger job_offers_recount_insert
  after insert on public.job_offers
  referencing new table as changed
  for each statement execute function public.job_requests_recount_offers();

create or replace trigger job_offers_recount_delete
  after delete on public.job_offers
  referencing old table as changed
  for each statement execute function public.job_requests_recount_offers();

create or replace trigger job_offers_touch_updated_at
  before update on public.job_offers
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 3. Row level security
-- ============================================================

alter table public.job_offers enable row level security;

-- A tradesperson sees their own leads. Nothing else — not other people's
-- offers on the same job, and not the fact that anyone else was offered it.
drop policy if exists "tradesman reads own offers" on public.job_offers;
create policy "tradesman reads own offers"
  on public.job_offers for select
  using (auth.uid() = tradesman_id);

-- Marking one viewed or declined is the tradesperson's own business. Accepting
-- is NOT: it is a race between everyone holding the same lead, so it goes
-- through accept_job_offer() below and this policy deliberately does not allow
-- writing 'accepted' directly.
drop policy if exists "tradesman updates own offers" on public.job_offers;
create policy "tradesman updates own offers"
  on public.job_offers for update
  using (auth.uid() = tradesman_id)
  with check (
    auth.uid() = tradesman_id
    and status in ('offered', 'viewed', 'declined')
  );

-- No insert policy at all. Offers are written by the fan-out under the service
-- role. A client that could insert its own offer row could put itself in front
-- of any job in the country, which is the whole product.

-- ============================================================
-- 4. Viewing a lead, once
-- ============================================================
--
-- Separate from a plain UPDATE because it has to be idempotent: the allowance
-- is spent the first time a lead is opened and never again, however many times
-- the screen rebuilds.

create or replace function public.view_job_offer(in_offer_id uuid)
returns public.job_offers
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.job_offers;
begin
  update public.job_offers
  set status   = case when status = 'offered' then 'viewed' else status end,
      viewed_at = coalesce(viewed_at, now())
  where id = in_offer_id
    and tradesman_id = auth.uid()
  returning * into result;

  if result.id is null then
    raise exception 'That lead is not yours' using errcode = '42501';
  end if;

  -- Count it only on the transition. coalesce() above means a second call
  -- leaves viewed_at alone, and this guard means it leaves the counter alone
  -- too.
  if result.viewed_at is not null and result.status = 'viewed' then
    insert into public.usage_counters (owner_id, leads_viewed)
    values (auth.uid(), 1)
    on conflict (owner_id) do update
      set leads_viewed = public.usage_counters.leads_viewed + 1,
          updated_at = now();
  end if;

  return result;
end;
$$;

revoke all on function public.view_job_offer(uuid) from public, anon;
grant execute on function public.view_job_offer(uuid) to authenticated;

-- ============================================================
-- 5. Accepting a lead
-- ============================================================
--
-- The only genuinely contended write in the system. Every tradesperson holding
-- this lead is racing for it, and exactly one must win.
--
-- The win is decided by a single conditional UPDATE on job_requests: the row
-- moves from 'posted' to 'assigned' only if it is still 'posted'. Postgres
-- serialises that, so the second caller updates zero rows and is told plainly
-- that it has gone. Checking "is it still open?" and then writing would be two
-- statements with a gap between them, and that gap is how two tradespeople end
-- up at the same house.

create or replace function public.accept_job_offer(in_offer_id uuid)
returns public.job_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  offer   public.job_offers;
  request public.job_requests;
begin
  select * into offer
  from public.job_offers
  where id = in_offer_id and tradesman_id = auth.uid();

  if offer.id is null then
    raise exception 'That lead is not yours' using errcode = '42501';
  end if;

  if offer.status in ('declined', 'withdrawn') then
    raise exception 'That lead is no longer open' using errcode = 'P0001';
  end if;

  -- The race, decided in one statement.
  update public.job_requests
  set status      = 'assigned',
      accepted_by = auth.uid()
  where id = offer.job_request_id
    and status = 'posted'
    and accepted_by is null
  returning * into request;

  if request.id is null then
    raise exception 'Somebody else has already taken this job'
      using errcode = 'P0001';
  end if;

  update public.job_offers
  set status = 'accepted', responded_at = now()
  where id = offer.id;

  -- Everyone else's copy stops being actionable the moment it is gone. Leaving
  -- them 'offered' would mean an inbox full of jobs that cannot be accepted,
  -- and a tap that only ever produces an error.
  update public.job_offers
  set status = 'withdrawn', responded_at = now()
  where job_request_id = offer.job_request_id
    and id <> offer.id
    and status in ('offered', 'viewed');

  return request;
end;
$$;

revoke all on function public.accept_job_offer(uuid) from public, anon;
grant execute on function public.accept_job_offer(uuid) to authenticated;

-- ============================================================
-- 6. Who should this job go to?
-- ============================================================
--
-- The fan-out's one question, answered in the database rather than in the edge
-- function, because it is the plan gate — and the plan gate is the product.
--
-- Each tradesperson is tested against THEIR OWN radius, not one radius for the
-- whole query. Standard's radius is 0, so a Standard account can never satisfy
-- `distance <= radius` and is excluded without needing to be named here. That
-- is the "—" in the comparison table, expressed as arithmetic rather than as a
-- special case that someone has to remember to keep writing.

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
  -- One plan per tradesperson: their live subscription, or nothing. A missing
  -- subscription is treated as no plan rather than as Standard, because
  -- guessing generously here would hand out paid leads for free.
  plans as (
    select
      p.id as profile_id,
      p.latitude,
      p.longitude,
      p.trade,
      sp.plan_type,
      coalesce(
        (sp.tradesman_limits ->> 'serviceRadiusMiles')::int,
        (sp.business_limits  ->> 'serviceRadiusMiles')::int,
        0
      ) as radius_miles
    from public.profiles p
    join public.subscriptions s
      on s.owner_id = p.id and s.status in ('active', 'trial')
    -- Prefer the plan row for this account's own type, and fall back to the
    -- tradesman row when there is none. There are currently NO rows with
    -- account_type = 'business', so a plain equality join would silently give
    -- every business account a radius of nothing and quietly exclude them from
    -- every job in the country. When business rows are added they take
    -- precedence automatically, because the ordering prefers an exact match.
    join lateral (
      select sp.*
      from public.subscription_plans sp
      where sp.plan_type = s.plan_type
        and sp.account_type in (p.account_type, 'tradesman')
      order by (sp.account_type = p.account_type) desc
      limit 1
    ) sp on true
    where p.account_type <> 'customer'
      and p.latitude is not null
      and p.longitude is not null
  )
  select
    plans.profile_id,
    dist.km,
    plans.plan_type,
    plans.radius_miles
  from req, plans,
  lateral (
    select 6371 * 2 * asin(sqrt(
      power(sin(radians(plans.latitude - req.latitude) / 2), 2)
      + cos(radians(req.latitude)) * cos(radians(plans.latitude))
      * power(sin(radians(plans.longitude - req.longitude) / 2), 2)
    )) as km
  ) dist
  where req.latitude is not null
    -- The trade has to match when the tradesperson has declared one. Eleven of
    -- the customer catalogue's services have no counterpart in the Pro app's
    -- trade list, so `service_id is null or not in their list` would silently
    -- match nobody for those; a null service falls through to distance alone.
    and (req.service_id is null or req.service_id = any (plans.trade))
    -- -1 is unlimited; 0 excludes. Miles to kilometres.
    and (plans.radius_miles = -1 or dist.km <= plans.radius_miles * 1.609344)
  order by dist.km;
$$;

comment on function public.candidates_for_job_request is
  'Tradespeople whose plan radius covers this job. Each is tested against their own radius, so Standard (0) never matches. Service role only.';

-- Not for authenticated. It reads every profile's location and plan, which is
-- both commercially sensitive and personal.
revoke all on function public.candidates_for_job_request(uuid)
  from public, anon, authenticated;
grant execute on function public.candidates_for_job_request(uuid) to service_role;
