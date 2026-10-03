-- Phase 3 — let users clear their own notifications, and add the tools bucket.
--
-- 1. notifications had SELECT and UPDATE policies but no DELETE, so
--    NotificationsRepository.clear()/clearAll() had nowhere to go. The old app
--    routed them through a Cloud Function, but there is no privilege question
--    here — a user dismissing their own notification is owner-scoped like every
--    other delete in the schema. Adding the policy keeps the behaviour and
--    removes two server round-trips.
--
--    The notifications_only_read_flag trigger is untouched: clients still
--    cannot rewrite a notification's contents, only mark it read or remove it.
--
-- 2. `user-tools` bucket for the Notes/Photos/Videos/Files tools. Object keys
--    keep the paths the app already builds (users/{uid}/tools/...), so the
--    Phase 8 copy from Firebase Storage is a straight key move.

create policy "owner deletes notifications"
  on public.notifications for delete
  using (auth.uid() = owner_id);

insert into storage.buckets (id, name, public, file_size_limit)
values ('user-tools', 'user-tools', false, 524288000)
on conflict (id) do nothing;

-- uid is the second path segment: users/{uid}/tools/...
drop policy if exists "owner reads own tools" on storage.objects;
create policy "owner reads own tools"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'user-tools'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner uploads own tools" on storage.objects;
create policy "owner uploads own tools"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'user-tools'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner updates own tools" on storage.objects;
create policy "owner updates own tools"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'user-tools'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner deletes own tools" on storage.objects;
create policy "owner deletes own tools"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'user-tools'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
