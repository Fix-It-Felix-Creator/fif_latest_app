-- Make realtime DELETE events reach the client.
--
-- Symptom: delete a journal event (or a customer, quote, job, tool asset —
-- anything backed by OwnedCollectionRepository.watchAll()) and the row
-- vanishes from Postgres but stays on screen until the app is restarted.
--
-- Cause: every published table was on the default replica identity, so
-- Postgres writes only the PRIMARY KEY into the WAL for a DELETE. The
-- realtime payload therefore carries `{id: ...}` and nothing else — no
-- `owner_id`.
--
-- That breaks the client twice over:
--
--   1. `watchAll()` subscribes with `.eq('owner_id', <uid>)`. For a DELETE,
--      the filter is evaluated against the old record, which has no
--      `owner_id` column at all, so the event never matches and is dropped.
--
--   2. Realtime enforces RLS per subscriber. Our policy is
--      `auth.uid() = owner_id`; with only the primary key present it cannot
--      be evaluated, so the event would be withheld even without the filter.
--
-- INSERT and UPDATE were unaffected — their payloads carry the full new row,
-- so `owner_id` is present and both the filter and the policy match. That is
-- exactly why creating worked and deleting did not.
--
-- Fix: REPLICA IDENTITY FULL, which writes the complete old row to the WAL.
--
-- Cost: more WAL volume per update/delete, since the whole prior row is
-- logged rather than just the key. These tables are small, per-user and
-- low-churn, so this is the right trade for correct deletes. It is also the
-- approach Supabase documents for filtered realtime deletes.
--
-- Applied to every table in the `supabase_realtime` publication rather than a
-- hardcoded list, so this stays correct as the publication changes.
--
-- NOTE: a table added to the publication AFTER this migration runs will start
-- on the default replica identity again and reintroduce the bug. Set
-- `replica identity full` alongside any future `alter publication ... add table`.

do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename
    from pg_publication_tables
    where pubname = 'supabase_realtime'
  loop
    execute format(
      'alter table %I.%I replica identity full',
      r.schemaname, r.tablename
    );
    raise notice 'replica identity full: %.%', r.schemaname, r.tablename;
  end loop;
end $$;
