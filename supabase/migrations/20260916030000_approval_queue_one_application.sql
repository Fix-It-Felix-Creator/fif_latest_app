-- The queue, for one application instead of two decisions.
--
-- The previous version computed a stage from verification_status AND the
-- application, on the assumption that identity was decided separately. It is
-- not any more: there is one application, and approving it verifies the
-- person.
--
-- The symptom was an application that had been submitted from the app sitting
-- in the table and appearing nowhere in the panel — filed as 'not_started'
-- because the profile was not yet verified, and therefore excluded from the
-- default "waiting on you" filter. The row existed; the view simply could not
-- describe it.

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
    document_type as application_document_type,
    document_paths,
    selfie_path,
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
  -- Prefer the application's own documents over the profile copy: the
  -- application is what is being decided, and the profile is a bind of it.
  coalesce(la.application_document_type, p.document_type) as document_type,
  coalesce(
    array_length(la.document_paths, 1),
    array_length(p.document_urls, 1),
    0
  ) as document_count,
  coalesce(la.document_paths, p.document_urls) as document_urls,
  coalesce(la.selfie_path, p.selfie_url) as selfie_url,
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

  -- One application, so the stage is the application's status. The only
  -- thing verification adds is the case of somebody verified by hand with no
  -- application at all.
  case
    when la.application_status = 'submitted' then 'to_review'
    when la.application_status = 'approved'  then 'approved'
    when la.application_status = 'rejected'  then 'rejected'
    when la.application_status = 'withdrawn' then 'withdrawn'
    when p.verification_status = 'verified'  then 'verified'
    else 'not_started'
  end as stage,

  -- coalesce, because application_status is null for anybody who has never
  -- applied: `null = 'submitted'` is NULL, and a null here would drop those
  -- rows out of a `needs_action = false` filter as well as a true one.
  coalesce(la.application_status = 'submitted', false) as needs_action,

  la.submitted_at as waiting_since

from public.profiles p
left join latest_application la on la.owner_id = p.id
where p.account_type <> 'customer';

revoke all on public.tradesperson_approval_queue from anon, authenticated;
grant select on public.tradesperson_approval_queue to service_role;
