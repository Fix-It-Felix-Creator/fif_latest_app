-- A testable way for server-side functions to write server-reserved columns.
--
-- `profiles_guard_server_columns` lets a write through when
-- `auth.role() = 'service_role'`. That is true of the panel, which calls
-- everything with the service key — but it is a property of the REQUEST, not
-- of the code doing the writing. A security-definer function that is only
-- executable by service_role still cannot set verification_status when it is
-- invoked any other way: a migration, a psql session, a test harness, a
-- future scheduled job.
--
-- The practical cost is that the one code path which needs this is the one
-- code path that cannot be tested before it ships. So the guard now also
-- accepts an explicit, transaction-local flag that a server-side function
-- sets deliberately.
--
-- `set_config(..., true)` is local to the transaction and resets at commit or
-- rollback, so the flag cannot leak into the next statement on a pooled
-- connection. It lives in the `fif.` namespace, and nothing reachable over
-- PostgREST can set it — set_config is in pg_catalog, which is not an exposed
-- schema.

create or replace function public.profiles_guard_server_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  -- Set by a server-side function that has decided this write is legitimate.
  if coalesce(current_setting('fif.server_write', true), '') = 'on' then
    return new;
  end if;

  if new.verification_status is distinct from old.verification_status then
    raise exception 'profiles: verification_status is set by the server';
  end if;
  if new.account_status is distinct from old.account_status then
    raise exception 'profiles: account_status is set by the server';
  end if;
  if new.deletion_requested_at is distinct from old.deletion_requested_at
     or new.deletion_scheduled_at is distinct from old.deletion_scheduled_at then
    raise exception 'profiles: deletion timestamps are set by the server';
  end if;
  if new.recovery_window_ends_at is distinct from old.recovery_window_ends_at
     or new.personal_data_retained_until is distinct from old.personal_data_retained_until then
    raise exception 'profiles: deletion window timestamps are set by the server';
  end if;
  if new.firebase_uid is distinct from old.firebase_uid
     or new.password_migrated_at is distinct from old.password_migrated_at then
    raise exception 'profiles: migration columns are set by the server';
  end if;
  return new;
end;
$$;
