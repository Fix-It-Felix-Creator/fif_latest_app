# Device smoke test

The app on your phone is built with `ENV=staging`, so it talks to
**fif-pro-development** (`mjteytegbjvemuxoimlq`) — the project holding the
migrated data with Google and Apple sign-in configured.

**Production is deliberately still empty.** Do not test against it; it would
look like a broken app.

Work down the list. After each step, tell me the number and what you saw — I
verify it landed correctly in Postgres before you move on, so a failure gets
caught at the step that caused it rather than three steps later.

---

## 1. Launch

**Do:** open the app.

**Expect:** the sign-in screen, no white screen, no crash.

**What it proves:** the whole boot chain — `SupabaseService` connects,
`ConfigService` reads `app_config` from Postgres (replacing Remote Config),
`AppConfigService` loads, and the offline sync service starts.

**If it white-screens:** that is the boot order. Tell me and I will pull it apart.

---

## 2. Sign up

**Do:** create an account with an email you can read.

**Expect:** it accepts the signup and moves you toward onboarding or email
verification.

**Proves:** Supabase Auth + the `handle_new_user` trigger creating your
`profiles` row automatically.

**I check:** an `auth.users` row exists and a matching `profiles` row was
created by the trigger.

---

## 3. Verification email

**Do:** check your inbox.

**Expect:** an email from `Fix It Felix Pro <no-reply@fixitfelix.app>`.

**Proves:** the Auth SMTP relay through Resend — the one thing from item 2 I
could not verify myself.

**If nothing arrives:** check spam, then tell me — I will look at Resend's logs.

---

## 4. Onboarding

**Do:** complete it — first name, phone, address.

**Expect:** it saves and moves you on.

**Proves:** `ProfileMapper` writing a live row. This is the biggest single
piece of new code in the migration: it translates the flat snake_case
`profiles` row to and from the nested camelCase JSON the Dart models expect,
which is what let every model and screen stay untouched.

**I check:** your name, phone and address landed in the right columns, and
that the address nests back correctly on read.

---

## 5. Create a customer

**Do:** add a customer with a name and email.

**Expect:** it appears in the list immediately.

**Proves:** `OwnedCollectionRepository` — the shared base under 15 repositories
— plus RLS and the realtime stream that replaced RTDB's `onValue`.

**I check:** the row exists, is scoped to your `owner_id`, and no other user
can see it.

---

## 6. Create a quote — the important one

**Do:** new quote → pick the customer → add **two line items**, and give the
second one a **10% discount**. Save.

**Expect:** the total reflects the discount.

**Proves:** the `save_quote` RPC writing parent + child tables in one
transaction. In RTDB this was a single `.set()`; normalised it is five
statements, and a partial write would leave a quote with only some of its line
items and a total that does not add up.

**I check:** the parent, both `quote_lines`, and that the database-computed
`line_total` matches what the app shows. This is where the discount bug lived —
the public page used to compute `gross − discount` (treating a percentage as an
amount) while the app used `gross × (1 − discount/100)`.

---

## 7. Share it

**Do:** share the quote → copy the link → open it in Safari.

**Expect:** the public quote page with your business name, the customer, both
line items and the correct totals.

**Proves:** the whole public path — Edge Function, token resolution, the
renderer lifted verbatim from the Cloud Functions.

**I check:** the page HTML matches the stored quote, and that a `viewed_at` was
stamped exactly once.

---

## 8. Push notification

**Do:** nothing — opening that link in step 7 should trigger it.

**Expect:** a **"Quote opened"** push on the phone.

**Proves:** the full FCM chain end to end on a real device token — the last
piece I could only verify against a fake token.

**I check:** the `fcm_tokens` row for your device and the `notifications` row.

---

## 9. Email the quote

**Do:** use the app's "send by email" on the quote, to an address you can read.

**Expect:** an email with the share link; the quote flips to **sent**.

**Proves:** the send-email route in the real flow.

---

## 10. Upload a photo

**Do:** Tools → Photos → add one.

**Expect:** it uploads and the thumbnail renders.

**Proves:** Supabase Storage upload, the per-user RLS path, and the signed URL
replacing `getDownloadURL()`.

**Heads-up — known change:** the progress bar will **jump 0 → 100** rather than
fill smoothly. Firebase exposed a byte-progress stream; the Supabase Dart
client has none. Not a bug, but tell me if it looks broken to you.

---

## 11. Offline

**Do:** turn on Airplane Mode → edit a customer's name → wait a moment → turn
wifi back on.

**Expect:** the edit sticks while offline and syncs when you reconnect.

**Proves:** the offline queue. **This is entirely new code.** RTDB persisted
writes and replayed them inside the SDK; Supabase has no equivalent, and the
`sync_queue` box this app shipped was never actually wired up.

**I check:** the change reached Postgres after reconnect.

---

## 12. Migrated user sign-in — the last unknown

**Do:** sign out. Sign in as one of your **existing** users with the password
they have always used.

**Expect:** it just works, with no mention of migration.

**Proves:** the password bridge. Firebase scrypt hashes cannot be imported, so
these accounts have no Supabase password. On the first failed sign-in the app
silently asks the backend to verify the old password against Firebase, copies
it across, and retries.

**I check:** `password_migrated_at` was stamped on that profile — the marker
that the crossing happened and cannot be repeated.

---

## Then

Free-roam the app and look for anything that feels wrong. The 90-screen
regression is the real remaining work, but these twelve steps cover every layer
the migration touched.
