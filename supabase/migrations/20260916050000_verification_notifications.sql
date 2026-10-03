-- Say what actually happened.
--
-- The notification told people they had been "approved for live leads". That
-- was true when the application was only about leads. It is now the
-- verification application, and being approved opens sending quotes and
-- invoices to customers and share links as well — so a message naming only
-- leads describes the smallest part of what changed, and sends somebody
-- looking for it to the wrong screen.

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
      'Your account is verified',
      'You can now send quotes and invoices to customers, share documents by '
        || 'link, and receive live leads from homeowners near you.',
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
