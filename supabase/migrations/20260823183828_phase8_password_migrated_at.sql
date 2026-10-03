-- Phase 8 — records that a migrated account has crossed to a Supabase password.
--
-- The auth bridge verifies an old Firebase password once and copies it across.
-- This column marks that as done so the bridge refuses a second attempt: after
-- the crossing the password works against Supabase directly, and leaving the
-- bridge open would keep a Firebase-backed password-guessing path alive for no
-- reason.
--
-- Server-owned, like the other columns the guard protects.

alter table public.profiles
  add column if not exists password_migrated_at timestamptz;

create or replace function public.profiles_guard_server_columns()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role' then
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
end
$$;
