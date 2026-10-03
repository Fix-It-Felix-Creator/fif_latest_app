-- Phase 9 — what the staff admin panel needs that the schema does not have.
--
-- Three things, in order of how much they matter:
--
--   1. admin_audit_log. The panel writes columns no client can write —
--      verification_status, account_status, the deletion timestamps — and a
--      tool that can disable someone's account without leaving a trace is not
--      one a founder can hand to a support hire. Specced in
--      docs/admin-panel-dashboard-spec.md §5.9; nothing implemented it.
--
--   2. Five roles instead of two. §4.2 of the same spec: a verification
--      reviewer and a read-only analyst are both narrower than today's
--      `admin`, and there is no way to express either. Purely additive — the
--      two existing values keep their exact meaning and existing rows are
--      untouched.
--
--   3. admin_dashboard_stats(). Counts the panel can get from PostgREST
--      head requests; sums it cannot. Without this the dashboard would either
--      scan every invoice on each page view or quietly not show money at all.
--
-- All three are service-role only. Nothing here is readable by the apps.

-- ============================================================
-- 1. admin_roles — the five roles, and who granted them
-- ============================================================

-- Dropped and re-added rather than altered: a CHECK constraint cannot be
-- widened in place, and naming it explicitly means a re-run finds it.
alter table public.admin_roles
  drop constraint if exists admin_roles_role_check;

alter table public.admin_roles
  add constraint admin_roles_role_check
  check (role in ('superAdmin', 'admin', 'support', 'verifier', 'analyst'));

alter table public.admin_roles
  -- Shown beside an action in the audit log. An email is an identity; a name
  -- is what the person reviewing the log a year later actually recognises.
  add column if not exists display_name text,
  add column if not exists created_by    uuid references auth.users (id) on delete set null,
  add column if not exists updated_at    timestamptz not null default now(),
  -- Stamped by the panel on each page load. The question it answers is "is
  -- this roster row still someone who works here", which no other column can.
  add column if not exists last_seen_at  timestamptz;

comment on column public.admin_roles.role is
  'superAdmin | admin | support | verifier | analyst. The api edge function''s '
  'isAdmin() accepts the first three; the panel''s own matrix (lib/roles.ts) '
  'splits them further.';

-- ============================================================
-- 2. admin_audit_log
-- ============================================================

create table if not exists public.admin_audit_log (
  id          uuid primary key default gen_random_uuid(),
  -- NOT a foreign key, and deliberately so. The row has to outlive the thing
  -- it describes: "who deleted this account" is the one entry that matters
  -- most, and a cascade from auth.users would erase exactly that one.
  actor_id    uuid not null,
  actor_email text,
  action      text not null,
  entity      text not null,
  entity_id   text,
  env         text not null default 'staging' check (env in ('staging', 'production')),
  -- Before and after, or whatever else the action needs to be reconstructible.
  diff        jsonb,
  created_at  timestamptz not null default now()
);

alter table public.admin_audit_log enable row level security;
-- No policies: service role only. RLS with zero policies denies everyone else,
-- which is the same shape admin_roles already uses and for the same reason —
-- a user must not be able to read what staff did to other users' accounts.

create index if not exists idx_admin_audit_log_created
  on public.admin_audit_log (created_at desc);
create index if not exists idx_admin_audit_log_entity
  on public.admin_audit_log (entity, entity_id, created_at desc);
create index if not exists idx_admin_audit_log_actor
  on public.admin_audit_log (actor_id, created_at desc);

comment on table public.admin_audit_log is
  'Every mutating action taken from the staff admin panel. Service-role only.';

-- ============================================================
-- 3. admin_dashboard_stats()
-- ============================================================

/**
 * The dashboard's aggregates, in one round trip.
 *
 * Only the things a PostgREST `head: true` count cannot answer: sums, and
 * grouped breakdowns that would otherwise be one request per combination.
 * Plain counts stay in the panel as head requests, so the dashboard still
 * renders — minus the money — if this function has not been deployed yet.
 *
 * security definer with a pinned search_path, and execute revoked from every
 * client role. Only the service role calls it, and only after the panel has
 * resolved the caller's admin role from their own session.
 */
create or replace function public.admin_dashboard_stats()
returns jsonb
language sql
security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
    'generated_at', now(),

    'invoices', coalesce((
      select jsonb_object_agg(status, jsonb_build_object('count', c, 'total', t))
        from (select status, count(*) c, coalesce(sum(total), 0) t
                from public.invoices group by status) s
    ), '{}'::jsonb),

    'quotes', coalesce((
      select jsonb_object_agg(status, jsonb_build_object('count', c, 'total', t))
        from (select status, count(*) c, coalesce(sum(total), 0) t
                from public.quotes group by status) s
    ), '{}'::jsonb),

    'jobs', coalesce((
      select jsonb_object_agg(status, c)
        from (select status, count(*) c from public.jobs group by status) s
    ), '{}'::jsonb),

    -- A list rather than a nested object: the breakdown is four-dimensional
    -- (status x plan x provider x cycle) and the panel wants to sort it.
    'subscriptions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'status', status, 'plan_type', plan_type,
               'provider', provider, 'billing_cycle', billing_cycle,
               'count', c, 'price', p))
        from (select status, plan_type, provider, billing_cycle,
                     count(*) c, coalesce(sum(price), 0) p
                from public.subscriptions
               group by status, plan_type, provider, billing_cycle) s
    ), '[]'::jsonb),

    -- Subscriptions the store says are live but whose period ended. Spec §5.5
    -- calls these out by name: they are webhook lag or a failed renewal, and
    -- they are invisible in every per-user view.
    'stale_subscriptions', (
      select count(*) from public.subscriptions
       where status = 'active' and current_period_end < now()
    ),

    'shares', jsonb_build_object(
      'created',   (select count(*) from public.document_shares where deleted_at is null),
      'viewed',    (select count(*) from public.document_shares where viewed_at is not null and deleted_at is null),
      'responded', (select count(*) from public.document_shares where responded_at is not null and deleted_at is null),
      'accepted',  (select count(*) from public.document_shares where responded_action = 'accepted'),
      'rejected',  (select count(*) from public.document_shares where responded_action = 'rejected')
    ),

    'work_30d', jsonb_build_object(
      'jobs',     (select count(*) from public.jobs     where created_at >= now() - interval '30 days'),
      'quotes',   (select count(*) from public.quotes   where created_at >= now() - interval '30 days'),
      'invoices', (select count(*) from public.invoices where created_at >= now() - interval '30 days'),
      'invoiced', (select coalesce(sum(total), 0) from public.invoices where created_at >= now() - interval '30 days')
    ),

    'expenses_total',  (select coalesce(sum(amount), 0) from public.job_expenses),
    'tracked_seconds', (select coalesce(sum(duration_seconds), 0) from public.job_time_entries)
  );
$$;

revoke execute on function public.admin_dashboard_stats() from public, anon, authenticated;

comment on function public.admin_dashboard_stats() is
  'Aggregates for the staff admin panel dashboard. Service role only.';
