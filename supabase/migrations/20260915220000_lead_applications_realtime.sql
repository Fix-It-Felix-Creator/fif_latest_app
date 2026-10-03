-- Put lead_applications on realtime.
--
-- Without this the status screen never moves: the app subscribes to a table
-- that is not published, the subscription errors, and an approval that landed
-- thirty seconds ago is invisible until the app is restarted. That is the one
-- screen somebody sits and watches.
--
-- `replica identity full` in the same breath, as
-- 20260824093000_realtime_delete_replica_identity.sql asks any later
-- publication change to do — without it a DELETE carries only the primary key,
-- so the `.eq('owner_id', uid)` filter cannot match it and RLS cannot evaluate
-- `auth.uid() = owner_id` either.
--
-- This is the second time the same step has been missed. It is missable
-- because nothing fails loudly: the insert works, the row is correct, and only
-- the live update is gone.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'lead_applications'
  ) then
    alter publication supabase_realtime add table public.lead_applications;
  end if;
end
$$;

alter table public.lead_applications replica identity full;
