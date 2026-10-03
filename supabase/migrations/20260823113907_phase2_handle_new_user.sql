-- Phase 2 — create a profiles row whenever an auth user is created.
--
-- There was no trigger on auth.users, and profiles.id is a FK to auth.users(id).
-- Without this, every sign-up leaves an auth user with no profile, and the very
-- first getUserDetails() returns null — which the app reads as "onboarding not
-- complete". Doing it client-side instead would leave a window where a crash
-- between signUp() and the insert strands the account permanently.
--
-- Runs as SECURITY DEFINER so it can populate verification_status/account_status,
-- which profiles_guard_server_columns reserves for the server.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_full_name text := nullif(trim(coalesce(
    v_meta->>'full_name', v_meta->>'name', v_meta->>'display_name', '')), '');
  v_first text;
  v_last  text;
begin
  -- Google and Apple hand back a single display name; split it so the
  -- onboarding name step is satisfied and the user is never asked to retype a
  -- name the provider already gave us (App Store Guideline 4).
  if v_full_name is not null then
    v_first := split_part(v_full_name, ' ', 1);
    v_last  := nullif(trim(substr(v_full_name, length(split_part(v_full_name, ' ', 1)) + 1)), '');
  end if;

  insert into public.profiles (id, email, first_name, last_name, profile_image_url)
  values (
    new.id,
    new.email,
    coalesce(nullif(v_meta->>'first_name', ''), v_first),
    coalesce(nullif(v_meta->>'last_name', ''),  v_last),
    nullif(coalesce(v_meta->>'avatar_url', v_meta->>'picture', ''), '')
  )
  on conflict (id) do nothing;

  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

comment on function public.handle_new_user() is
  'Creates the public.profiles row for a new auth user, seeding name/avatar from OAuth metadata.';
