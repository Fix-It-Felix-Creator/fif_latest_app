-- One queue for one journey.
--
-- Verification and leads approval are two decisions with different evidence,
-- and they stay two decisions. But they are SEQUENTIAL — an unverified account
-- cannot be approved for leads at all — and showing them as two lists made
-- staff hold that sequence in their heads and check two pages to answer "where
-- is this tradesperson up to".
--
-- The app already shows it as one card walking one path. This is the same path
-- from the other side.
--
-- A view rather than a query in the panel, so "what stage is somebody at" has
-- one definition. Two places computing it is two places to disagree the first
-- time a status is added.

create or replace view public.tradesperson_approval_queue as
with latest_application as (
  -- One row per person: the application that counts. Live first, then the
  -- most recent piece of history — the same rule the app's status screen
  -- uses, so the two never disagree about which application they mean.
  select distinct on (owner_id)
    owner_id,
    id         as application_id,
    status     as application_status,
    services,
    registrations,
    base_address,
    base_latitude,
    has_own_insurance,
    insurer,
    policy_number,
    policy_expires_at,
    moves_waste,
    waste_carrier_number,
    headline,
    about,
    applicant_type,
    submitted_at,
    rejection_reason as application_rejection_reason
  from public.lead_applications
  order by
    owner_id,
    (status in ('submitted', 'approved')) desc,
    submitted_at desc
)
select
  p.id,
  p.email,
  p.first_name,
  p.last_name,
  p.account_type,
  p.created_at,
  p.verification_status,
  p.rejection_reason as verification_rejection_reason,
  p.document_type,
  coalesce(array_length(p.document_urls, 1), 0) as document_count,
  p.document_urls,
  p.selfie_url,
  la.application_id,
  la.application_status,
  la.application_rejection_reason,
  la.applicant_type,
  la.services,
  la.registrations,
  la.base_address,
  la.base_latitude,
  la.has_own_insurance,
  la.insurer,
  la.policy_number,
  la.policy_expires_at,
  la.moves_waste,
  la.waste_carrier_number,
  la.headline,
  la.about,
  la.submitted_at,

  -- The stage, in the order somebody actually moves through it. Named for
  -- what a reviewer would say out loud, not for the column it came from.
  case
    when p.verification_status = 'waiting'  then 'id_to_check'
    when p.verification_status = 'rejected' then 'id_rejected'
    when p.verification_status is distinct from 'verified' then 'not_started'
    when la.application_status = 'submitted' then 'leads_to_review'
    when la.application_status = 'rejected'  then 'leads_rejected'
    when la.application_status = 'approved'  then 'approved'
    else 'verified'
  end as stage,

  -- Whether anybody has to do anything. The default filter, because a queue
  -- is for finding the next piece of work.
  -- coalesce, because verification_status is null on every account that has
  -- never been through it: `null = 'waiting'` is NULL, `NULL or false` is
  -- NULL, and a null here would drop those rows out of a `needs_action =
  -- false` filter as well as a true one — present in neither list.
  coalesce(
    p.verification_status = 'waiting'
    or (p.verification_status = 'verified'
        and la.application_status = 'submitted'),
    false
  ) as needs_action,

  -- Which queue it has been waiting in, for ordering. Oldest first is the
  -- fair order, and it is the number somebody will eventually want to report
  -- on.
  case
    when p.verification_status = 'waiting' then p.updated_at
    else la.submitted_at
  end as waiting_since

from public.profiles p
left join latest_application la on la.owner_id = p.id
where p.account_type <> 'customer';

comment on view public.tradesperson_approval_queue is
  'One row per tradesperson with the stage they have reached. Staff-facing; read through the service role only.';

-- Views do not carry RLS of their own, and this one reads every profile. The
-- panel is a server app holding the service key; nothing signed in as a normal
-- user should be able to select it.
revoke all on public.tradesperson_approval_queue from anon, authenticated;
grant select on public.tradesperson_approval_queue to service_role;
