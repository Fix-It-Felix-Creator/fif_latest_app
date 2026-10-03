-- Subscription plans as data, editable by a super admin, read by both apps.
--
-- Until now a plan lived in three places that disagreed: the Pro paywall
-- hardcoded £12.99/£129.99 and four feature strings, `app_config` said
-- £9.99/£99.99 with no features at all, and the launch campaign said
-- £12.99/£100. Nobody could change the price without a release, and the price
-- they would have changed was one of three.
--
-- So plans become rows. The table is the source of truth; a trigger republishes
-- `app_config.subscriptions` in exactly the shape SubscriptionPlanConfigModel
-- already parses, so the apps keep their existing read path and gain the
-- fields they were missing.

-- ============================================================
-- 1. `pro` becomes a real plan type
-- ============================================================
--
-- The campaign's middle tier is Pro. The enum and this constraint called it
-- `plus`, which no marketing material has ever said out loud. Added rather than
-- renamed: `plus` stays accepted so any historical row keeps validating, and
-- the seed below moves the config keys over.

alter table public.subscriptions
  drop constraint if exists subscriptions_plan_type_check;

alter table public.subscriptions
  add constraint subscriptions_plan_type_check
  check (plan_type in ('standard', 'pro', 'plus', 'advance', 'vip'));

-- ============================================================
-- 2. The table
-- ============================================================

create table if not exists public.subscription_plans (
  -- 'tradesman_standard'. Matches the key the apps already look plans up by
  -- (`${accountType}_${planType}`), so the published document needs no
  -- translation layer.
  id                  text primary key,
  account_type        text not null check (account_type in ('tradesman', 'business', 'customer')),
  plan_type           text not null check (plan_type in ('standard', 'pro', 'plus', 'advance', 'vip')),

  -- What a person reads on the card.
  name                text not null,
  tagline             text,
  description         text not null default '',
  features            text[] not null default '{}',

  -- Display prices. These do NOT charge anybody: billing is native in-app
  -- purchase and the store owns the real price. They are the number on the
  -- card, and they have to be kept in step with App Store Connect by hand —
  -- which is exactly why they need to be editable without a release.
  currency            text not null default 'GBP',
  monthly_price       numeric(10,2) not null default 0,
  yearly_price        numeric(10,2) not null default 0,

  -- How the card presents itself.
  availability        text not null default 'live'
                        check (availability in ('live', 'coming_soon', 'hidden')),
  badge               text,
  is_featured         boolean not null default false,
  is_active           boolean not null default true,
  sort_order          integer not null default 0,

  trial_days          integer not null default 0,
  transaction_fee     numeric(5,2),

  -- Enforcement, as the app's existing limit models shape it. jsonb rather
  -- than columns because the three account types have three different sets and
  -- a column per key across all three would be mostly nulls.
  limits              jsonb not null default '{}'::jsonb,
  tradesman_limits    jsonb,
  business_limits     jsonb,
  customer_limits     jsonb,

  has_tools           boolean not null default false,
  tools_monthly_price numeric(10,2),
  tools_yearly_price  numeric(10,2),

  -- Store identifiers. The IAP ids are what actually charge; the Stripe ones
  -- are left over from before the move to in-app purchase.
  product_id_monthly       text,
  product_id_yearly        text,
  stripe_price_id_monthly  text,
  stripe_price_id_yearly   text,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  -- One plan per tier per app. Without this a second 'tradesman_pro' under a
  -- different id would publish over the first at random.
  unique (account_type, plan_type)
);

alter table public.subscription_plans enable row level security;

-- Readable by everyone, writable only by the service role — the same shape as
-- app_config, and for the same reason: the apps read it before anyone signs in.
drop policy if exists "anyone reads subscription_plans" on public.subscription_plans;
create policy "anyone reads subscription_plans"
  on public.subscription_plans for select
  using (true);

create index if not exists idx_subscription_plans_account
  on public.subscription_plans (account_type, sort_order);

create or replace trigger subscription_plans_touch_updated_at
  before update on public.subscription_plans
  for each row execute function public.touch_updated_at();

comment on table public.subscription_plans is
  'Source of truth for plan cards in both apps. Edited by super admins; '
  'published to app_config.subscriptions by publish_subscription_plans().';
comment on column public.subscription_plans.monthly_price is
  'Display only. The store owns the real price — keep in step with App Store '
  'Connect and Play Console by hand.';

-- ============================================================
-- 3. Publishing to app_config
-- ============================================================

/**
 * Rebuilds app_config.subscriptions from the table.
 *
 * The apps already read that key and parse it with
 * SubscriptionPlanConfigModel.fromJson, which expects
 * `{ accountType: { planId: {...camelCase plan...} } }`. Emitting exactly that
 * shape is what lets the whole feature ship without touching either app's
 * config loader — the editor changes a row, the trigger rewrites the document,
 * and the next app launch reads it.
 *
 * Keys the Dart model does not know (tagline, badge, availability, isFeatured,
 * productId*) are emitted anyway: fromJson reads the keys it recognises and
 * ignores the rest, so a newer app can use them while an older build carries
 * on working. That is the whole reason this is additive rather than a second
 * config key.
 *
 * Inactive plans are published too, carrying isActive:false. A plan that
 * vanishes from the document looks identical to a config that failed to load,
 * and an app that has cached the old document would keep showing a plan that
 * was withdrawn.
 */
create or replace function public.publish_subscription_plans()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_doc jsonb;
begin
  select coalesce(jsonb_object_agg(account_type, plans), '{}'::jsonb)
    into v_doc
    from (
      select account_type,
             jsonb_object_agg(id, jsonb_strip_nulls(jsonb_build_object(
               'id',                  id,
               'name',                name,
               'tagline',             tagline,
               'description',         description,
               'accountType',         account_type,
               'planType',            plan_type,
               'currency',            currency,
               'monthlyPrice',        monthly_price,
               'yearlyPrice',         yearly_price,
               'availability',        availability,
               'badge',               badge,
               'isFeatured',          is_featured,
               'isActive',            is_active,
               'sortOrder',           sort_order,
               'trialDays',           trial_days,
               'transactionFee',      transaction_fee,
               -- to_jsonb on the array, not array_to_json: the Dart side does
               -- List<String>.from(...) and needs a real JSON array.
               'features',            to_jsonb(features),
               'limits',              limits,
               'tradesmanLimits',     tradesman_limits,
               'businessLimits',      business_limits,
               'customerLimits',      customer_limits,
               'hasTools',            has_tools,
               'toolsMonthlyPrice',   tools_monthly_price,
               'toolsYearlyPrice',    tools_yearly_price,
               'productIdMonthly',    product_id_monthly,
               'productIdYearly',     product_id_yearly,
               'stripePriceIdMonthly', stripe_price_id_monthly,
               'stripePriceIdYearly',  stripe_price_id_yearly,
               'createdAt',           to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
               'updatedAt',           to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
             ))) as plans
        from public.subscription_plans
       group by account_type
    ) grouped;

  insert into public.app_config (key, value, description)
  values ('subscriptions', v_doc,
          'Generated from public.subscription_plans. Edit the table, not this row.')
  on conflict (key) do update
    set value       = excluded.value,
        description = excluded.description,
        updated_at  = now();
end
$$;

revoke execute on function public.publish_subscription_plans() from public, anon, authenticated;

create or replace function public.subscription_plans_publish_trigger()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform public.publish_subscription_plans();
  return null;
end
$$;

-- AFTER and FOR EACH STATEMENT: the function rebuilds the whole document from
-- the table, so running it once per statement is both correct and enough —
-- per-row would rebuild it N times for one edit.
drop trigger if exists subscription_plans_publish on public.subscription_plans;
create trigger subscription_plans_publish
  after insert or update or delete on public.subscription_plans
  for each statement execute function public.subscription_plans_publish_trigger();

-- ============================================================
-- 4. The six plans, from the Premium Launch Campaign
-- ============================================================
--
-- Prices here are the campaign's, which is the number customers have been
-- shown. Where the old config disagreed it was wrong: tradesman Standard was
-- £9.99/£99.99 in app_config and £12.99/£129.99 hardcoded in the paywall,
-- against £12.99/£100 in the campaign.
--
-- -1 means unlimited, matching every existing limit model.
--
-- Invoicing, quoting, contracts and scheduling are unlimited on every
-- CUSTOMER tier, including the free one — the campaign's own footnote says
-- they are included on every package, and the Standard card lists them.
-- Zero there would have contradicted the bullet printed above it.
--
-- Idempotent: re-running restores the campaign values over any hand-edit,
-- which is what you want from a seed and why editing happens in the panel.

insert into public.subscription_plans (
  id, account_type, plan_type, name, tagline, description, features,
  monthly_price, yearly_price, availability, badge, is_featured, sort_order,
  trial_days, transaction_fee, limits, tradesman_limits, customer_limits,
  product_id_monthly, product_id_yearly
) values

-- ─────────────────────────── FIX IT FELIX PRO — tradesmen ───────────────────
(
  'tradesman_standard', 'tradesman', 'standard', 'Standard',
  'Start your 30-Day Standard Package Trial today',
  'Built for professionals who want to manage their business, not just their paperwork.',
  array[
    'Invoicing, quoting & scheduling',
    'Reviews & tradesmen calculators',
    'AI estimator & AI quote generator',
    '1 business location & service area',
    'Up to 2 staff members',
    'No transaction charges'
  ],
  12.99, 100.00, 'live', 'LIVE — 30-DAY FREE TRIAL', true, 1,
  30, 0,
  '{"maxJobs":-1,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1,"maxAddresses":1}'::jsonb,
  '{"maxPhotoUploads":10,"maxVideoUploads":3,"maxFileUploads":3,"maxStaffMembers":2,"maxAdminStaff":1,"maxServiceAreas":1,"maxBranches":1,"serviceRadiusMiles":0,"maxVisibleLeadsPerMonth":0}'::jsonb,
  null,
  -- The only tier that charges today. Must match App Store Connect and Play.
  'fixitfelixpro.standard.monthly', 'fixitfelixpro.standard.yearly'
),
(
  'tradesman_pro', 'tradesman', 'pro', 'Pro',
  null,
  'Everything in Standard, plus CRM, live leads and wider visibility.',
  array[
    'Everything in Standard, plus:',
    'CRM & live leads',
    'Visibility up to 100 miles',
    'AR measurement tools',
    'Hiring through platform',
    '10% transaction charge'
  ],
  30.00, 300.00, 'coming_soon', 'COMING SOON', false, 2,
  0, 10,
  '{"maxJobs":-1,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1,"maxAddresses":2}'::jsonb,
  '{"maxPhotoUploads":50,"maxVideoUploads":9,"maxFileUploads":9,"maxStaffMembers":5,"maxAdminStaff":2,"maxServiceAreas":2,"maxBranches":2,"serviceRadiusMiles":100,"maxVisibleLeadsPerMonth":-1}'::jsonb,
  null, null, null
),
(
  'tradesman_advance', 'tradesman', 'advance', 'Advance',
  null,
  'Everything in Pro, plus UK-wide leads and room to grow.',
  array[
    'Everything in Pro, plus:',
    'Unlimited live leads · UK-wide',
    '5+ locations & 10+ staff',
    'Folders & completed projects',
    'Priority growth features',
    'Only 5% transaction charge'
  ],
  60.00, 650.00, 'coming_soon', 'COMING SOON', false, 3,
  0, 5,
  '{"maxJobs":-1,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1,"maxAddresses":-1}'::jsonb,
  '{"maxPhotoUploads":-1,"maxVideoUploads":-1,"maxFileUploads":-1,"maxStaffMembers":-1,"maxAdminStaff":5,"maxServiceAreas":-1,"maxBranches":-1,"serviceRadiusMiles":-1,"maxVisibleLeadsPerMonth":-1}'::jsonb,
  null, null, null
),

-- ─────────────────────────── FIX IT FELIX — homeowners ──────────────────────
(
  'customer_standard', 'customer', 'standard', 'Standard',
  'Get started at no cost',
  'Helping homeowners connect with verified tradespeople, compare quotes and book with confidence.',
  array[
    '10 photos · 3 videos · 3 files',
    '1 property location',
    '2 job posts per month',
    'Felix AI — up to 2 jobs',
    'Live leads: 5-mile radius',
    'Invoicing, quoting & scheduling'
  ],
  0, 0, 'live', null, false, 1,
  0, null,
  '{"maxJobs":2,"maxAddresses":1,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1}'::jsonb,
  null,
  '{"maxPhotoUploads":10,"maxVideoUploads":3,"maxFileUploads":3,"maxProperties":1,"maxJobPostsPerMonth":2,"maxFelixAiJobs":2,"maxScheduledTradesmenPerJob":2,"maxMessagesPerMonth":2,"serviceRadiusMiles":5,"hasCrm":false,"hasArTools":false}'::jsonb,
  null, null
),
(
  'customer_pro', 'customer', 'pro', 'Pro',
  null,
  'More properties, more jobs, and the CRM to keep track of them.',
  array[
    '50 photos · 9 videos · 9 files',
    'Up to 5 properties',
    '10 job posts per month',
    'Felix AI — up to 10 jobs',
    'Live leads: 100-mile radius',
    'CRM & job tracking'
  ],
  30.00, 300.00, 'live', 'MOST POPULAR', true, 2,
  0, null,
  '{"maxJobs":10,"maxAddresses":5,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1}'::jsonb,
  null,
  '{"maxPhotoUploads":50,"maxVideoUploads":9,"maxFileUploads":9,"maxProperties":5,"maxJobPostsPerMonth":10,"maxFelixAiJobs":10,"maxScheduledTradesmenPerJob":5,"maxMessagesPerMonth":10,"serviceRadiusMiles":100,"hasCrm":true,"hasArTools":false}'::jsonb,
  null, null
),
(
  'customer_advance', 'customer', 'advance', 'Advance',
  null,
  'Unlimited everything, nationwide leads and AR measurement.',
  array[
    'Unlimited uploads',
    '10+ properties',
    'Unlimited job posting',
    'Felix AI — unlimited',
    'Live leads: nationwide',
    'AR measurement tools'
  ],
  60.00, 600.00, 'live', null, false, 3,
  0, null,
  '{"maxJobs":-1,"maxAddresses":-1,"maxQuotations":-1,"maxInvoices":-1,"maxCustomers":-1,"maxServices":-1,"maxTemplates":-1}'::jsonb,
  null,
  '{"maxPhotoUploads":-1,"maxVideoUploads":-1,"maxFileUploads":-1,"maxProperties":10,"maxJobPostsPerMonth":-1,"maxFelixAiJobs":-1,"maxScheduledTradesmenPerJob":10,"maxMessagesPerMonth":-1,"serviceRadiusMiles":-1,"hasCrm":true,"hasArTools":true}'::jsonb,
  null, null
)

on conflict (id) do update set
  account_type     = excluded.account_type,
  plan_type        = excluded.plan_type,
  name             = excluded.name,
  tagline          = excluded.tagline,
  description      = excluded.description,
  features         = excluded.features,
  monthly_price    = excluded.monthly_price,
  yearly_price     = excluded.yearly_price,
  availability     = excluded.availability,
  badge            = excluded.badge,
  is_featured      = excluded.is_featured,
  sort_order       = excluded.sort_order,
  trial_days       = excluded.trial_days,
  transaction_fee  = excluded.transaction_fee,
  limits           = excluded.limits,
  tradesman_limits = excluded.tradesman_limits,
  customer_limits  = excluded.customer_limits,
  updated_at       = now();

-- The old `*_plus` keys are what the campaign now calls Pro, and they only
-- ever existed inside the generated document. Nothing references them.
delete from public.subscription_plans where plan_type = 'plus';

-- Publish once explicitly. The statement trigger above has already fired, but
-- being explicit means a hand-run of this file leaves app_config correct even
-- if the trigger were ever dropped.
select public.publish_subscription_plans();
