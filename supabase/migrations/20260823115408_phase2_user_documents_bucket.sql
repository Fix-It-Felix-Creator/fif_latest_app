-- Phase 2 — storage bucket for user documents (profile image, KYC docs).
--
-- Object keys keep the exact paths DatabasePaths already produces, e.g.
--   users/{uid}/documents/profile/{timestamp}.jpg
-- so the Phase 8 file copy from Firebase Storage is a 1:1 key move rather than
-- a rename. `storageUsers` yields 'users' on dev and 'pod_users' on prod; both
-- are accepted below since dev and prod are now separate projects anyway.
--
-- Private bucket: files are served through signed URLs, replacing Firebase's
-- getDownloadURL().

insert into storage.buckets (id, name, public, file_size_limit)
values ('user-documents', 'user-documents', false, 52428800)
on conflict (id) do nothing;

-- The uid is the second path segment: users/{uid}/documents/...
-- foldername() is 1-indexed, so [2] is the uid.
drop policy if exists "owner reads own user documents" on storage.objects;
create policy "owner reads own user documents"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'user-documents'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner uploads own user documents" on storage.objects;
create policy "owner uploads own user documents"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'user-documents'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner updates own user documents" on storage.objects;
create policy "owner updates own user documents"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'user-documents'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "owner deletes own user documents" on storage.objects;
create policy "owner deletes own user documents"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'user-documents'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
