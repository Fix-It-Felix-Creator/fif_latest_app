-- Services: the trades a customer can ask for, and the questions they answer.
--
-- Two things live here, and they are different in kind:
--
--   1. The service itself — name, blurb, artwork, which group it sits in.
--      Catalogue data, shown as a tile.
--   2. Its FLOW — the nested questions a customer walks to describe the job
--      ("What plumbing help do you need?" → Heating & Hot Water → Install new
--      boiler → Combi boiler). That tree is the data-input process, and it is
--      what turns "I need a plumber" into something a tradesperson can quote.
--
-- Both are editable by a super admin, because the flow is copy: the wording of
-- a question, the order of the options, whether a branch needs a free-text
-- description. None of that should need a release.
--
-- Imported from the old mobile app's assets/documents/services — 37 flow
-- files, 277 categories, 2,113 options.

-- ============================================================
-- 1. Groups
-- ============================================================
--
-- The headings a customer scrolls past. Their own table rather than a text
-- column so renaming "Heating & Gas" is one row, not an update across every
-- service that mentions it.

create table if not exists public.service_groups (
  id         text primary key,
  name       text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.service_groups enable row level security;

drop policy if exists "anyone reads service_groups" on public.service_groups;
create policy "anyone reads service_groups"
  on public.service_groups for select using (true);

create or replace trigger service_groups_touch_updated_at
  before update on public.service_groups
  for each row execute function public.touch_updated_at();

insert into public.service_groups (id, name, sort_order) values
  ('home_services',         'Home Services',          1),
  ('building_construction', 'Building & Construction', 2),
  ('outdoor_garden',        'Outdoor & Garden',        3),
  ('heating_gas',           'Heating & Gas',           4),
  ('kitchen_bathroom',      'Kitchen & Bathroom',      5),
  ('security',              'Security',                6),
  ('automotive',            'Automotive',              7),
  ('cleaning',              'Cleaning',                8),
  ('personal_care',         'Personal Care',           9)
on conflict (id) do update
  set name = excluded.name, sort_order = excluded.sort_order, updated_at = now();

-- ============================================================
-- 2. Services
-- ============================================================

create table if not exists public.services (
  -- 'plumber'. The id the old flow files already use, so an import needs no
  -- mapping table and a saved job's service reference stays readable.
  id            text primary key,
  name          text not null,
  subtitle      text,
  description   text not null default '',

  -- Presentation. Nullable on purpose: eleven of the imported flows have no
  -- index entry and therefore no icon, colour or group. Blank is the honest
  -- value, and the panel flags it rather than inventing one.
  icon          text,
  color         text,
  group_id      text references public.service_groups (id) on delete set null,

  is_popular    boolean not null default false,
  has_emergency boolean not null default false,
  is_active     boolean not null default true,
  sort_order    integer not null default 0,

  -- Artwork. `thumbnail_path` is the object in the `service-thumbnails`
  -- bucket when the image was uploaded here; `thumbnail_url` is what anything
  -- displaying it should read, and may point at the bucket or at an external
  -- URL a super admin pasted. Keeping both means a replaced upload can delete
  -- the object it replaced instead of orphaning it.
  thumbnail_url  text,
  thumbnail_path text,

  -- ---- the data-input process -------------------------------------------
  --
  -- flow_title is the question at the top ("What plumbing help do you
  -- need?"); categories is the tree beneath it. Held as jsonb rather than
  -- three more tables because it is read whole, written whole, and nests
  -- three deep — a relational shape would need a recursive query to answer
  -- the only question anyone asks of it, which is "give me the whole tree".
  flow_title    text not null default '',
  flow_subtitle text,
  categories    jsonb not null default '[]'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint services_categories_is_array check (jsonb_typeof(categories) = 'array')
);

alter table public.services enable row level security;

-- Readable by everyone, same as app_config: both apps show the catalogue
-- before anyone signs in, and a service tile is not private data.
drop policy if exists "anyone reads services" on public.services;
create policy "anyone reads services"
  on public.services for select using (true);

create index if not exists idx_services_group on public.services (group_id, sort_order);
create index if not exists idx_services_active on public.services (is_active);

create or replace trigger services_touch_updated_at
  before update on public.services
  for each row execute function public.touch_updated_at();

comment on table public.services is
  'Trades a customer can request, with the nested question flow that describes '
  'the job. Edited by super admins in the admin panel; read by both apps.';
comment on column public.services.categories is
  'The question tree. Array of categories, each with options nesting up to '
  'three levels. Shape matches the old app''s assets/documents/services JSON.';

-- ============================================================
-- 3. Thumbnail storage
-- ============================================================
--
-- Public read, unlike every other bucket in this project. Service artwork is
-- catalogue imagery shown before sign-in and identical for every viewer;
-- signing each URL would add a round trip per tile and buy nothing.

insert into storage.buckets (id, name, public)
values ('service-thumbnails', 'service-thumbnails', true)
on conflict (id) do update set public = true;

drop policy if exists "anyone reads service thumbnails" on storage.objects;
create policy "anyone reads service thumbnails"
  on storage.objects for select
  using (bucket_id = 'service-thumbnails');

-- Writes are service-role only — the admin panel uploads through a server
-- action after checking the caller's role. No client policy, so no signed-in
-- user can put an object here.
