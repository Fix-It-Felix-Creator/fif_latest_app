-- Give the tradesman plans the two feature flags their cards already claim.
--
-- hasCrm and hasArTools were seeded in 20260914120000 onto the CUSTOMER plans
-- only, in customer_limits. The tradesman plans never got them, so every
-- tradesman plan read as "no CRM, no AR" no matter what the paywall card said
-- beside it — and anything gating on those flags would have locked the feature
-- for the people paying for it.
--
-- Values are the campaign comparison table: both features are the line between
-- Standard and the paid tiers.
--
--   Standard   CRM & live leads —        AR measurement & hiring tools —
--   Pro        CRM & live leads ✓        AR measurement & hiring tools ✓
--   Advance    CRM & live leads ✓ Unltd  AR measurement & hiring tools ✓
--
-- Merged into the existing jsonb with || rather than replacing it, so the
-- radius, staff and upload limits already in there survive.

update public.subscription_plans
set tradesman_limits = coalesce(tradesman_limits, '{}'::jsonb)
  || '{"hasCrm": false, "hasArTools": false}'::jsonb
where account_type = 'tradesman' and plan_type = 'standard';

update public.subscription_plans
set tradesman_limits = coalesce(tradesman_limits, '{}'::jsonb)
  || '{"hasCrm": true, "hasArTools": true}'::jsonb
where account_type = 'tradesman' and plan_type in ('pro', 'advance');

-- Business accounts run the same app and the same paywall, so they get the
-- same flags. A business on Pro that could not see leads because its row was
-- missing a key would be the same bug one account_type over.
update public.subscription_plans
set business_limits = coalesce(business_limits, '{}'::jsonb)
  || '{"hasCrm": false, "hasArTools": false}'::jsonb
where account_type = 'business' and plan_type = 'standard';

update public.subscription_plans
set business_limits = coalesce(business_limits, '{}'::jsonb)
  || '{"hasCrm": true, "hasArTools": true}'::jsonb
where account_type = 'business' and plan_type in ('pro', 'advance');
