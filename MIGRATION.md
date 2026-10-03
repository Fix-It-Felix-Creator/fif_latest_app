# Firebase → Supabase Migration

**App:** Fix It Felix Pro (Flutter)
**Rule:** UI and behaviour stay identical. Backend only.
**Supabase org:** FixItFelix (`pegtkckgqnfhnokhrknn`)

| Environment | Project | Ref | Region |
|---|---|---|---|
| Development | `fif-pro-development` | `mjteytegbjvemuxoimlq` | eu-west-2 |
| Production | `fif-pro-production` | `nhghuurzmwoirnjkpvaa` | eu-west-2 |

## Decisions

- **Projects:** dev + prod provisioned up front; migrations promoted dev → prod.
- **Passwords:** lazy migration bridge. An Edge Function verifies the old Firebase password once at first login, then sets the Supabase password. Users notice nothing.
- **Offline:** build a local sqlite/drift cache layer in Phase 3 to preserve today's offline behaviour.

## Packages

| Action | Packages |
|---|---|
| Remove | `firebase_auth`, `firebase_database`, `firebase_storage`, `firebase_remote_config`, `firebase_app_check` |
| Keep (notifications only) | `firebase_core`, `firebase_messaging` |
| Add | `supabase_flutter` |

`google_sign_in` and `sign_in_with_apple` stay — Supabase accepts their native ID tokens.

---

## Phase 0 — Provision & wire up

App still runs on Firebase. Supabase initialised alongside it. Nothing removed yet.

- [x] Create production project `fif-pro-production` in FixItFelix org
- [x] Store DB passwords in `.secrets/` (gitignored)
- [x] `supabase init` at repo root
- [x] Link CLI to dev project
- [x] ~~Confirm dev project is empty~~ → **it is not.** 29 tables, 105 RLS policies, 6 functions, 17 triggers already exist. Essentially no data. Baseline saved to `supabase/_baseline/dev_schema_existing.sql`
- [x] Add `supabase_flutter` to `pubspec.yaml`
- [x] Add Supabase URL + publishable key to both env files (`config/staging/.env` → dev, `config/production/.env` → prod)
- [x] Initialise Supabase client in `lib/main.dart` alongside Firebase
- [x] Health check from the app proves connectivity
- [x] Dashboard checked via Chrome extension — Email, Apple and Google providers **already enabled** on dev
- [x] Set Site URL (`fixitfelix://login-callback`) + 2 redirect URLs on **both** dev and prod
- [x] Added the `fixitfelix` intent-filter to `AndroidManifest.xml` (iOS already had the scheme)
- [x] Resend configured and **verified with a real send**; `FROM_EMAIL` = no-reply@fixitfelix.app
- [x] Supabase Auth SMTP configured on both projects (Resend relay, port 587)
- [ ] Confirm a reset email lands in an inbox — SMTP relays are invisible to Resend's API
- [x] `flutter analyze` clean (0 errors), and **`flutter build apk --debug` succeeds** — a real APK, proving the native Supabase plugin and the new intent-filter compile

## Phase 1 — Schema + RLS ✅

> **Rewritten by a Phase 0 discovery.** A schema already existed on dev — 29 tables, fully **normalised** (`invoice_lines`, `quote_labour_lines`, `job_time_entries`…), using `owner_id` rather than `user_id`. Phase 1 became *audit, close the gaps, and make it reproducible* rather than *design from scratch*.

**Decision: adopt the normalised schema as-is.** It is well built — proper FKs, generated columns, guard triggers, consistent RLS. The cost lands in Phase 3: what was one RTDB blob is now parent + child tables, so the Dart models need joins and multi-statement writes rather than a straight `fromJson`. That is the right trade for a database this app will live on for years.

### Audit result

- [x] Audited all 29 tables against the 47 `DatabasePaths` methods the app actually calls
- [x] Confirmed no data loss risk — both projects were effectively empty
- [x] Baselined the existing schema (`20260823105501_remote_schema.sql`) — history was empty, so prod could not be rebuilt from source before this
- [x] Removed a `DROP EXTENSION pg_net` diff artifact from the baseline (dev lacks pg_net; dropping it on prod fails and would break webhook features wanted in Phase 5/6)

### Gaps found and closed (`20260823105713_phase1_gap_tables.sql`)

Seven tables the live code reads or writes had no home, plus one table that was simply wrong:

- [x] `app_config` — replaces Remote Config **and** the RTDB `config/` node (`imageLimits`, `commissionRates`, `subscriptions`, `videoLimits`). Public read, service-role write
- [x] `user_devices` — RTDB `devices/$uid/$deviceId`; 17 fields, 9 call sites, backs an 875-line repository
- [x] `user_sessions` — RTDB `sessions/$uid/$sessionId` + history, unified via `status`; 11 call sites
- [x] `portfolio_media` — RTDB portfolio `images` / `videos` / `job_videos` / `highlights`, unified via `kind`; 22 call sites
- [x] `trade_cards` — RTDB `users/$uid/tradeCard`
- [x] `trade_qualifications` — RTDB `users/$uid/tradeQualifications`
- [x] `extra_documents` — RTDB `users/$uid/extraDocuments`
- [x] `profiles.firebase_uid` (unique, partial index) — the Phase 8 uid → UUID mapping
- [x] **`usage_counters` corrected** — the app tracks **17** counters; the table had 3, only 2 of which matched, and `bump_usage()` raised an exception on anything else. Added the 15 missing counters, widened the whitelist, and added `reset_usage()`
- [x] **Fixed a reset-semantics bug** — `bump_usage()` auto-zeroed counters on a calendar month boundary. The app resets only on *subscription change* (`resetUsage()` is called solely from `updateSubscription`). Left as-is, counters like `customerCount` and `staffCount` would have silently zeroed every month. Monthly auto-reset removed

### Verified, not assumed

- [x] RLS genuinely enforcing — anonymous `INSERT` rejected with `42501` on both a user table and `app_config`
- [x] `app_config` public-read proven with a real row (service-role insert → anonymous read → cleaned up)
- [x] Migrations applied to dev, then promoted to prod
- [x] **Schema parity confirmed: 38 tables on each, identical** (via the PostgREST spec, service key)
- [x] CLI relinked to dev so nothing lands on prod by accident

### Follow-up: column-level audit of the high-traffic tables

Diffed the Dart models against the tables rather than trusting the schema.

- [x] `customers`, `staff`, `pricing_items`, `todos` — **exact matches**, no changes needed
- [x] `quotes`, `invoices`, `jobs` — match once child tables are accounted for (`*_lines`, `*_labour_lines`, `*_terms`, `*_attachments`, `job_time_entries`, `job_expenses`, `job_links`)
- [x] `profiles` — **7 persisted fields had no column** (`20260823111125_phase1_profiles_missing_columns.sql`):
  `role` (BusinessRole — genuinely distinct from `account_type`/AccountCategoryType), `rejection_reason`
  (pairs with the already-typed `verification_status`), `national_insurance_number`, `document_type`,
  `document_urls`, `selfie_url`, `subscription_plan_selected`. Added with CHECK constraints matching the Dart enums
- [x] Seeded `app_config` with all 10 Remote Config keys from `remote_config_backup_2026-05-14_v13.json`
      (`20260823111235_phase1_seed_app_config.sql`) — verified readable anonymously
- [x] All follow-up migrations promoted to prod

## Phase 2 — Auth *(in progress)*

### Foundation — done

- [x] `AppUser` model (`lib/models/app_user.dart`) — app-owned auth type replacing Firebase's `User`
- [x] `BaseAuthenticationRepository` rewritten — **zero Firebase references**; `User`/`UserCredential` gone,
      and the actions that hung off Firebase's `User` (`reload`, `sendEmailVerification`, `updateDisplayName`,
      `delete`, `getIdToken`) are now repository methods, which is where Supabase exposes them
- [x] `ProfileMapper` (`profile_mapper.dart`) — translates the flat snake_case `profiles` row to and from the
      nested camelCase JSON the models already speak. **This is what keeps the models untouched:**
      `UserDetailsModel`, `AddressModel`, `LocationModel`, `CompanyDetailsModel` and
      `NotificationPreferencesModel` need no changes, so neither do the screens reading them
- [x] **6 passing unit tests** covering full round-trip, field collision, partial update, empty profile,
      and the server-owned-column guard
- [x] `business_name` / `business_email` / `business_registration_id` columns added
- [x] `handle_new_user` trigger — **verified end-to-end**: auth user created → profile row auto-created,
      "Felix Fixer" split into first/last, avatar mapped, FK cascade cleaned up on delete
- [x] Both migrations promoted to prod

### Repository port — done

- [x] `authentication_repository.dart` ported to Supabase auth + `profiles` + Storage (1,289 lines) —
      **compiles clean, zero Firebase imports**
- [x] Email + password sign in / sign up (profile row comes from the `handle_new_user` trigger)
- [x] Google sign-in via `signInWithIdToken`
- [x] Apple sign-in via `signInWithIdToken` — raw-nonce flow preserved
- [x] Error-code normaliser maps Supabase `AuthException`s onto the Firebase codes the UI copy was
      written against, so every screen switching on a code keeps working unchanged
- [x] `handleAuthentication()` navigation preserved exactly — force-update, maintenance, deletion-pending,
      disabled, customer-block, onboarding and subscription gates all intact
- [x] Profile image upload → Supabase Storage with signed URLs replacing `getDownloadURL()`
- [x] Recursive storage delete replacing `_deleteRecursive(Reference)`
- [x] `updateSubscription(resetUsage:)` still resets **only its 6 counters**, not all 17
- [x] De-leaked `lib/blocs/auth/auth_state.dart`
- [x] De-leaked `lib/core/utils/dialog_utils.dart`
- [x] De-leaked `lib/screens/authentication/onboarding/personal_details_step.dart`
- [x] De-leaked `lib/screens/quotes/new_quote_screen.dart`
- [x] De-leaked `lib/screens/subscription/choose_plan_screen.dart`
- [x] **All UI and bloc Firebase leaks gone.** The 22 files still importing `firebase_auth` are all
      Phase 3 data repositories using it only to read the current uid
- [x] `flutter analyze`: **0 errors**; all 7 tests pass
- [x] `recovery_window_ends_at` / `personal_data_retained_until` columns + guard extended to cover them
- [x] `user-documents` storage bucket with per-user RLS (uid is the 2nd path segment)
- [x] `account-disable` + `account-delete` Edge Functions written and **deployed to dev and prod**
- [x] **End-to-end verified:** a client `PATCH` of its own `account_status` is rejected with
      `profiles: account_status is set by the server`, the same operation via the Edge Function returns
      `{"ok":true}`, and the column actually changes

### Still open in Phase 2

- [ ] Email verification + password reset — code written, **untestable until SMTP exists**
- [x] Lazy password-migration bridge — Edge Function AND the app-side call that invokes it
- [ ] Auth flows exercised on a real device against dev

### Findings carried into later phases

- **Verification writes must move server-side.** `tradesman_repository.dart:827-853` writes
  `verificationStatus: 'rejected'` and a rejection reason directly to the user record. The
  `profiles_guard_server_columns` trigger correctly rejects that from a client — a tradesman must not be able
  to set their own verification state. These two call sites become Edge Function calls in Phase 3/5
- **`updateSubscription(resetUsage: true)` resets only 6 counters** (address, invoice, quotation, template,
  service, customer), not the 17 that `usage_repository.resetUsage()` clears. Two different reset behaviours —
  the port must keep them distinct rather than routing both through `reset_usage()`
- **RTDB stored usage counters in two places** — on the user record (via `updateSubscription`) and under
  `usages/$uid` (via `usage_repository`). `usage_counters` is the single home now; Phase 3 must reconcile

## Phase 3 — Data layer *(in progress)*

20 repositories, ~9,300 lines. RTDB `onValue` → Supabase realtime; `set`/`update`/`remove` → insert/update/delete.

### Offline layer — done

> **Finding:** the `sync_queue` Hive box existed but was **never used anywhere**. The app's offline
> capability came entirely from RTDB's built-in persistence, not from app code — so this layer is
> genuinely new, not a port.

- [x] `OfflineSyncService` — persists writes made while offline and replays them oldest-first on
      reconnect. Inserts replay as `upsert` so a half-completed drain cannot fail on a duplicate key;
      a mutation is abandoned after 5 attempts so one poisoned row cannot block the queue
- [x] Wired into `main.dart` after `SupabaseService`, inside the existing boot-step timeout guard
- [x] 4 passing tests: JSON round-trip (including explicit nulls), forward-compatible op decoding,
      attempt counting, and 500 distinct RFC-4122 v4 UUIDs

### Shared base — done

- [x] `OwnedCollectionRepository<T>` — one implementation of the CRUD, streaming, caching and
      offline-queue behaviour shared by every `{collection}/{uid}/{id}` table. Subclasses supply only
      the table name, row mapping and sort order
- [x] Reads emit the cache first so the UI paints instantly and works offline, then switch to realtime
- [x] A stream error falls back to cache instead of breaking the stream, matching RTDB
- [x] A malformed row is skipped rather than blanking the whole list
- [x] **Client-generated UUIDs** so an offline insert has its final primary key before it reaches the
      server — which is what makes queued inserts safe to replay
- [x] `patch()` for partial column updates, so "clear this field" works without nulling everything else

### Atomic document saves — done

> **Why this was needed:** in RTDB a quote was ONE node written with a single `.set()` — parent fields
> plus nested `lines`, `staff`, `terms` and `attached*` arrays. Normalised, that becomes a parent row
> plus four child tables, so the naive port is five statements and a mid-write failure leaves a quote
> with only some of its line items — silently wrong totals.

- [x] `save_quote(jsonb)`, `save_invoice(jsonb)`, `save_job(jsonb)` — whole document in one transaction
- [x] SECURITY INVOKER, so RLS still applies: the function adds atomicity, not privilege
- [x] Children replaced wholesale, which is exactly what `.set()` meant
- [x] `share_token` protected with `coalesce` so a save that omits it cannot blank a server-minted token
- [x] `save_job` deliberately does **not** replace time entries or expenses — those accumulate through
      clock-out and expense capture, and a document save must not wipe logged hours
- [x] **Caught by testing:** `line_total` is a `GENERATED ALWAYS` column and rejected the insert (428C9).
      Verified the generated formulas match the app's exactly, so totals are unchanged:
      `GREATEST((rate + unit_markup) * quantity * (1 - discount/100), 0)` == `QuoteLineDraft.lineTotal`
- [x] **End-to-end verified:** 2 lines + labour + term + attachment saved atomically; `line_total`
      computed as 675 (250 x 3 x 0.9); sort order preserved; re-save without `share_token` kept the
      token and replaced children cleanly

### Repositories ported (11 of 20)

- [x] `customers_repository` — 114 lines to 66, zero Firebase
- [x] `staff_repository`
- [x] `pricing_repository`
- [x] `todo_repository` — named-parameter API preserved via composition
- [x] `journal_repository` — named-parameter API preserved via composition
- [x] `notifications_repository` — **no longer needs Edge Functions.** The
      `notifications_only_read_flag` trigger already prevents a client rewriting contents, so mark-read
      is a direct update; a new owner-scoped DELETE policy covers clearing. Removes 4 endpoints from Phase 5
- [x] `notes` / `photos` / `videos` / `files` — unified into `tool_assets` by `kind`, sharing one
      `ToolAssetStore`; all four public APIs unchanged
- [x] `quote_settings_repository` — settings + `term_library`
- [x] `user-tools` storage bucket with per-user RLS
- [x] `flutter analyze`: **0 errors** app-wide; **11 tests pass**
- [x] All migrations promoted to prod

### Repositories ported — all 20 ✅

- [x] `commission_repository`, `subscription_repository` — RTDB `config/` reads now go through a new
      `AppConfigStore`, the shared reader over `app_config`
- [x] `account_repository` — HTTP-only wrapper; just its bearer token changed
- [x] `quotes_repository` + `invoices_repository` — atomic saves via `save_quote` / `save_invoice`,
      documents rebuilt in one embedded select
- [x] `jobs_repository` — `save_job`, plus `clockOut` now INSERTs one time entry instead of rewriting
      the whole array, so two devices closing sessions can't overwrite each other's hours
- [x] `usage_repository` (1,073 lines) — surgical port keeping every consumer unchanged
- [x] `device_info_repository` (875 lines) — `user_devices` + `user_sessions`
- [x] `tradesman_repository` (2,320 lines) — 95 touchpoints across profiles, portfolio media,
      trade card, qualifications and extra documents
- [x] `image_validator` — image limits from `app_config`
- [x] `flutter analyze`: **0 errors** app-wide; **11 tests pass**
- [x] All migrations and the new Edge Function promoted to prod

### Schema gaps this phase uncovered

Found the same way as before — by diffing the code against the tables, not by trusting them:

- [x] **3 missing usage counters.** Phase 1 took its list from `resetUsage()`, but the authoritative
      list is `_getCountFieldName()`, which maps all 20 `UsageCountType` values. `cancellationsThisMonth`,
      `tradesmanCancellationsThisMonth` and `scheduledVisitsCount` never appear in `resetUsage()`, so
      `bump_usage` would have raised 'unknown field' the first time a cancellation was recorded
- [x] **Single-device login had nowhere to write.** `user_devices` was missing `force_logout_at` /
      `force_logout_reason`, so the entire kick-other-devices mechanism was inert
- [x] **`trade_qualifications` was modelled as a generic document.** The real model is a *requirement
      fulfilment* — without `requirement_id` the app cannot match a document to its requirement at all
- [x] **`save_job` wasn't saving expenses.** They are edited in the job form and persisted by
      `update(job)`, so an added expense would simply never have saved

### Moderation moved server-side

- [x] `tradesman-verification` Edge Function deployed to both projects
- [x] `updateVerificationStatus` / `updateRejectionReason` now refuse client-side approval or rejection
      outright rather than failing opaquely at the guard — a tradesman must not be able to verify
      themselves, and there is no admin surface in this client
- [x] `deleteRegistrationData`'s verification reset routed through the function

### Known behaviour changes

- **Upload progress is no longer continuous.** Firebase's `putFile` exposed a byte-progress stream; the
  Supabase Dart client has none. `onProgress` fires at 0 and 1, so determinate bars jump rather than fill
- **`incrementUsageCountForUser` and friends are now no-ops that log.** They wrote another user's
  counters, which RLS scopes to the signed-in user. They have no callers; if cross-user counting is ever
  needed it requires an Edge Function with an explicit staff-to-employer authorisation check
- **Session history is a status, not a separate node.** RTDB physically moved a session record on logout;
  one table with `logout_at` expresses the same thing and can't lose the record mid-move

- [x] `lib/core/services/database_service.dart` **deleted** — nothing imports it any more

## Phase 4 — Storage ✅

Done inside Phases 2 and 3 rather than as a separate pass; recorded here for completeness.

- [x] Three private buckets: `user-documents`, `user-tools`, each with per-user RLS keyed on the uid
      path segment
- [x] `storage.rules` translated to storage policies
- [x] Signed URLs replace `getDownloadURL()` throughout (10-year expiry, so a stored URL stays valid
      for the life of the record as Firebase's did)
- [x] `files_repository`, `photos_repository`, `videos_repository` — zero Firebase
- [x] `tradesman_repository` storage calls — zero Firebase
- [x] `authentication_repository` profile-image upload
- [x] Recursive tree delete replacing `_deleteRecursive(Reference)` — Supabase has no folder delete
- [ ] Upload/download/delete exercised on a device

**Known behaviour change:** upload progress is no longer continuous. Firebase's `putFile` exposed a
byte-progress stream; the Supabase Dart client has none, so `onProgress` fires at 0 and 1 and
determinate bars jump rather than fill.

## Phase 5 — Edge Functions *(in progress)*

One `api` Edge Function with a hand-rolled router, preserving the Express paths exactly.

### Foundation — done

- [x] `api` function scaffolded and deployed to dev; dependency-free router (~17 simple routes did not
      justify a framework in the bundle)
- [x] `lib/context.ts` — service-role client, Supabase JWT verification, admin check, rate limiting
- [x] `lib/fcm.ts` — **FCM HTTP v1 implemented directly.** `firebase-admin` is a Node SDK and does not
      run on Deno, so token minting (RS256 JWT via Web Crypto), sending, and dead-token detection are
      written against the REST API. This also closes Phase 6's outstanding server-send item
- [x] `lib/notify.ts` — in-app row + push fan-out, pruning only genuinely dead tokens
- [x] `admin_roles` table replacing RTDB `config/admin/systemRoles` — service-role only, so no client
      can enumerate admins
- [x] `rate_limit_hits` + `rate_limit_check()` — the abuse protection the public routes lost with
      App Check. Fixed-window, fails open, self-cleaning
- [x] **HTML renderers lifted verbatim** (~2,000 lines) from the Cloud Functions. They are pure string
      builders, so the page a customer opens is byte-identical; only the loader beneath them changed
- [x] `data/shares.ts` — resolves a token to a whole document in one embedded select

### Routes done (7 of ~17)

- [x] `GET /q/:token`, `GET /i/:token` — public viewers, rate-limited, first-view notification
- [x] `POST /q/:token/respond` — accept/reject, now guarded so two clicks cannot both win
- [x] `POST /quotes/share-link`, `POST /invoices/share-link` — idempotent, subscription-gated
- [x] `POST /quotes/delete`, `POST /invoices/delete` — tombstoning shares
- [x] `GET /ping`

### Verified end-to-end on dev

Mint link → customer opens (200) → accepts (200) → second response rejected (409) → status mirrored to
the quote → owner deletes (200, 1 share tombstoned) → **old link returns 410 "withdrawn"** → quote row
actually gone. Plus 402 when the caller has no active subscription.

### Three bugs found

- [x] **The public quote page has always shown wrong line totals.** Its renderer computed
      `gross - discount`, treating a PERCENTAGE as an absolute amount: a 10% discount on £750 rendered
      as £740 instead of £675. The *invoice* renderer had the correct formula, so quotes and invoices
      disagreed with each other as well as with the app. Fixed by passing the database's
      GENERATED ALWAYS `line_total` through and preferring it — one source of truth
- [x] **Every customer accept/reject would have failed.** `document_shares_responded_action_check`
      allowed only `'accepted'`/`'rejected'`, but the code contract — original Cloud Function, its
      type, and the viewer's locked-state renderer — is `'accept'`/`'reject'`
- [x] **Withdrawing a document destroyed its own tombstone.** `document_shares.quote_id` was
      ON DELETE CASCADE, so deleting a quote deleted the share row, and a customer holding the link
      got a bare "not found" instead of "withdrawn by the tradesperson" — the exact behaviour the
      delete endpoint exists to provide. Changed to ON DELETE SET NULL, with the exactly-one check
      relaxed for tombstones

### Platform gotcha

- [x] Edge Functions verify JWTs at the platform layer by default, which returned **401 to a
      customer's browser** before the handler ran. Disabled for this function (`verify_jwt = false`)
      since it serves public pages and does its own auth

### All routes done (16) ✅

- [x] `GET /q/:token`, `GET /i/:token` — public viewers
- [x] `POST /q/:token/respond`
- [x] `GET /q/:token/:mode/:kind/:id`, `GET /i/:token/:mode/:kind/:id` — asset streaming
- [x] `POST /quotes/share-link`, `POST /invoices/share-link`
- [x] `POST /quotes/delete`, `POST /invoices/delete`
- [x] `POST /account/request-deletion`, `POST /account/recover`, `GET /account/export-data`
- [x] `POST /subscriptions/activate-trial`
- [x] `POST /iap/apple/validate`, `POST /iap/google/validate`
- [x] `POST /iap/apple/notifications`, `POST /iap/google/notifications` — public webhooks
- [x] `POST /notifications/send` — admin only
- [x] `GET /ping`
- [x] **Deployed to dev AND prod**; prod smoke-tested
- [x] `/notifications/mark-read` and `/notifications/clear` **no longer needed** — direct Postgres

Two Node libraries had no Deno equivalent and were reimplemented against the raw APIs:
`jsonwebtoken` (ES256 for Apple, RS256 for Google/FCM) and `firebase-admin`.

### Verified end-to-end on dev

- Share lifecycle: mint → open (200) → accept (200) → re-respond (409) → status mirrored →
  delete (200) → **old link 410 "withdrawn"** → row gone
- Account: trial (200) → second trial (409, database-enforced) → export (correct filename, **no bank
  fields leaked**) → request-deletion (200) → **re-signin still works during the recovery window** →
  recover (200) → recover again (400)
- IAP: webhooks public and tolerant; validate routes 401 without auth, 400 on bad input
- Admin: non-admin broadcast **403**; admin broadcast 200 with rows landing; `admin_roles`
  **unreadable by clients**
- All 16 routes confirmed reachable through the router

### Old share links

- [x] `firebase.json` reduced to Hosting ONLY — `database` and `functions` removed so a stray
      `firebase deploy` cannot resurrect them
- [x] `/q/:rest*` and `/i/:rest*` redirect to the prod Edge Function. `:rest*` in **both** source and
      destination — a bare `**` matches but captures nothing, which would silently drop the token
- [x] **302, not 301**: a permanent redirect is cached forever, stranding anyone who opened a link
      before the API URL was final
- [x] `HOSTING_CUTOVER.md` written with deploy + verification steps
- [ ] Run `firebase deploy --only hosting` — **left for you**: it changes live behaviour for links
      already in customers' inboxes

### Still open

- [x] `POST /quotes/send-email`, `POST /invoices/send-email` — written against the Resend REST API
      (nodemailer and the Resend SDK are both Node-only). Templates lifted verbatim so the email a
      customer receives is byte-identical. Returns a clear 503 until `RESEND_API_KEY` is set
- [x] `FIREBASE_SERVICE_ACCOUNT` set on both projects; FCM sender verified against Google
      (invalid token correctly rejected AND pruned, which only a working JWT/OAuth chain reaches)
- [ ] Set IAP secrets: `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_BUNDLE_ID`,
      `APPSTORE_PRIVATE_KEY`, `GOOGLE_PLAY_SA_JSON`, `ANDROID_PACKAGE_NAME`
- [x] Point the app's `stripeBackendUrl` at the new API — done in Phase 9, verified live
- [ ] Optional: custom domain + `PUBLIC_SHARE_BASE_URL` so new links skip the redirect hop

## Phase 6 — FCM rewiring ✅

Firebase Cloud Messaging stays — it is the one Firebase product the app keeps. Only what surrounds it moved.

- [x] Token storage moved from `users/{uid}/fcmTokens/{tokenKey}` to the `fcm_tokens` table.
      The RTDB key had to be mangled (`:` and `/` are invalid keys, truncated to 40 chars);
      `(owner_id, token)` is a composite primary key, so the full token is stored as-is and the
      mangling is gone
- [x] `push_notifications_service` follows Supabase auth state, skipping the hourly
      `tokenRefreshed` event so a token refresh doesn't cause pointless write traffic
- [x] `subscription_listener_service` — one stream over `subscriptions` instead of two RTDB nodes
- [x] `iap_service` — validation now sends the Supabase JWT
- [x] `flutter analyze`: **0 errors**; 11 tests pass

**Finding:** `SubscriptionListenerService.startListening()` has no callers, and nothing in the app
reads a *tool* subscription. RTDB had `subscription/member` and `subscription/tool`; `subscriptions`
is one row per owner, so `tool` is always null. Documented in the code — if tool subscriptions are
ever used they need their own table, not a second listener.

- [x] Server-side send via Edge Function → FCM HTTP v1 (`lib/fcm.ts`, RS256 via Web Crypto)
- [ ] Foreground, background and tap-to-open verified on a device
- [ ] Verified on both iOS and Android

## Phase 7 — Remote Config replacement ✅

- [x] `AppConfigStore` — shared reader over `app_config`, cached in memory and Hive so a cold
      offline launch gets the last-known config rather than built-in defaults
- [x] `ConfigService` ported (764 lines) — public API unchanged, `_parseRemoteConfig` became
      `_parseAppConfig`. Remote Config returned JSON as strings needing `jsonDecode`; app_config
      stores real jsonb, so object keys arrive as maps
- [x] `app_config_service` — reassembles the four `config/` keys into the one map the model expects
- [x] `subscription_config_service` — `config/subscriptions` and `config/videoLimits`
- [x] `configurations_repositories` — constructor no longer takes a `FirebaseRemoteConfig`
- [x] `image_validator` — `config/imageLimits`
- [x] **`firebase_remote_config` and `firebase_app_check` removed from `pubspec.yaml`**

**Bug caught while wiring boot:** `ConfigService().initialize()` ran *before*
`SupabaseService().initialize()`. `AppConfigStore.load()` silently no-ops without a client, so
maintenance mode and force-update would have stayed on their built-in defaults forever — failing
open, with no error. Boot order corrected, with a comment saying why it matters.

**App Check decision — removed.** It attested callers to Realtime Database, Storage and Remote
Config, none of which the app still uses, and it cannot gate Supabase. The equivalent protection is
RLS (every table owner-scoped and verified) plus Edge Function rate limiting — a stronger guarantee
for data access, since it checks *authorisation* rather than *client authenticity*. What is genuinely
lost is abuse protection on the public share endpoints, which have no authenticated caller to scope.
**Phase 5 must put rate limiting in front of those routes.**

## Milestone: Firebase reduced to messaging ✅

- [x] `firebase_auth`, `firebase_database`, `firebase_storage`, `firebase_remote_config` and
      `firebase_app_check` all removed from `pubspec.yaml`
- [x] Only `firebase_core` (2 imports) and `firebase_messaging` (3 imports) remain in `lib/`
- [x] `database_service.dart` deleted

## Phase 8 — Data migration *(dev complete)*

> **The dataset is small.** Production is **13 auth users, 181 records, 3 storage objects, 45 KB of
> RTDB**. That changes the risk profile entirely — this is not a bulk migration.

### Tooling

- [x] `tools/migrate_to_supabase.py` — export → transform → load, **idempotent** (every write is an
      upsert on a stable id, so a partial run is simply re-run)
- [x] `tools/migrate_storage.py` — Firebase Storage → Supabase Storage
- [x] Exports in `.migration-data/`, **gitignored** — they contain real user PII
- [x] Firebase auth users + production RTDB exported

### Identity

- [x] No mapping table: each Firebase user becomes a Supabase user whose `profiles.firebase_uid`
      records the origin. That column is also the idempotency key
- [x] Child records use **deterministic UUIDv5** derived from the RTDB key, so a re-run maps the same
      record to the same row instead of duplicating it, and cross-document references still line up

### Loaded into dev and verified

- [x] 13 auth users, 12 profiles, 9 subscriptions, 12 fcm tokens
- [x] 2 customers, 4 staff, 11 pricing items, 17 notifications, 5 tool assets
- [x] 7 quotes with 15 lines, 5 labour lines, 1 attachment; 3 jobs with 6 time entries
- [x] 5 document shares, 6 config keys — **122 writes**
- [x] **Row counts verified against the source, scoped to migrated users** — every table matches
- [x] **A real production share token renders correctly through the live API** with reference, title,
      customer name, line item and total all matching the RTDB original

### Storage

- [x] 3 objects copied, **paths remapped** from `users/{firebase_uid}/…` to `users/{supabase_uuid}/…`
- [x] `tool_assets` rows repointed at Supabase signed URLs. The old
      `firebasestorage.googleapis.com` URLs die with the Firebase project, so leaving them would have
      silently broken every image

**Why the remap matters:** the storage policy scopes a user to their own prefix by comparing the second
path segment to `auth.uid()` — the *Supabase* uuid. Copying keys verbatim would have uploaded files the
owner could not read.

### Password bridge

- [x] `POST /auth/bridge` deployed to dev and prod — verifies the old password against Firebase once,
      then sets the Supabase one. Users type the password they have always used and notice nothing
- [x] `password_migrated_at` records the crossing; the guard trigger protects it
- [x] **Security verified:** wrong password and unknown email return **byte-identical** responses (no
      account enumeration); rate-limited per IP *and* per email; a native Supabase account can never be
      bridged; the Firebase uid must match the one the profile was migrated from
- [ ] Happy path untested — that needs a real user's password, which I do not have

### Two bugs found in my own tooling

- [x] **The dry run overwrote the real uid map** with `dry-` placeholders, and dev/prod shared one file.
      Fixed: dry runs never write it, and it is namespaced per target. The dev map was regenerated from
      the database, which is the authoritative record
- [x] **An orphaned share would have failed the load.** Production has an `invoiceShares` entry pointing
      at an invoice that no longer exists; its FK would be rejected. Skipped with a count, and the
      customer-facing behaviour is unchanged — that link already 404s today

### Production import — deliberately not run

- [ ] Run the import against prod **at cutover, not before**

The app does not point at Supabase yet, so importing now buys nothing and costs something: any model
mismatch found during device testing would mean re-shaping data that is already loaded. The script is
idempotent and verified against identical data on dev, so running it at cutover is a known quantity.

- [ ] Rehearse rollback (prod Supabase is currently empty, so rollback is `delete from` + re-run)

## Phase 9 — Cutover & Firebase removal *(code complete)*

### Backend URL repointed

- [x] `app_config.dev_variable` / `prod_variable` now name each environment's own Edge Function, on
      **both** projects; verified live (`/ping` = 200 for each)
- [x] `databaseUrl` blanked — a dead field that still looked live was worse than an empty one

**The env-mismatch guard was rebuilt, not deleted.** It used to compare the RTDB url against the Cloud
Function name (`api` vs `apiProd`) after a split config silently sent subscription writes to the wrong
database and broke the free-trial flow. RTDB is gone, but that failure mode is not: dev and prod are
separate Supabase projects. The check now compares the **project ref** in the backend URL against the
one expected for this build's `APP_TYPE`, which is a stricter test than the old suffix ever was — a
staging build can no longer talk to production at all.

### Firebase reduced to messaging

- [x] `firebase_options.dart` trimmed: `databaseURL` and `storageBucket` removed, since nothing reads
      them and leaving them implied those products were still in use. What remains is what FCM needs
- [x] `database.rules.json`, `storage.rules`, `functions/` and the app-level `firebase.json` moved to
      `.retired/` with a README — kept as reference, not deleted, until production is verified
- [x] `google-services.json` / `GoogleService-Info.plist` **kept** — FCM still needs them
- [x] **Only `firebase_core` (2 imports) and `firebase_messaging` (3 imports) remain in `lib/`**
- [x] `flutter analyze`: 0 errors · 11 tests pass · debug APK builds

### Not done — and these need a person

- [ ] **Run the app on a device.** Nothing has executed against Supabase from inside the app. Every
      verification so far has been HTTP-level, and this is the single largest untested surface
- [ ] Full regression across the 90 screens
- [ ] `firebase deploy --only hosting` — see `HOSTING_CUTOVER.md`
- [ ] Production data import at cutover (`tools/migrate_to_supabase.py --target prod`)
- [ ] Release

### Blocked on credentials

- [x] Resend — send-email routes verified end to end
- [x] Supabase Auth SMTP configured on both projects
- [ ] Confirm a reset email lands in an inbox
- [x] `FIREBASE_SERVICE_ACCOUNT` set on both projects; FCM sender verified against Google
      (invalid token correctly rejected AND pruned, which only a working JWT/OAuth chain reaches)
- [ ] Apple IAP: `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_BUNDLE_ID`, `APPSTORE_PRIVATE_KEY`
- [ ] Google IAP: `GOOGLE_PLAY_SA_JSON`, `ANDROID_PACKAGE_NAME`
- [ ] Google/Apple auth providers on the **prod** project (dev already has them)
