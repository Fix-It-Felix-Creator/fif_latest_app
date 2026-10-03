-- What a tradesperson can see of jobs they have not taken yet.
--
-- The original design deliberately had NO discovery policy: letting any
-- signed-in tradesperson select open job_requests would hand out the address
-- and postcode of every homeowner who has ever posted. That reasoning still
-- holds, so this is not a policy — it is a function that decides, per caller,
-- what they may see and how precisely.
--
-- The rule is the one every established trades marketplace uses: you see the
-- AREA before you take a job, and the door only after. So the full address is
-- withheld until the job is theirs, and the coordinates are rounded to two
-- decimal places — about a kilometre — which is enough to put a pin on a map
-- and useless for turning up uninvited.

create or replace function public.nearby_job_requests(
  in_limit integer default 50
)
returns table (
  id              uuid,
  service_id      text,
  service_name    text,
  summary         text,
  description     text,
  urgency         text,
  status          text,
  posted_at       timestamptz,
  distance_km     double precision,
  -- Rounded. Precise enough for a map pin, useless for a doorstep.
  approx_latitude  double precision,
  approx_longitude double precision,
  -- "G74" rather than "G74 3NN": the district says which town, the full code
  -- says which street.
  postcode_district text,
  offers_sent     integer,
  mine            boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select
      p.id,
      la.base_latitude  as lat,
      la.base_longitude as lng,
      la.services,
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
    where p.id = auth.uid()
      -- Every gate the matching function applies, applied here too. A board
      -- somebody can browse while unverified would be a way around the whole
      -- verification requirement.
      and p.verification_status = 'verified'
      and p.account_type <> 'customer'
      and la.base_latitude is not null
  )
  select
    r.id,
    r.service_id,
    r.service_name,
    -- The deepest thing they picked, which is what the job IS.
    coalesce(
      (r.selections -> (jsonb_array_length(r.selections) - 1) ->> 'name'),
      r.service_name
    ) as summary,
    r.description,
    r.urgency,
    r.status,
    r.created_at,
    dist.km,
    round(r.latitude::numeric, 2)::double precision,
    round(r.longitude::numeric, 2)::double precision,
    split_part(coalesce(r.postcode, ''), ' ', 1),
    r.offers_sent,
    -- coalesce, not a bare comparison: accepted_by is null on every open
    -- job, and `null = uuid` is null, not false. A nullable boolean leaking
    -- out of a column declared `boolean` is the same defect that made
    -- needs_action return null instead of false.
    coalesce(r.accepted_by = me.id, false) as mine
  from public.job_requests r, me,
  lateral (
    select 6371 * 2 * asin(sqrt(
      power(sin(radians(r.latitude - me.lat) / 2), 2)
      + cos(radians(me.lat)) * cos(radians(r.latitude))
      * power(sin(radians(r.longitude - me.lng) / 2), 2)
    )) as km
  ) dist
  where r.latitude is not null
    -- Open, or already theirs. A job they accepted stays on their board.
    and (r.status = 'posted' or r.accepted_by = me.id)
    and (r.service_id is null or r.service_id = any (me.services))
    and (me.radius_miles = -1
         or dist.km <= me.radius_miles * 1.609344)
  order by dist.km
  limit greatest(coalesce(in_limit, 50), 1);
$$;

comment on function public.nearby_job_requests is
  'Open jobs within the calling tradesperson''s plan radius. Address withheld and coordinates rounded to ~1km until the job is theirs.';

-- Callable by a signed-in user, because it scopes itself to auth.uid() and
-- returns nothing to anybody who is not verified and approved.
revoke all on function public.nearby_job_requests(integer) from public, anon;
grant execute on function public.nearby_job_requests(integer) to authenticated;

-- ============================================================
-- The full detail, once it is theirs
-- ============================================================
--
-- Accepting is what turns an area into an address. Until then the board shows
-- a district; afterwards the tradesperson needs the door, because they have
-- to get there.

create or replace function public.job_request_detail(in_request_id uuid)
returns public.job_requests
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result public.job_requests;
begin
  select * into result
  from public.job_requests
  where id = in_request_id and accepted_by = auth.uid();

  if result.id is null then
    raise exception 'That job is not yours' using errcode = '42501';
  end if;

  return result;
end;
$$;

revoke all on function public.job_request_detail(uuid) from public, anon;
grant execute on function public.job_request_detail(uuid) to authenticated;
