# What's left

Everything that can be written and verified without a device or a credential
is done: **194 of 218 items**. `flutter analyze` 0 errors, 11 tests pass, the
APK builds, and all 18 API routes are live on dev and prod.

The 24 open items are all one of three things.

---

## 1. Needs credentials — 5 items, ~30 minutes

Each is a one-line `supabase secrets set` on **both** projects
(`mjteytegbjvemuxoimlq` = dev, `nhghuurzmwoirnjkpvaa` = prod). The code is
written, deployed, and degrades cleanly until the secret exists.

| Secret | Unblocks | Symptom today |
|---|---|---|
| `RESEND_API_KEY` (+ optional `FROM_EMAIL`, `FROM_NAME`) | send-quote / send-invoice email | routes return a clear 503 |
| SMTP in Supabase Auth settings (dashboard, not a secret) | password reset, email verification | Supabase's default sender is rate-limited to a trickle |
| `FIREBASE_SERVICE_ACCOUNT` | push notifications | in-app rows are written, no push is sent |
| `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_BUNDLE_ID`, `APPSTORE_PRIVATE_KEY` | Apple IAP validation + webhooks | validation returns 500 |
| `GOOGLE_PLAY_SA_JSON`, `ANDROID_PACKAGE_NAME` | Google IAP validation + webhooks | validation returns 500 |

```bash
supabase secrets set RESEND_API_KEY=re_xxx --project-ref mjteytegbjvemuxoimlq
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)" --project-ref mjteytegbjvemuxoimlq
# ...repeat for nhghuurzmwoirnjkpvaa
```

Also dashboard-only: **enable Google and Apple auth providers on the prod
project.** Dev already has them; prod has Email only. They need the same OAuth
client IDs and secrets dev uses.

---

## 2. Needs a device — the real remaining risk

**Nothing has executed against Supabase from inside the app.** Every
verification so far has been HTTP-level: RLS, routes, migrations, and real
production data rendering through the live API. But no Flutter code has run.

That is the single largest untested surface in the project, and it cannot be
closed from here.

Suggested smoke test, in order — each step exercises a different layer:

1. **Sign up** with a new email → confirms auth + the `handle_new_user` trigger
2. **Complete onboarding** → confirms `ProfileMapper` round-trip against a live row
3. **Create a customer** → confirms `OwnedCollectionRepository` + RLS + realtime
4. **Create a quote with two line items and a discount** → confirms `save_quote`,
   the generated `line_total`, and the child-table writes
5. **Share it, open the link in a browser** → confirms the public viewer end to end
6. **Upload a photo in Tools** → confirms storage upload + signed URL
7. **Go offline, edit something, come back online** → confirms the offline queue
8. **Sign in as a migrated user** (one of the 5 with a Firebase password) →
   confirms the password bridge

Then the full regression across the 90 screens.

---

## 3. Deliberate holds — yours to trigger

**`firebase deploy --only hosting`** — changes live behaviour for share links
already in customers' inboxes. See `HOSTING_CUTOVER.md`.

**Production data import** — `python3 tools/migrate_to_supabase.py --target prod`
then `tools/migrate_storage.py --target prod`. Held until cutover on purpose:
the app does not point at Supabase in production yet, so importing now buys
nothing, and any model mismatch found during device testing would mean
re-shaping data that is already loaded. Both scripts are idempotent and were
verified against identical data on dev.

**Rollback** is `delete from` the affected tables and re-run — prod Supabase
holds no data yet, so there is nothing to lose.

---

## Optional, not blocking

Point a custom domain (e.g. `share.fixitfelixsoftwaresolutions.com`) at the
Edge Function and set `PUBLIC_SHARE_BASE_URL`. New share links then skip the
Hosting redirect hop, and customer-facing emails stop showing a
`supabase.co` URL.
