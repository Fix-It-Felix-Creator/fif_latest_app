# Migration TODO — work through in order

**Status: 196 of 218 done.** `flutter analyze` 0 errors · 11 tests pass · APK builds ·
all 18 API routes live on dev and prod.

Projects: `mjteytegbjvemuxoimlq` = **dev**, `nhghuurzmwoirnjkpvaa` = **prod**.

---

## ✅ 1. Resend email — DONE

- [x] `RESEND_API_KEY` set on both projects
- [x] `FROM_NAME` = "Fix It Felix Pro"
- [x] `FROM_EMAIL` = `no-reply@fixitfelix.app`
- [x] **Verified: a real quote email sent successfully**, quote flipped `draft -> sent`,
      the emailed link opens for a customer with no auth, and Resend has the send on record

**Two things this uncovered — worth a decision:**

1. **The sending domain is `fixitfelix.app`.** That is the only domain verified on the Resend
   account; `fixitfelixsoftwaresolutions.com` is not. Emails now come from
   `no-reply@fixitfelix.app`. If you would rather they came from the other domain, verify it at
   <https://resend.com/domains> and then:
   ```bash
   supabase secrets set FROM_EMAIL=no-reply@fixitfelixsoftwaresolutions.com --project-ref mjteytegbjvemuxoimlq
   supabase secrets set FROM_EMAIL=no-reply@fixitfelixsoftwaresolutions.com --project-ref nhghuurzmwoirnjkpvaa
   ```

2. **A long-standing typo in the email footer.** The Cloud Function hardcoded the support address
   as `info@fixitfelixsoftwaresolution.com` — *singular* "solution". Everything else in the app
   uses the *plural* `fixitfelixsoftwaresolutions.com`. Customers replying to a quote email have
   likely been writing to a domain that does not accept mail. I corrected it to the plural.
   Override if that is wrong:
   ```bash
   supabase secrets set EMAIL_SUPPORT_ADDRESS=info@yourdomain.com --project-ref mjteytegbjvemuxoimlq
   ```

---

## ✅ 2. Supabase Auth SMTP — CONFIGURED (needs one inbox check)

Set on **both** projects via the dashboard, both reporting "Successfully updated settings":

| Field | Value |
|---|---|
| Host | `smtp.resend.com` |
| Port | `587` |
| Username | `resend` |
| Password | the `re_...` key |
| Sender | `no-reply@fixitfelix.app` |
| Sender name | `Fix It Felix Pro` |

- [x] dev configured
- [x] prod configured
- [x] `POST /auth/v1/recover` returns 200

**One thing I could not verify — please check:**

- [ ] **Confirm the password-reset email actually arrived.** Resend's `/emails` API only lists mail
      sent through their REST API; SMTP relays do not appear there, so I cannot see it from here. The
      `recover` endpoint also returns 200 whether or not an account exists (deliberate — it prevents
      account enumeration), so a 200 is not proof of delivery either.

      Trigger one and watch the inbox:
      ```bash
      curl -X POST https://mjteytegbjvemuxoimlq.supabase.co/auth/v1/recover \
        -H "apikey: <anon key>" -H "Content-Type: application/json" \
        -d '{"email":"your@email.com"}'
      ```
      Expect it from `Fix It Felix Pro <no-reply@fixitfelix.app>`. If nothing arrives, check
      Resend → Logs (which does show SMTP traffic) and the Supabase project's Auth logs.

      Note the rate limit is now **30 emails/hour** — that is Supabase's default once custom SMTP is
      on, raised from the shared-sender trickle. Adjustable under Authentication → Rate Limits.

## ✅ 3. Push notifications — DONE and verified

- [x] `FIREBASE_SERVICE_ACCOUNT` set on both projects
      (`firebase-adminsdk-fbsvc@fifcloud.iam.gserviceaccount.com`)
- [x] **The FCM sender is proven working.** Registered a deliberately-invalid token and sent a
      broadcast: `{"sent":1,"pushSent":0,"pushFailed":1}` and the bad token was **pruned**.

**Why that result proves it.** For Google to *reject* a token, the whole chain has to work first:
parse the service account → sign an RS256 JWT with Web Crypto → exchange it for an OAuth access
token with Google → POST to FCM v1 → parse the rejection. A broken chain returns a transient
`error`, which deliberately does **not** prune. Pruning is only reachable via a real `UNREGISTERED`
response, so it is the strongest signal available without a physical device.

- [ ] Confirm a push actually lands on a handset — needs a real device token (covered by step 7)

## 4. Apple IAP secrets

From App Store Connect -> Users & Access -> Integrations -> In-App Purchase key.

```bash
supabase secrets set APPSTORE_KEY_ID=XXXXXXXXXX      --project-ref <ref>
supabase secrets set APPSTORE_ISSUER_ID=xxxxxxxx-... --project-ref <ref>
supabase secrets set APPSTORE_BUNDLE_ID=com.techkushx.fixitfelixpro --project-ref <ref>
supabase secrets set APPSTORE_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" --project-ref <ref>
```

- [ ] dev · [ ] prod
- [ ] Point App Store Server Notifications V2 at
      `https://nhghuurzmwoirnjkpvaa.supabase.co/functions/v1/api/iap/apple/notifications`

---

## 5. Google Play IAP secrets

```bash
supabase secrets set GOOGLE_PLAY_SA_JSON="$(cat play-service-account.json)" --project-ref <ref>
supabase secrets set ANDROID_PACKAGE_NAME=com.techkushx.fixitfelixpro --project-ref <ref>
```

- [ ] dev · [ ] prod
- [ ] Point Play RTDN (Pub/Sub push) at
      `https://nhghuurzmwoirnjkpvaa.supabase.co/functions/v1/api/iap/google/notifications`

---

## 6. Google + Apple sign-in on **prod** — DONE 2026-08-23

Configured to match dev exactly. Both use the **native ID-token flow**, so no OAuth client
secret is set on either project — that is correct, not an omission.

`Authentication -> Sign In / Providers`

- [x] Google — 3 client IDs (web / iOS / Android), byte-identical to dev
- [x] Apple — client ID `com.techkushx.fixitfelixpro`

The three Google client IDs are the ones the app actually ships:

| client ID prefix | source in repo | role |
|---|---|---|
| `…-j92ahukq` | `google-services.json` type 3 | Web / Android server |
| `…-2gg9pppi` | `GoogleService-Info.plist` CLIENT_ID | iOS |
| `…-4tdva2kb` | `google-services.json` type 1 | Android |

Verified live on both projects via `GET /auth/v1/settings`:

```
staging     enabled : apple, email, google
production  enabled : apple, email, google
```

- [ ] **Eyeball one toggle before prod cutover:** Google -> *Skip nonce checks* must be ON
  (dev has it on; iOS native Google sign-in fails without it). I set it and the save
  returned "Successfully updated settings", but the dashboard would not re-render for me
  to read it back, so it is unconfirmed. It only matters once the app points at prod.

Site URL and redirect URLs (`fixitfelix://login-callback`) are already set on both.

---

## 7. 📱 Run the app — **the real remaining risk**

Debug can't attach on the iOS 27 beta, so use the release-build script:

```bash
cd fixitfelixpro && ./run-device.sh staging    # staging = dev project
```

Each step exercises a different layer:

- [x] **Sign up** with a new email → auth + the `handle_new_user` trigger
      *(verified 2026-08-24: 1 auth user, matching profile auto-created)*
- [x] **Complete onboarding** → `ProfileMapper` round-trip against a live row
      *(verified: first_name / phone / postcode all persisted)*
- [x] **Start the free trial** → `/subscriptions/activate-trial` + the gate reads it back
      *(needed the `SubscriptionMapper` fix below — see "Fixed during testing")*
- [ ] **Create a customer** → `OwnedCollectionRepository` + RLS + realtime stream
      **← next; this base class backs ~15 collections, so it is the highest-value single test**
- [ ] **Create a quote, 2 line items, one with a discount** → `save_quote`, generated
      `line_total`, child-table writes
- [ ] **Share it; open the link in a browser** → public viewer end to end
- [ ] **Email it to yourself** → the send-email route in the real flow
- [ ] **Upload a photo in Tools** → storage upload + signed URL
- [ ] **Confirm a push lands on the handset** → `fcm_tokens` is still empty, so the token
      has not registered yet; this also closes the open box in item 3
- [ ] **Turn off wifi, edit something, turn it back on** → the offline queue drains
- [ ] ~~Sign in as a migrated user → password bridge~~ **NOT TESTABLE** — the migrated users
      were deleted in the 2026-08-24 wipe. See item 10.
- [ ] Full regression across the 90 screens

### Fixed during testing

- **Realtime DELETE never reached the client** (found 2026-08-24, systemic). Deleting a journal
  event removed the row from Postgres but left it on screen. Two compounding causes: every
  published table was on the default replica identity, so a DELETE's WAL record carries only the
  primary key — with no `owner_id` the `.eq('owner_id', uid)` stream filter could not match and
  RLS could not be evaluated, so the event was dropped; and `delete()` updated the Hive cache
  while open `watchAll()` streams only read that cache once, at listen time. INSERT/UPDATE were
  fine because their payloads carry the full row, which is why creating worked and deleting did
  not. Affected all 8 `OwnedCollectionRepository` subclasses and the 7 screens that call
  `repository.delete()` directly instead of going through their bloc (customers, invoices,
  quotes, staff, todos, pricing, journal). Fixed with `replica identity full` on all 13 published
  tables (migration `20260824093000`, applied to dev + prod) plus a local-change bus in the base
  class so optimistic writes re-emit to open streams.

- **Subscription never loaded into the user document** (found 2026-08-24). RTDB nested it under
  the user record; Postgres puts it in its own table and nothing fetched it, so
  `user.subscription` was always null. That made `_needsSubscription()` route *every* user to
  ChoosePlan for ever, trial or paid, and Settings show "No active plan". Fixed with a shared
  `SubscriptionMapper` wired into `getUserDetails()`, `streamUserDetails()` (which was also
  clobbering the cache) and `AuthUserRefreshed` (which was not reloading at all). 5 new tests.

---

## 8. 🚀 Cutover

- [ ] `firebase deploy --only hosting` — keeps links already in customers' inboxes alive,
      and serves the email logo. See `HOSTING_CUTOVER.md`
- [ ] Verify: `curl -sI https://fifcloud.web.app/q/SOME_TOKEN | head -3` → 302 to Supabase
- [ ] **DECIDE FIRST: is the production data import still wanted?** (see item 10) If yes:
      ```bash
      export SUPABASE_PROD_URL=https://nhghuurzmwoirnjkpvaa.supabase.co
      export SUPABASE_PROD_SERVICE_KEY=...
      python3 tools/migrate_to_supabase.py --target prod --dry-run
      python3 tools/migrate_to_supabase.py --target prod
      python3 tools/migrate_storage.py   --target prod
      ```
- [ ] Spot-check prod row counts (expect 13 users, 181 records, 3 storage objects)
- [ ] **Seed prod's 6 missing `app_config` keys** — `accountDeletion`, `admin`,
      `commissionRates`, `imageLimits`, `subscriptions`, `videoLimits`. These came from the
      RTDB `/config` migration, not from a seed migration, so dev has 16 keys and prod only 10.
      Four are read by live code (commission repo, image validator, subscription config, usage
      repo) and would read empty on prod. Write them into a proper migration so both match.
- [ ] Ship a build with an **even** build number (production env by parity rule)

**Rollback** is currently trivial — prod Supabase holds no app data, so it is `delete from` the
affected tables and re-run. Both scripts are idempotent.

---

## 9. Optional

- [x] ~~Optional~~ **REQUIRED** — custom domain (`share.fixitfelixsoftwaresolutions.com`) →
      set `PUBLIC_SHARE_BASE_URL`. Not a polish item: Supabase rewrites `text/html` to
      `text/plain` on `*.supabase.co`, so every `/q/` and `/i/` share page currently renders
      as raw source in the customer's browser. Needs the Custom Domain add-on ($10/mo, Pro).
      Full runbook: `CUSTOM_DOMAIN.md`
- [ ] **`firebase deploy --only hosting` was never run** — `fifcloud.web.app/i/<token>` 404s,
      so every share link already in a customer's inbox is dead. Fix as part of `CUSTOM_DOMAIN.md`
      step 5 (the redirect destination must be the custom domain, not `supabase.co`)
- [ ] Delete `.retired/` once production is verified
- [ ] Rotate the Resend API key — it was pasted into a chat transcript

---

## Reference

| File | What |
|---|---|
| `MIGRATION.md` | full phase-by-phase record, every decision and finding |
| `REMAINING.md` | narrative version of what is left |
| `HOSTING_CUTOVER.md` | the old-share-links problem and its fix |
| `.retired/README.md` | what was retired and what replaced it |
| `tools/migrate_to_supabase.py` | data migration (idempotent) |
| `tools/migrate_storage.py` | storage migration (idempotent) |

---

## 10. ⚠️ Open decision — what happens to the 13 real users?

On 2026-08-24 both databases were wiped to a clean slate at your request. That was the right call
for testing, but it changes the cutover plan, so it needs a decision rather than an assumption.

Nothing is lost: Firebase is untouched and still the live source of truth, and
`.migration-data/` holds the full RTDB export, the auth-user list and the import tooling.

- [ ] **Decide:** at cutover, do the 13 existing users come across, or does production start empty?
  - **Import them** — customers keep their history and their share links keep working. The
    lazy password bridge matters, and item 7's bridge test needs re-running against a
    re-imported dev.
  - **Start empty** — everyone re-registers. Simpler, but old share links 404, history is gone,
    and `POST /auth/bridge` plus `password_migrated_at` become dead code to delete.

Until this is settled, item 8's import step and item 7's password-bridge test are both blocked.
