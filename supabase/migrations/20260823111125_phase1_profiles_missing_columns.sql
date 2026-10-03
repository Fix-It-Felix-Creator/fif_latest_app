-- Phase 1 follow-up — columns the app persists that `profiles` had no home for.
--
-- Found by diffing UserDetailsModel.toJson() (33 keys) against the profiles
-- table. Seven persisted fields had nowhere to go. Left unfixed these would
-- have failed at runtime in Phase 2/3, not at compile time.
--
-- These are KYC / verification fields. `verification_status` is already a
-- typed column with a CHECK constraint, so keeping its paired
-- `rejection_reason` in an untyped blob would have been inconsistent — and
-- DatabasePaths.userRejectionReason is read directly at 2 call sites.

alter table public.profiles
  -- BusinessRole enum (owner | admin | customerSupport). Distinct from
  -- account_type, which is AccountCategoryType — DatabasePaths exposes both
  -- `userRole` and the account type as separate paths.
  add column if not exists role text,

  -- Paired with the existing verification_status column.
  add column if not exists rejection_reason text,

  -- KYC identity document set.
  add column if not exists national_insurance_number text,
  add column if not exists document_type text,
  add column if not exists document_urls text[],
  add column if not exists selfie_url text,

  -- Plan chosen during onboarding, before a subscription row exists.
  add column if not exists subscription_plan_selected text;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role is null or role in ('owner', 'admin', 'customerSupport'));

alter table public.profiles
  drop constraint if exists profiles_document_type_check;

alter table public.profiles
  add constraint profiles_document_type_check
  check (document_type is null or document_type in ('passport', 'idCard', 'driverLicense'));

comment on column public.profiles.role is
  'BusinessRole enum. Distinct from account_type (AccountCategoryType).';
comment on column public.profiles.firebase_uid is
  'Firebase Auth uid this profile was migrated from. Null for natively-created users.';
