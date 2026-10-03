-- Put job_requests on realtime.
--
-- Without this the customer app's Jobs tab spins forever: the repository's
-- `.stream()` subscribes to a table that is not published, the subscription
-- errors, and the list never arrives. The job itself posts perfectly well —
-- which is what made it look like a loading bug rather than a missing
-- publication.
--
-- `replica identity full` is set in the same breath, exactly as
-- 20260824093000_realtime_delete_replica_identity.sql asks any later
-- publication change to do. That migration set it across every table then in
-- the publication, and closed with a note that anything added afterwards
-- starts on the default identity again and reintroduces the DELETE bug: a
-- DELETE would carry only the primary key, so the `.eq('customer_id', uid)`
-- filter could not match it and RLS could not evaluate `auth.uid() =
-- customer_id` either. Cancelling a job would leave it on screen until the
-- app restarted.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'job_requests'
  ) then
    alter publication supabase_realtime add table public.job_requests;
  end if;
end
$$;

alter table public.job_requests replica identity full;
