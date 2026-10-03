-- Phase 3 — fields TradeQualificationDoc carries that the table lacked.
--
-- Phase 1 modelled trade_qualifications from the generic "document" shape.
-- The actual model (models/trade_requirement.dart) is a *requirement*
-- fulfilment: it points at the trade requirement it satisfies, records whether
-- that requirement is mandatory, and keeps a moderation audit trail.
--
-- requirement_id is the key the app looks documents up by, so without it the
-- qualification screens cannot match a document to its requirement at all.

alter table public.trade_qualifications
  add column if not exists requirement_id text,
  add column if not exists is_mandatory   boolean not null default true,
  add column if not exists uploaded_at    timestamptz not null default now(),
  add column if not exists verified_at    timestamptz,
  add column if not exists verified_by    text;

-- One document per requirement per user, matching the RTDB layout where the
-- requirement id WAS the child key.
create unique index if not exists uq_trade_qualifications_owner_requirement
  on public.trade_qualifications (owner_id, requirement_id)
  where requirement_id is not null;

comment on column public.trade_qualifications.requirement_id is
  'Trade requirement this document satisfies. Was the RTDB child key.';
comment on column public.trade_qualifications.verified_by is
  'Moderator who reviewed this document. Server-set.';
