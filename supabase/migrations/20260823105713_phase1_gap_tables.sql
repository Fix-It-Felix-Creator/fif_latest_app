-- Phase 1 — close the gaps between the existing schema and what the app uses.
--
-- The baseline schema covers the core business objects well. This migration adds
-- the areas live code reads/writes that had no table, and corrects usage_counters
-- to match the app's actual counters.
--
-- Conventions follow the baseline: owner_id + auth.uid() RLS, "owner {verb}s {table}"
-- policy names, touch_updated_at() triggers.

-- ============================================================
-- 1. profiles.firebase_uid — Firebase uid → auth.users.id mapping
--    Required by the Phase 8 data migration. Firebase uids are 28-char
--    strings, not UUIDs, so they cannot be reused as primary keys.
-- ============================================================
alter table public.profiles
  add column if not exists firebase_uid text;

create unique index if not exists uq_profiles_firebase_uid
  on public.profiles (firebase_uid)
  where firebase_uid is not null;

-- ============================================================
-- 2. app_config — replaces Firebase Remote Config and the RTDB `config/` node
--    Read by AppConfigService, subscription_config_service,
--    commission_repository, configurations_repositories.
--    Publicly readable (it is client configuration), writable only by service role.
-- ============================================================
create table if not exists public.app_config (
  key         text primary key,
  value       jsonb not null default '{}'::jsonb,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.app_config enable row level security;

create policy "anyone reads app_config"
  on public.app_config for select
  using (true);

create or replace trigger app_config_touch_updated_at
  before update on public.app_config
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 3. user_devices — RTDB devices/$uid/$deviceId
--    device_info_repository (875 lines), 9 call sites.
-- ============================================================
create table if not exists public.user_devices (
  owner_id           uuid not null references auth.users (id) on delete cascade,
  device_id          text not null,
  fcm_token          text,
  platform           text,
  os_version         text,
  device_model       text,
  manufacturer       text,
  app_version        text,
  build_number       text,
  screen_width       double precision,
  screen_height      double precision,
  locale             text,
  timezone           text,
  is_physical_device boolean not null default true,
  is_active          boolean not null default true,
  last_active_at     timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  primary key (owner_id, device_id)
);

alter table public.user_devices enable row level security;

create policy "owner reads user_devices"   on public.user_devices for select using (auth.uid() = owner_id);
create policy "owner inserts user_devices" on public.user_devices for insert with check (auth.uid() = owner_id);
create policy "owner updates user_devices" on public.user_devices for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes user_devices" on public.user_devices for delete using (auth.uid() = owner_id);

create index if not exists idx_user_devices_owner_active
  on public.user_devices (owner_id, is_active);

create or replace trigger user_devices_touch_updated_at
  before update on public.user_devices
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 4. user_sessions — RTDB sessions/$uid/$sessionId (+ history)
--    11 call sites. `status` distinguishes active from historical,
--    replacing the separate RTDB history node.
-- ============================================================
create table if not exists public.user_sessions (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references auth.users (id) on delete cascade,
  session_id       text not null,
  device_id        text,
  fcm_token        text,
  status           text not null default 'active',
  ip_address       text,
  user_agent       text,
  login_method     text,
  platform         text,
  device_model     text,
  app_version      text,
  login_location   jsonb,
  login_at         timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  logout_at        timestamptz,
  created_at       timestamptz not null default now(),
  unique (owner_id, session_id)
);

alter table public.user_sessions enable row level security;

create policy "owner reads user_sessions"   on public.user_sessions for select using (auth.uid() = owner_id);
create policy "owner inserts user_sessions" on public.user_sessions for insert with check (auth.uid() = owner_id);
create policy "owner updates user_sessions" on public.user_sessions for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes user_sessions" on public.user_sessions for delete using (auth.uid() = owner_id);

create index if not exists idx_user_sessions_owner_status
  on public.user_sessions (owner_id, status, last_activity_at desc);

-- ============================================================
-- 5. portfolio_media — RTDB users/$uid/portfolio/{images,videos,job_videos,highlights}
--    22 call sites across tradesman_repository. `kind` replaces the four
--    sibling RTDB nodes.
-- ============================================================
create table if not exists public.portfolio_media (
  id                     uuid primary key default gen_random_uuid(),
  owner_id               uuid not null references auth.users (id) on delete cascade,
  kind                   text not null check (kind in ('image', 'video', 'job_video', 'highlight')),
  sort_order             integer not null default 0,
  title                  text not null default '',
  description            text not null default '',
  url                    text,
  storage_path           text,
  thumbnail_url          text,
  thumbnail_storage_path text,
  cover_url              text,
  media_url              text,
  is_video               boolean not null default false,
  job_id                 uuid,
  job_title              text,
  file_size              bigint not null default 0,
  duration_seconds       integer,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

alter table public.portfolio_media enable row level security;

create policy "owner reads portfolio_media"   on public.portfolio_media for select using (auth.uid() = owner_id);
create policy "owner inserts portfolio_media" on public.portfolio_media for insert with check (auth.uid() = owner_id);
create policy "owner updates portfolio_media" on public.portfolio_media for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes portfolio_media" on public.portfolio_media for delete using (auth.uid() = owner_id);

create index if not exists idx_portfolio_media_owner_kind
  on public.portfolio_media (owner_id, kind, sort_order);

create or replace trigger portfolio_media_touch_updated_at
  before update on public.portfolio_media
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 6. trade_cards — RTDB users/$uid/tradeCard (5 call sites)
-- ============================================================
create table if not exists public.trade_cards (
  owner_id            uuid primary key references auth.users (id) on delete cascade,
  card_scheme         text,
  card_color          text,
  qualification_level text,
  registration_number text,
  expiry_date         date,
  image_url           text,
  storage_path        text,
  mapped_trade        text,
  verification_status text,
  rejection_reason    text,
  file_size           bigint not null default 0,
  uploaded_at         timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.trade_cards enable row level security;

create policy "owner reads trade_cards"   on public.trade_cards for select using (auth.uid() = owner_id);
create policy "owner inserts trade_cards" on public.trade_cards for insert with check (auth.uid() = owner_id);
create policy "owner updates trade_cards" on public.trade_cards for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes trade_cards" on public.trade_cards for delete using (auth.uid() = owner_id);

create or replace trigger trade_cards_touch_updated_at
  before update on public.trade_cards
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 7. trade_qualifications — RTDB users/$uid/tradeQualifications (4 call sites)
-- ============================================================
create table if not exists public.trade_qualifications (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references auth.users (id) on delete cascade,
  name                text not null,
  issuing_body        text,
  reference           text,
  issue_date          date,
  expiry_date         date,
  url                 text,
  storage_path        text,
  file_size           bigint not null default 0,
  verification_status text,
  rejection_reason    text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.trade_qualifications enable row level security;

create policy "owner reads trade_qualifications"   on public.trade_qualifications for select using (auth.uid() = owner_id);
create policy "owner inserts trade_qualifications" on public.trade_qualifications for insert with check (auth.uid() = owner_id);
create policy "owner updates trade_qualifications" on public.trade_qualifications for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes trade_qualifications" on public.trade_qualifications for delete using (auth.uid() = owner_id);

create index if not exists idx_trade_qualifications_owner
  on public.trade_qualifications (owner_id);

create or replace trigger trade_qualifications_touch_updated_at
  before update on public.trade_qualifications
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 8. extra_documents — RTDB users/$uid/extraDocuments (6 call sites)
-- ============================================================
create table if not exists public.extra_documents (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references auth.users (id) on delete cascade,
  name         text not null,
  description  text not null default '',
  type         text,
  url          text,
  storage_path text,
  file_size    bigint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.extra_documents enable row level security;

create policy "owner reads extra_documents"   on public.extra_documents for select using (auth.uid() = owner_id);
create policy "owner inserts extra_documents" on public.extra_documents for insert with check (auth.uid() = owner_id);
create policy "owner updates extra_documents" on public.extra_documents for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "owner deletes extra_documents" on public.extra_documents for delete using (auth.uid() = owner_id);

create index if not exists idx_extra_documents_owner
  on public.extra_documents (owner_id);

create or replace trigger extra_documents_touch_updated_at
  before update on public.extra_documents
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 9. usage_counters — the app tracks 17 counters; the baseline had 3,
--    only two of which matched. Add the rest.
--
--    Reset semantics: the app resets on SUBSCRIPTION CHANGE, not monthly
--    (usage_repository.resetUsage() is called only from updateSubscription).
--    bump_usage's monthly auto-zero is therefore removed below so behaviour
--    matches the current app exactly.
-- ============================================================
alter table public.usage_counters
  add column if not exists address_count               integer not null default 0,
  add column if not exists job_count                   integer not null default 0,
  add column if not exists invoice_count               integer not null default 0,
  add column if not exists quotation_count             integer not null default 0,
  add column if not exists template_count              integer not null default 0,
  add column if not exists service_count               integer not null default 0,
  add column if not exists customer_count              integer not null default 0,
  add column if not exists job_applications_this_month integer not null default 0,
  add column if not exists completed_jobs_count        integer not null default 0,
  add column if not exists photo_upload_count          integer not null default 0,
  add column if not exists video_upload_count          integer not null default 0,
  add column if not exists staff_count                 integer not null default 0,
  add column if not exists freelance_hires_this_month  integer not null default 0,
  add column if not exists branch_count                integer not null default 0,
  add column if not exists projects_this_month         integer not null default 0,
  add column if not exists reset_at                    timestamptz;

-- Accept every counter the app uses, and stop auto-zeroing monthly.
create or replace function public.bump_usage("p_field" text, "p_amount" integer default 1)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'bump_usage: not authenticated';
  end if;
  if p_field !~ '^[a-z_]+$' then
    raise exception 'bump_usage: invalid field %', p_field;
  end if;
  if p_field not in (
    'voice_seconds_used', 'suggestions_used', 'leads_viewed',
    'address_count', 'job_count', 'invoice_count', 'quotation_count',
    'template_count', 'service_count', 'customer_count',
    'job_applications_this_month', 'completed_jobs_count',
    'photo_upload_count', 'video_upload_count', 'staff_count',
    'freelance_hires_this_month', 'branch_count', 'projects_this_month'
  ) then
    raise exception 'bump_usage: unknown field %', p_field;
  end if;

  insert into public.usage_counters (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  -- Counters are reset by reset_usage() on subscription change, never on a
  -- calendar boundary — this mirrors the RTDB behaviour being replaced.
  execute format(
    'update public.usage_counters set %I = greatest(%I + $1, 0) where owner_id = $2',
    p_field, p_field
  ) using p_amount, v_uid;
end
$$;

-- Explicit reset, mirroring usage_repository.resetUsage().
create or replace function public.reset_usage()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'reset_usage: not authenticated';
  end if;

  insert into public.usage_counters (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  update public.usage_counters
     set address_count               = 0,
         job_count                   = 0,
         invoice_count               = 0,
         quotation_count             = 0,
         template_count              = 0,
         service_count               = 0,
         customer_count              = 0,
         job_applications_this_month = 0,
         completed_jobs_count        = 0,
         photo_upload_count          = 0,
         video_upload_count          = 0,
         staff_count                 = 0,
         freelance_hires_this_month  = 0,
         branch_count                = 0,
         projects_this_month         = 0,
         voice_seconds_used          = 0,
         suggestions_used            = 0,
         leads_viewed                = 0,
         period_start                = date_trunc('month', now())::date,
         reset_at                    = now()
   where owner_id = v_uid;
end
$$;

grant execute on function public.reset_usage() to authenticated;
