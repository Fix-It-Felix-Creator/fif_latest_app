-- Phase 5 — reverse lookup for Google Play purchases.
--
-- Store webhooks arrive unauthenticated, carrying only a store identifier, so
-- the server must be able to find the owning account from that identifier
-- alone. RTDB kept two index nodes for this:
--   iap/appleOriginalTxnToUid/{originalTransactionId} -> uid
--   iap/googleTokenToUid/{sha256(purchaseToken)}      -> uid
--
-- Apple's case is already covered: `subscriptions.original_transaction_id`
-- exists and is indexed. Google's had no column, so a Play RTDN could not be
-- attributed to a user at all.
--
-- The token is stored HASHED, as the RTDB key was: a purchase token is a
-- bearer credential for the subscription, and it does not need to be readable
-- to be matched.

alter table public.subscriptions
  add column if not exists google_purchase_token_hash text;

create unique index if not exists uq_subscriptions_google_token
  on public.subscriptions (google_purchase_token_hash)
  where google_purchase_token_hash is not null;

comment on column public.subscriptions.google_purchase_token_hash is
  'sha256 of the Play purchase token. Lets an unauthenticated RTDN webhook find the owning account.';
