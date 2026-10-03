# Subscription Plan — End-to-End Testing Guide

A step-by-step runbook for verifying the full subscription lifecycle. Follow
it top-to-bottom the first time; later you only need to revisit the section
matching the scenario you're checking.

All testing is against **Stripe test mode** (`pk_test_…` / `sk_test_…`). No
real cards, no real charges.

---

## 0. Setup checklist (run once)

Before any functional test, confirm all three layers are live.

### 0.1 Remote Config (Flutter reads this at startup)

```
Firebase Console → fifcloud → Remote Config → Parameters
```

`dev_variable` value should contain:

| Field | Expected |
|---|---|
| `stripeBackendUrl` | `https://europe-west1-fifcloud.cloudfunctions.net/api` |
| `stripePublishableKey` | starts with `pk_test_` |
| `databaseUrl` | `https://fifcloud-default-rtdb.europe-west1.firebasedatabase.app` |

### 0.2 Secret Manager (backend reads these at cold start)

```bash
firebase functions:secrets:access STRIPE_SECRET_KEY --project fifcloud
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET --project fifcloud
```

- `STRIPE_SECRET_KEY` must start with `sk_test_`.
- `STRIPE_WEBHOOK_SECRET` must start with `whsec_` (not the placeholder).

### 0.3 Stripe Dashboard webhook

```
Stripe Dashboard (test mode) → Developers → Webhooks
```

- Endpoint URL: `https://europe-west1-fifcloud.cloudfunctions.net/api/stripe/webhook`
- Subscribed events: `invoice.payment_succeeded`, `invoice.payment_failed`,
  `customer.subscription.created`, `customer.subscription.updated`,
  `customer.subscription.deleted`
- Signing secret matches the value in Secret Manager
- Recent deliveries show 200 responses

### 0.4 Plan catalog in RTDB

```
Firebase Console → Realtime Database → fifcloud-default-rtdb
→ config/subscriptions/business/business_vip
```

Required fields present:
- `stripeProductId`
- `stripePriceIdMonthly`
- `stripePriceIdYearly`

Same check for `config/subscriptions/tradesman/tradesman_plus` and
`config/subscriptions/tradesman/tradesman_advance`.

### 0.5 Health check

```bash
curl -i https://europe-west1-fifcloud.cloudfunctions.net/api/ping
# Expected: HTTP/2 401  {"message":"Unauthorized: Missing token"}
```

401 is correct — it proves the function is running and auth middleware
is active. A 200 here would mean auth is broken.

---

## 1. Purchase a subscription (happy path)

### 1.1 Precondition
- Account exists and is `verified`.
- `users/{uid}/subscription/member` is absent or has `status != "active"`.

### 1.2 Steps
1. Hot-restart the Flutter app (don't hot-reload — Remote Config caches).
2. Sign in. Auth routing should land on `/businessSubscription` or
   `/tradesmanSubscription` because the user has no active member sub.
3. Pick **Monthly** or **Yearly** toggle.
4. Tap **Subscribe**.
5. Stripe payment sheet appears.
6. Enter test card:
   - Card: `4242 4242 4242 4242`
   - Expiry: any future date (e.g., `12/30`)
   - CVC: any 3 digits (e.g., `123`)
   - Postcode: any valid UK postcode (e.g., `SW1A 1AA`)
7. Tap **Pay**.

### 1.3 Expected
- Payment sheet dismisses.
- Screen swaps to **Subscription Activated** with:
  - green circle check
  - plan name
  - billing cycle ("Billed monthly" / "Billed yearly")
  - price (e.g., `£100/month`)
- App bar is **hidden**.
- **Continue** button is anchored at the bottom.

### 1.4 Verify persistence
- **Stripe Dashboard → Customers**: new customer exists with metadata
  `firebaseUid = <your uid>`.
- **Stripe Dashboard → Subscriptions**: new subscription with status
  `Active`, next invoice ~1 month out, customer linked.
- **RTDB `users/{uid}/subscription/member`** has:
  ```
  status: "active"
  stripeSubscriptionId: "sub_..."
  stripePriceId: "price_..."
  stripeCustomerId: "cus_..."
  currentPeriodStart: <ms>
  currentPeriodEnd: <ms>
  startDate: "2026-04-19T..."
  endDate: "2026-05-19T..."
  autoRenew: true
  cancelAtPeriodEnd: false
  ```

### 1.5 Continue
Tap **Continue**. Auth routing re-evaluates → lands on `/tradesmanHome`.
The **Current Plan** card shows:
- Plan name + price
- "Renews <date>" (date = `endDate` ≈ 1 month from now)
- **Cancel Subscription** outlined button

---

## 2. Auto-renewal

### 2.1 Fast-forward simulation
You can't wait a month in test mode. Instead, simulate invoice payment:

1. Stripe Dashboard → Subscriptions → select your sub.
2. **Actions** dropdown → **Create test invoice** → Finalize → Pay.
3. Stripe sends `invoice.payment_succeeded`.

### 2.2 Expected
- Webhook receives event (check Stripe Dashboard → Webhooks → deliveries,
  200 OK).
- RTDB `currentPeriodStart` and `currentPeriodEnd` advance to the new window.
- `startDate`/`endDate` update to the new ISO strings.
- Home card's "Renews <date>" shows the new date.
- `status` stays `"active"`.

### 2.3 Watch Cloud Function logs live

```bash
firebase functions:log --project fifcloud --only api
```

Look for:
```
Stripe event  { type: 'invoice.payment_succeeded', id: 'evt_...' }
```

---

## 3. Cancellation (at period end — default flow)

### 3.1 Steps
1. On home screen, tap **Cancel Subscription**.
2. Confirmation dialog: tap **Yes, Cancel**.

### 3.2 Expected (client side)
- Button shows inline spinner + "Cancelling..." briefly.
- Card updates:
  - "Auto-renews <date>" → gone
  - Amber banner appears: "Cancels on <date>"
  - **Cancel Subscription** button — gone
- Info toast: "Your plan stays active until the end of the current period."
- `status` still `"active"` (user keeps access until period end).

### 3.3 Expected (Stripe side)
- Stripe Dashboard → Subscriptions → your sub.
- Status badge: **Canceling** (orange).
- "Cancels at period end: 19 May 2026".

### 3.4 Expected (RTDB)
```
autoRenew: false
cancelAtPeriodEnd: true
status: "active"        ← still active
endDate: "2026-05-19..."
```

### 3.5 Simulate the period ending
1. Stripe Dashboard → Subscriptions → your sub → **Actions** → **Cancel now**.
2. Stripe sends `customer.subscription.deleted`.

### 3.6 Expected after deletion
- Webhook marks `status: "cancelled"` in RTDB.
- Home card status dot goes **grey**, label "Cancelled".
- Amber "Cancels on" banner disappears (card is no longer active).
- Sign out + sign in → auth routing sends user back to
  `/businessSubscription` or `/tradesmanSubscription` because there's no
  active member sub.

---

## 4. Cancellation (immediate — admin override)

Not exposed in the UI. Useful for testing revocation flow.

```bash
# Obtain the user's Firebase ID token (from DevTools, Flutter logs, etc.),
# then:
curl -X POST https://europe-west1-fifcloud.cloudfunctions.net/api/subscriptions/cancel \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"immediate": true}'
```

### Expected
- Stripe status: **Canceled** (immediately).
- Webhook fires `customer.subscription.deleted`.
- RTDB: `status: "cancelled"`, `autoRenew: false`.
- Home card flips to Cancelled state instantly.

---

## 5. Failure scenarios

### 5.1 Card declined (payment sheet)
Test card: `4000 0000 0000 0002` (generic decline).

Expected:
- Payment sheet shows "Your card has been declined."
- Flutter stays on the plan-picker screen.
- No Stripe Subscription created (check Dashboard).
- No RTDB write.
- Toast may show an error depending on the Stripe UI path.

### 5.2 Authentication required (3D Secure)
Test card: `4000 0025 0000 3155`.

Expected:
- Payment sheet triggers 3DS challenge (test UI in Stripe test mode).
- Tap "Complete authentication".
- Payment succeeds, subscription activates, flow matches §1.

### 5.3 Recurring payment fails (past due)
After a successful initial payment, cause the next invoice to fail:

1. Stripe Dashboard → Customers → your customer → Payment methods.
2. Remove the default card (or replace with `4000 0000 0000 0341`, which
   succeeds once then fails on renewal).
3. Dashboard → Subscriptions → your sub → **Actions** → **Create test invoice**
   → Finalize. Payment fails.

Expected:
- `invoice.payment_failed` webhook fires.
- RTDB `status: "past_due"`.
- Home card status dot orange, label "Past Due".
- Cancel button still shown (user can intervene / update card).

### 5.4 Webhook secret mismatch
If someone rotates the webhook signing secret in Stripe but doesn't
update Secret Manager, the endpoint rejects events:

Expected:
- Stripe Dashboard → Webhooks → recent deliveries show 400 responses.
- No RTDB changes.
- Function logs show `Webhook handler failed` with signature errors.

Fix: rerun `./scripts/deploy.sh` after pasting the new `whsec_...` into
`scripts/.secrets.local`.

---

## 6. Edge cases

### 6.1 Existing subscriber signs in again
- Sign out.
- Sign back in.
- Auth routing reads `users/{uid}/subscription/member.status`.
- If `active` → `/tradesmanHome` directly.
- If `cancelled`/missing → `/tradesmanSubscription` or
  `/businessSubscription`.

### 6.2 Two devices for the same user
- Subscribe on device A.
- Open app on device B → `/tradesmanHome` (routing is server-driven;
  device B reads the same RTDB record).
- Cancel on device A → RTDB stream pushes to device B; card on B flips
  without any local action.

### 6.3 Webhook retry after transient failure
If the function errors and returns non-2xx, Stripe retries with
exponential backoff (up to 3 days). Check Dashboard → Webhooks → your
endpoint → delivery attempts.

Test by temporarily returning `res.status(500)` in the webhook handler,
redeploying, firing a test event, then reverting.

### 6.4 Customer search by `firebaseUid`
`ensureCustomer` in `functions/src/lib/customer.ts` looks up Stripe
customers by metadata. Verify duplicates aren't created:

1. Subscribe once.
2. Cancel + delete RTDB sub record.
3. Subscribe again.
4. Stripe Dashboard → Customers → should still be **one** customer
   for your Firebase UID, just with two subscriptions attached.

### 6.5 Remote Config change mid-session
- Change `stripePublishableKey` in Remote Config to an empty string.
- The running app keeps the old key (in-memory).
- On next cold start it fetches the new (empty) key → Stripe fails to
  initialise → Subscribe button errors with "Invalid or missing Stripe
  publishable key" in logs.
- Restore the key + hot-restart → works again.

---

## 7. Stripe test card reference

| Card number | What happens |
|---|---|
| `4242 4242 4242 4242` | Succeeds, no 3DS |
| `4000 0025 0000 3155` | Requires 3DS authentication |
| `4000 0000 0000 9995` | Insufficient funds |
| `4000 0000 0000 0002` | Generic decline |
| `4000 0000 0000 0069` | Expired card |
| `4000 0000 0000 0127` | Incorrect CVC |
| `4000 0000 0000 0119` | Processing error |
| `4000 0000 0000 0341` | Succeeds on attach, fails on charge (great for past_due) |

Any future expiry works (e.g., `12/30`). Any 3-digit CVC. Any valid UK
postcode (e.g., `SW1A 1AA`).

---

## 8. Where to look when something's wrong

| Symptom | First place to check |
|---|---|
| Subscribe button does nothing | Flutter debug console — look for `NativeStripeService:` logs |
| "Unauthorized: Invalid token" | Firebase Auth project mismatch — Remote Config `stripeBackendUrl` vs token source |
| `{"message":"Invalid amount"}` | Backend logs for `createSubscriptionWithPaymentSheet failed` |
| Payment succeeds but nothing in RTDB | Webhook deliveries + function logs — usually signing secret is wrong |
| Card on home doesn't update | Check `AuthBloc` stream — did `AuthUserDetailsChanged` fire? |
| Cancel button errors | `firebase functions:log --only api` — look for `cancelSubscription failed` |
| Home routes to sub screen even though I have active sub | RTDB `users/{uid}/subscription/member.status` not `active` |

**Useful commands while testing:**

```bash
# Tail Cloud Function logs
firebase functions:log --project fifcloud --only api

# Tail Flutter logs with filter
flutter logs | grep -E "Stripe|Subscription|Auth"

# Fire a test webhook from CLI
stripe trigger payment_intent.succeeded   # (requires Stripe CLI)

# Inspect a user's subscription in RTDB
curl "https://fifcloud-default-rtdb.europe-west1.firebasedatabase.app/users/<UID>/subscription/member.json?auth=$(gcloud auth print-access-token)"
```

---

## 9. Resetting a user between tests

Stripe + RTDB need to be cleared to re-run the purchase flow for the same account.

### 9.1 Via the app
- Open subscription screen → tap **Cancel** → on period-end simulation
  (§3.5) the sub is fully cancelled.

### 9.2 Via Stripe + RTDB (fastest for repeated testing)
1. Stripe Dashboard → Subscriptions → your sub → Cancel now.
2. Firebase Console → RTDB → `users/<UID>/subscription` → delete.
3. Force-close the app, hot-restart. Sign in → lands on plan-picker again.

### 9.3 Cloud Function quick reset helper
If repeated resets get annoying, add a test-only endpoint
`POST /debug/reset-subscription` that does steps 9.2 server-side.
Deliberately not added in production — keep it gated behind a debug
flag if you build it.

---

## 10. Acceptance criteria (one-page summary)

A release is subscription-ready when **all** of these pass:

- [ ] Purchase flow produces an **Active** Stripe Subscription (not just a
      one-off PaymentIntent).
- [ ] After purchase, home shows the correct plan name, price, renewal
      date, and Cancel button.
- [ ] Cancel tap → Stripe Subscription enters "cancel at period end"
      state; UI reflects it; user keeps access until `endDate`.
- [ ] On period end, `customer.subscription.deleted` webhook fires and
      RTDB status flips to `cancelled`.
- [ ] A cancelled user signing in is redirected back to the subscription
      screen.
- [ ] `invoice.payment_failed` results in `status: past_due` and the home
      card reflects it.
- [ ] No raw amount is sent from client to server for plan pricing — the
      server reads the Stripe Price from `config/subscriptions` in RTDB.
- [ ] The STRIPE_SECRET_KEY never appears in a request/response body,
      client logs, or a committed file.
