-- Claim only the thing that is unambiguously new.
--
-- The approval message listed emailing quotes and sharing links alongside live
-- leads. All three are genuinely gated — the api function returns 403 on the
-- first two — but a tradesperson reading it does not know that, because they
-- have been sending quotes all along as PDFs from the send screen, which is
-- not gated and should not be.
--
-- "You can now send quotes" therefore reads as wrong to the one person it is
-- addressed to, whatever the endpoint does. Live leads are the thing that did
-- not exist for them before and does now, so that is what the message says.
-- The full list of what verification opens still lives in the app, where
-- there is room to draw the distinction properly.

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

  if new.status = 'withdrawn' then
    return new;
  end if;

  if new.status = 'approved' then
    insert into public.notifications (owner_id, type, title, body, payload)
    values (
      new.owner_id,
      'lead_application',
      'Your account is verified',
      'Live leads from homeowners near you can now reach you.',
      jsonb_build_object('applicationId', new.id, 'status', new.status)
    );
  elsif new.status = 'rejected' then
    insert into public.notifications (owner_id, type, title, body, payload)
    values (
      new.owner_id,
      'lead_application',
      'Your verification needs attention',
      coalesce(
        new.rejection_reason,
        'Open the app to see what needs fixing.'
      ),
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
