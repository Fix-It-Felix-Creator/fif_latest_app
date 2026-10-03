# Subscription Tests — Automation

An end-to-end test runner that exercises every backend path of the
subscription flow against the **deployed** `fifcloud` Cloud Function,
using real Firebase Auth + real Stripe test mode.

Run it before every deploy, before every release, or whenever you touch
the Stripe code path.

```bash
cd functions
npm run test:subs
```

Expected output on a green run:

```
Backend: https://europe-west1-fifcloud.cloudfunctions.net/api
Project: fifcloud
Test user: subscription-tests@fif.test
Session UID: …

Auth + health
  GET /ping without token → 401 ... ok (120ms)
  GET /ping with valid token → 200 ... ok (85ms)
  POST with malformed token → 401 ... ok (92ms)

Create subscription
  monthly business VIP → 200, recurring sub created ... ok (2300ms)
  yearly tradesman Plus → 200, yearly price ... ok (2100ms)
  missing accountType → 400 ... ok (80ms)
  missing planType → 400 ... ok (78ms)
  invalid billing cycle → 400 ... ok (82ms)
  unknown plan → 404 ... ok (440ms)
  no auth token → 401 ... ok (75ms)

Cancel subscription
  cancel without subscription → 404 ... ok (310ms)
  cancel at period end → sub marked cancel_at_period_end ... ok (3200ms)
  cancel immediately → Stripe sub canceled + RTDB cancelled ... ok (2900ms)

Webhook
  missing stripe-signature → 400 ... ok (70ms)
  invalid stripe-signature → 400 ... ok (72ms)
  valid signature + subscription.deleted → marks cancelled in RTDB ... ok (550ms)

One-off PaymentIntent
  valid amount → 200 clientSecret ... ok (1100ms)
  zero amount → 400 Invalid amount ... ok (78ms)

Cleanup
  ✓ Stripe subscriptions + customers removed

17/17 passed
✓ All tests passed
```

---

## What's covered

| Area | Happy path | Error paths |
|---|---|---|
| **Auth middleware** | ✓ valid token → 200 | ✓ missing token, ✓ malformed token |
| **POST /subscriptions/create-with-payment-sheet** | ✓ business VIP monthly, ✓ tradesman Plus yearly | ✓ missing `accountType`, ✓ missing `planType`, ✓ invalid `billingCycle`, ✓ unknown plan (404), ✓ no token (401) |
| **POST /subscriptions/cancel** | ✓ cancel at period end, ✓ cancel immediately | ✓ no subscription → 404 |
| **POST /stripe/webhook** | ✓ signed `customer.subscription.deleted` writes RTDB | ✓ missing signature, ✓ invalid signature |
| **POST /payments/create-intent** | ✓ valid amount | ✓ zero amount → 400 |

Each test also **verifies state at both sides** — Stripe (via the real API) and RTDB (via `firebase-admin`) — not just the HTTP response. For example, the cancel tests pull the Stripe Subscription object back and assert `cancel_at_period_end === true`.

---

## Prerequisites

### 1. Firebase Admin Credentials (one-time setup)

The test harness uses the Admin SDK to seed the test user and verify RTDB writes.

```bash
gcloud auth application-default login
```

When the browser opens, sign in with a Google account that has **Owner / Editor** access to the `fifcloud` Firebase project.

Alternative — download a service-account JSON and set:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/secrets/fifcloud-sa.json
```

### 2. Credentials in `functions/scripts/.secrets.local`

Copy the example if you haven't already:

```bash
cp scripts/.secrets.local.example scripts/.secrets.local
```

Then ensure these fields are set:

```bash
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
STRIPE_PUBLISHABLE_KEY="pk_test_..."        # not required for tests, but harmless
FIREBASE_PROJECT="fifcloud"

# ── Test-only fields ──
FIREBASE_WEB_API_KEY="AIzaSy..."            # Android apiKey from firebase_options.dart
TEST_USER_EMAIL="subscription-tests@fif.test"
TEST_USER_PASSWORD="TestPass-2026!"
```

`.secrets.local` is gitignored — it never leaves your machine.

### 3. The Stripe webhook endpoint exists in test mode

The webhook signature tests need your `STRIPE_WEBHOOK_SECRET` to match what Stripe Dashboard shows for your registered webhook endpoint. If you've never registered a webhook, follow §3 of `subscription-testing.md`.

---

## Running the suite

```bash
cd functions
npm run test:subs
```

The runner will:

1. **Bootstrap a dedicated test user** — creates `subscription-tests@fif.test` in Firebase Auth if missing, seeds a minimal `users/{uid}` record (verified tradesman).
2. **Sign that user in via Auth REST** to mint a real Firebase ID token.
3. **Run all tests sequentially** against the deployed backend.
4. **Clean up Stripe** — cancels every subscription attached to the test user's Stripe customer, then deletes the customer.
5. **Clear `users/{uid}/subscription`** — leaves the test user record intact so subsequent runs are fast.

Each test prints `ok (NN ms)` or `FAIL` + the error message. Exit code is non-zero on any failure so CI can use it directly.

---

## Adding a new test

Edit `functions/tests/subscription.test.ts` and add another `test(...)` call. Assertions available from `runner.ts`:

```ts
expectStatus(actual, expected);       // HTTP code
expectEqual(actual, expected);        // strict ===
expectTruthy(value);                  // asserts definedness
expectIncludes(haystack, needle);     // substring match
expectStartsWith(actual, prefix);     // useful for ids (sub_, pi_, ...)
```

Two helpers for talking to the backend:

```ts
await createSubscription(session, { accountType, planType, billingCycle });
await cancel(session, immediate);
```

…and a low-level escape hatch:

```ts
await post<ResponseShape>("/path", { token: session.idToken, body: {...} });
```

For RTDB checks, use `firebase-admin`:

```ts
import { getDatabase } from "firebase-admin/database";
const snap = await getDatabase().ref(`users/${session.uid}/subscription/member`).get();
expectEqual(snap.val().status, "active");
```

---

## Troubleshooting

### `error: ApplicationDefaultCredentialsError`
You haven't run `gcloud auth application-default login` (or your token expired). Re-run it.

### `signInWithPassword failed: 400 EMAIL_NOT_FOUND`
The test user record was deleted but the password changed. Easiest fix:
```bash
firebase auth:delete <UID> --project fifcloud
```
…and re-run. The suite recreates the user on the next run.

### `Plan not configured: business/vip`
The Stripe Price IDs aren't in RTDB `config/subscriptions/...`. Re-run the catalog sync (see `docs/subscription-testing.md` §0.4).

### `401 Unauthorized: Invalid token` on every test
Firebase project mismatch — your deployed function is validating tokens from a **different** Firebase project than the one `FIREBASE_WEB_API_KEY` belongs to. Check that `FIREBASE_PROJECT=fifcloud` and the API key in `.secrets.local` is from `fifcloud`'s `firebase_options.dart`.

### Webhook signature test fails with 400
Your local `STRIPE_WEBHOOK_SECRET` doesn't match the function's Secret Manager version. Fix:
```bash
./scripts/deploy.sh
```
(That syncs whatever's in `.secrets.local` to Secret Manager and redeploys.)

### Test takes >10s per subscription scenario
Cold start on the function after a long idle. Happens once — subsequent tests in the same run reuse the warm instance.

---

## Extending to CI

The test command returns a non-zero exit code on failure, so it drops into any CI system:

```yaml
# .github/workflows/subscription-tests.yml (example)
- uses: actions/setup-node@v4
  with:
    node-version: '22'
- run: cd functions && npm ci
- name: Run subscription tests
  env:
    STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
    STRIPE_WEBHOOK_SECRET: ${{ secrets.STRIPE_WEBHOOK_SECRET }}
    FIREBASE_WEB_API_KEY: ${{ secrets.FIREBASE_WEB_API_KEY }}
    TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
    TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
    GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GCP_SA_JSON_PATH }}
  run: cd functions && npx tsx tests/subscription.test.ts
```

Don't wire this to production Stripe / Firebase — CI must only hit the test-mode credentials above.

---

## Files

```
functions/
  tests/
    runner.ts                  # tiny test harness + assertions
    setup.ts                   # session bootstrap, cleanup, webhook signing
    subscription.test.ts       # the main suite
  scripts/
    run-tests.sh               # wrapper that loads .secrets.local and runs tsx
  package.json                 # "test:subs" script
```

No Jest, no Mocha, no `.test.*` globbing — one file, one `main()`, tested sequentially for readable logs. Total harness is ~500 lines.
