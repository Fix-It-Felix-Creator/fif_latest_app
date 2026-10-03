-- Phase 5 — admin roles, and rate limiting for the public share routes.
--
-- 1. admin_roles replaces RTDB `config/admin/systemRoles/{uid}`, which gated
--    the notifications broadcast endpoint. Deliberately NOT readable by
--    clients: a user must not be able to enumerate admins, and nothing in the
--    app needs to. Only the service role (Edge Functions) reads it.
--
-- 2. rate_limit_hits backs the abuse protection the public share endpoints
--    lost when App Check was removed. `/q/:token` and `/i/:token` are open by
--    design — there is no authenticated caller to scope them to — so without
--    this a leaked or guessed token can be hammered freely.

create table if not exists public.admin_roles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  role       text not null check (role in ('admin', 'superAdmin')),
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.admin_roles enable row level security;
-- No policies: service role only. RLS with zero policies denies everyone else.

comment on table public.admin_roles is
  'Service-role only. Clients must not be able to enumerate admins.';

-- ============================================================
-- Rate limiting
-- ============================================================
create table if not exists public.rate_limit_hits (
  bucket     text        not null,
  window_start timestamptz not null,
  hits       integer     not null default 0,
  primary key (bucket, window_start)
);

alter table public.rate_limit_hits enable row level security;
-- Service role only, same reasoning as admin_roles.

/**
 * Records a hit and reports whether the caller is over its limit.
 *
 * Fixed-window rather than sliding: a sliding window needs per-hit rows, and
 * for abuse protection on a public endpoint the extra precision is not worth
 * the write amplification. Worst case a caller gets 2x the limit across a
 * window boundary, which is fine for this purpose.
 */
create or replace function public.rate_limit_check(
  p_bucket        text,
  p_limit         integer,
  p_window_seconds integer default 60
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_window timestamptz := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );
  v_hits integer;
begin
  insert into public.rate_limit_hits (bucket, window_start, hits)
  values (p_bucket, v_window, 1)
  on conflict (bucket, window_start)
    do update set hits = public.rate_limit_hits.hits + 1
  returning hits into v_hits;

  -- Opportunistic cleanup: drop windows old enough that nothing can reference
  -- them, so the table cannot grow without bound. Cheap because it is indexed
  -- by the primary key and only fires on the first hit of a new window.
  if v_hits = 1 then
    delete from public.rate_limit_hits
     where window_start < now() - interval '1 hour';
  end if;

  return v_hits <= p_limit;
end
$$;

revoke execute on function public.rate_limit_check(text, integer, integer) from public, anon, authenticated;
