-- Say only what is actually true.
--
-- The approval message claimed verification let somebody "send quotes and
-- invoices to customers". They could already: the quote send screen offers
-- "Send as PDF", which builds the document on the device and hands it to the
-- OS share sheet. No API call, no gate, and rightly so — it is their document,
-- from their own data, and they could screenshot it anyway.
--
-- What verification actually opens is the two paths that carry Fix It Felix
-- to the customer: a hosted page on our domain with Accept and Decline, and
-- an email sent from our system. Those are the ones where we are vouching for
-- the person, and those are the ones the api function refuses with a 403.

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
      'You can now send quotes and invoices by email or share link, and '
        || 'receive live leads from homeowners near you.',
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
