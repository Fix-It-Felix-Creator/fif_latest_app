-- Phase 3 — the single-device-login force-logout flags.
--
-- device_info_repository implements single-device login: signing in on a new
-- device stamps `forceLogoutAt` / `forceLogoutReason` on every other device
-- record, and each device watches its own row to detect being kicked. Both
-- fields were missed when user_devices was designed in Phase 1, so the whole
-- mechanism had nowhere to write.

alter table public.user_devices
  add column if not exists force_logout_at     timestamptz,
  add column if not exists force_logout_reason text;

comment on column public.user_devices.force_logout_at is
  'Set when another device signs in; the device watching this row signs itself out.';

-- The watcher needs realtime events for its own row.
alter publication supabase_realtime add table public.user_devices;
