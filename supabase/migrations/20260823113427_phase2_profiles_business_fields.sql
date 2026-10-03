-- Phase 2 — separate the top-level business fields from the companyDetails block.
--
-- UserDetailsModel carries BOTH `businessName` and `companyDetails.companyName`,
-- and likewise `businessEmail` / `companyDetails.companyEmail` and
-- `businessRegistrationId` / `companyDetails.companiesHouseNumber`. The schema
-- had only the company_* column of each pair.
--
-- They are genuinely different fields, not duplicates:
--   * businessName gates profile completion for business accounts
--     (authentication_repository.dart:576, auth_state.dart:49)
--   * companyDetails.companyName is the company block rendered in settings
--     and on quotes/invoices (settings_screen.dart:261)
--
-- Mapping both onto one column would mean editing company details silently
-- overwrites the business name — data loss with no error. One column per model
-- field keeps the round-trip exact.

alter table public.profiles
  add column if not exists business_name text,
  add column if not exists business_email text,
  add column if not exists business_registration_id text;

comment on column public.profiles.business_name is
  'UserDetailsModel.businessName — gates profile completion for business accounts. Distinct from company_name (companyDetails.companyName).';
comment on column public.profiles.business_email is
  'UserDetailsModel.businessEmail — distinct from company_email (companyDetails.companyEmail).';
comment on column public.profiles.business_registration_id is
  'UserDetailsModel.businessRegistrationId — distinct from companies_house_number (companyDetails.companiesHouseNumber).';
