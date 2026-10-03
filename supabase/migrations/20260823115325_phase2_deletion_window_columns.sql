-- Phase 2 — the two deletion-window timestamps the account-recovery screen reads.
--
-- handleAuthentication() routes a `deletion_pending` account to /accountDisabled
-- and passes both values as arguments (routes.dart:310-312). They are written
-- server-side by functions/src/account/requestDeletion.ts and only read by the
-- client, so they join the server-owned set.
--
-- Kept distinct from the existing deletion_requested_at / deletion_scheduled_at:
-- those record when deletion was asked for and when it runs, whereas these two
-- are the user-facing recovery deadline and the data-retention deadline. Reusing
-- one for the other would show users the wrong date.

alter table public.profiles
  add column if not exists recovery_window_ends_at timestamptz,
  add column if not exists personal_data_retained_until timestamptz;

comment on column public.profiles.recovery_window_ends_at is
  'Deadline for the user to recover a deletion-pending account. Server-set.';
comment on column public.profiles.personal_data_retained_until is
  'Deadline after which personal data is purged. Server-set.';

-- Extend the guard so a client cannot move its own recovery deadline.
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
  return new;
end
$$;
