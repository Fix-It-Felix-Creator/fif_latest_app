# In-App Purchase migration (Stripe → StoreKit / Play Billing)

App Store rejected the build because subscriptions were sold through Stripe.
Apple requires **In-App Purchase** for any digital subscription consumed in
the app; Google Play has the same rule (Play Billing). This document tracks
the migration and — most importantly — the **manual steps you must do**
yourself in App Store Connect / the Apple Developer portal, because they
can't be scripted.

Decisions taken (2026‑05‑23):

- Replace Stripe **everywhere** with the official `in_app_purchase` plugin
  (iOS = StoreKit 2, Android = Play Billing). Stripe is fully removed.
- **Server-side validation**: a Cloud Function validates the StoreKit
  transaction with Apple's App Store Server API, and an **App Store Server
  Notifications V2** webhook keeps `users/{uid}/subscription/member` in RTDB
  in sync (renew / cancel / refund / expire). This mirrors the old
  "Stripe-webhook-is-the-source-of-truth" model.
- **Member plans only** for now (the tools add-on is unchanged / later).
- The free **30-day trial stays server-side** (`activateTrial`). It takes no
  money, so Apple does not require IAP for it. Only the paid **Subscribe**
  and **Cancel** paths change.

Shipping surface today is tiny: one plan, **Standard**, monthly or yearly.

---

## Product identifiers (must match EXACTLY in App Store Connect)

| Plan              | Product ID                                       | Price   |
|-------------------|--------------------------------------------------|---------|
| Standard Monthly  | `com.techkushx.fixitfelixpro.standard.monthly`   | £9.99   |
| Standard Yearly   | `com.techkushx.fixitfelixpro.standard.yearly`    | £99.99  |

Both belong to ONE **subscription group** (e.g. "Fix It Felix Pro") so Apple
handles upgrade/downgrade (monthly ⇄ yearly) and cross-grade proration for us.

App bundle ID: `com.techkushx.fixitfelixpro`.

---

## ✅ MANUAL STEPS — iOS (do these yourself; nothing in code can do them)

### A. Apple Developer portal — enable the capability
1. https://developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.
2. Open App ID **com.techkushx.fixitfelixpro**.
3. Tick **In-App Purchase** (it's on by default for paid Apple Developer
   accounts) and Save. No provisioning-profile regeneration is needed for IAP.
   - You do NOT need to add anything to `Runner.entitlements` — IAP has no
     entitlement key. (Sign in with Apple + Push stay as they are.)

### B. App Store Connect — Paid Apps Agreement & banking
4. App Store Connect → **Business** → Agreements: make sure the **Paid
   Applications Agreement** is *Active*, with **Bank** and **Tax** details
   completed. IAP returns no products until this is Active — this is the #1
   cause of "products not loading".

### C. App Store Connect — create the subscriptions
5. My Apps → Fix It Felix Pro → **Subscriptions** (under Monetization).
6. Create a **Subscription Group**: Reference Name `Fix It Felix Pro`.
7. Add subscription **Standard Monthly**:
   - Product ID: `com.techkushx.fixitfelixpro.standard.monthly`
   - Duration: 1 Month, Price: £9.99 (pick the GBP tier).
   - Add a **Localization** (display name "Standard", description).
8. Add subscription **Standard Yearly** in the **same group**:
   - Product ID: `com.techkushx.fixitfelixpro.standard.yearly`
   - Duration: 1 Year, Price: £99.99.
9. For each: add the **Review screenshot** + review notes (Apple requires a
   screenshot of the paywall). Set availability to all your territories.
10. (Optional, later) If you want Apple's native free trial instead of the
    server trial, add an **Introductory Offer → Free, 1 month** on each
    product. Not required for this migration.
> New subscriptions sit in "Missing Metadata" / "Ready to Submit" — that's
> fine; they're purchasable in **Sandbox** immediately once the Paid Apps
> Agreement is Active.

### D. App Store Server API key (for server-side validation)
11. App Store Connect → **Users and Access → Integrations → In-App Purchase**
    (App Store Server API). Click **Generate In-App Purchase Key** (or use the
    "In-App Purchase" key type).
12. Give it a name, **Download the `.p8`** (you can only download once), and
    note the **Key ID** and the **Issuer ID** shown on that page.
13. Note your app's **Apple ID (App ID number)**: App Store Connect → App →
    App Information → "Apple ID" (a number like `1234567890`).
14. Hand me these 4 values (or set them as Cloud Function secrets yourself —
    see "Backend secrets" below):
    - `APPSTORE_KEY_ID`
    - `APPSTORE_ISSUER_ID`
    - `APPSTORE_BUNDLE_ID` = `com.techkushx.fixitfelixpro`
    - `APPSTORE_APP_APPLE_ID` = the numeric Apple ID from step 13
    - the `.p8` file contents → secret `APPSTORE_PRIVATE_KEY`

### E. App Store Server Notifications V2 (renew / cancel / refund sync)
15. App Store Connect → App → **App Information → App Store Server
    Notifications**.
16. Set **Production Server URL** and **Sandbox Server URL** to the deployed
    Cloud Function endpoints (Version **2**):
    - Sandbox / staging:  `https://europe-west1-fifcloud.cloudfunctions.net/api/iap/apple/notifications`
    - Production:          `https://europe-west1-fifcloud.cloudfunctions.net/apiProd/iap/apple/notifications`
    (Confirm the exact host with `firebase deploy` output — see backend below.)

### F. Sandbox tester (to test purchases without real money)
17. App Store Connect → Users and Access → **Sandbox → Test Accounts** → add a
    tester (use an email you don't already use as an Apple ID).
18. On the test device: Settings → App Store → scroll to **Sandbox Account**
    and sign in with the tester (iOS 18 puts it under Developer settings too).
    Do NOT sign your real Apple ID out of the main App Store section.

### G. Local StoreKit testing in Xcode (optional but fast)
19. A `ios/Runner/FixItFelixPro.storekit` config file is included. In Xcode:
    Product → Scheme → Edit Scheme → Run → Options → **StoreKit Configuration**
    → pick `FixItFelixPro.storekit`. This lets you test the purchase UI on the
    simulator with no App Store Connect round-trip. Turn it OFF to test against
    real Sandbox.

---

## ✅ MANUAL STEPS — Android (Play Billing)

The client + backend are implemented (`/iap/google/validate` +
`/iap/google/notifications`). The Play Billing library and the
`com.android.vending.BILLING` permission are added automatically by the
`in_app_purchase` plugin — no manifest edit needed. You must do the Play
Console / Google Cloud setup:

### A. Play Console — create the subscriptions
1. Play Console → your app → Monetize → Products → **Subscriptions** →
   create two subscriptions with **exactly** these product IDs, each with a
   single **base plan** (auto-renewing), in GBP:
   - `com.techkushx.fixitfelixpro.standard.monthly` — base plan period **P1M**, £9.99
   - `com.techkushx.fixitfelixpro.standard.yearly` — base plan period **P1Y**, £99.99
   Activate each base plan. (Keep one base plan per product — the client
   buys the default offer; multiple offers would need an offer token.)
2. The app must be uploaded to at least an **internal testing** track for
   products to be queryable, and your tester added to that track + the
   **License testing** list (Play Console → Setup → License testing) so test
   purchases are free.

### B. Play Developer API — service account for validation
3. Play Console → Setup → **API access** → link a Google Cloud project.
4. In Google Cloud Console → IAM & Admin → **Service Accounts**: create one,
   then **create a JSON key** and download it.
5. Back in Play Console → API access → grant that service account access with
   the **View financial data / Manage orders and subscriptions** permission
   (enough to call `purchases.subscriptionsv2.get`).
6. Hand me (or set yourself) the secrets:
   - `GOOGLE_PLAY_SA_JSON` = the full contents of the downloaded JSON key
   - `ANDROID_PACKAGE_NAME` = `com.techkushx.fixitfelixpro`

### C. Real-time Developer Notifications (renew / cancel / refund sync)
7. Google Cloud → Pub/Sub → create a **topic**, e.g. `play-rtdn`.
8. Grant Google Play permission to publish to it: add member
   `google-play-developer-notifications@system.gserviceaccount.com` as
   **Pub/Sub Publisher** on that topic.
9. Create a **push subscription** on the topic with the endpoint:
   - Staging:    `https://europe-west1-fifcloud.cloudfunctions.net/api/iap/google/notifications`
   - Production: `https://europe-west1-fifcloud.cloudfunctions.net/apiProd/iap/google/notifications`
   (One backend serves both stores; pick the function that matches the build
   the Android app targets.)
10. Play Console → Monetization setup → **Real-time developer notifications**:
    set the **Topic name** to your topic's full path and **Send a test
    notification** (it should hit the endpoint and log a `test notification`).

---

## Backend secrets (Cloud Functions)

Set these once (staging + prod share the same keys):

```bash
# Apple (iOS)
firebase functions:secrets:set APPSTORE_KEY_ID
firebase functions:secrets:set APPSTORE_ISSUER_ID
firebase functions:secrets:set APPSTORE_BUNDLE_ID
firebase functions:secrets:set APPSTORE_PRIVATE_KEY   # paste the whole .p8 incl. BEGIN/END lines

# Google (Android)
firebase functions:secrets:set GOOGLE_PLAY_SA_JSON    # paste the whole service-account JSON
firebase functions:secrets:set ANDROID_PACKAGE_NAME   # com.techkushx.fixitfelixpro
```

> Note: `APPSTORE_APP_APPLE_ID` isn't required by the current code (we
> never verify the notification's own JWS signature — we re-query Apple's
> authenticated API instead), but keep the numeric Apple ID handy in case
> a future change adds signature verification.

The old Stripe secrets (`STRIPE_*`) are no longer referenced and can be
deleted after deploy:
```bash
firebase functions:secrets:destroy STRIPE_SECRET_KEY
firebase functions:secrets:destroy STRIPE_SECRET_KEY_LIVE
firebase functions:secrets:destroy STRIPE_WEBHOOK_SECRET
firebase functions:secrets:destroy STRIPE_WEBHOOK_SECRET_LIVE
```

---

## RTDB entitlement shape (unchanged path, provider-agnostic fields)

`users/{uid}/subscription/member`:
```
provider:              "apple" | "google" | "trial"   (was implicitly "stripe")
productId:             "com.techkushx.fixitfelixpro.standard.monthly"
originalTransactionId: "<stable store sub id>"  ← Apple originalTransactionId
                        or Play purchaseToken (replaces stripeSubscriptionId)
status:                "active" | "cancelled" | "expired"
autoRenew:             bool
cancelAtPeriodEnd:     bool
startDate / endDate:   ISO strings (endDate = expiry)
planType/accountType/billingCycle/name/price: as before
```
Indexes for notification→user lookup (store notifications don't carry our
uid), both written at validate time:
- `iap/appleOriginalTxnToUid/{originalTransactionId} = uid`
- `iap/googleTokenToUid/{sha256(purchaseToken)} = uid`

The Flutter `MemberSubscriptionModel.isPaid` now returns true when EITHER
`originalTransactionId` (Apple) or the legacy `stripeSubscriptionId` is set.

---

## Test checklist (Sandbox)

- [ ] Products load on the paywall (if empty → Paid Apps Agreement not Active,
      or product IDs mismatch, or wrong bundle ID).
- [ ] Buy Standard Monthly → Apple sheet → entitlement appears in RTDB →
      app navigates to home.
- [ ] Kill + relaunch → still entitled (gate passes).
- [ ] "Restore purchases" re-grants on a fresh install.
- [ ] Cancel in App Store → DID_CHANGE_RENEWAL_STATUS notification →
      `autoRenew=false`, card shows "Cancels on …".
- [ ] Let sandbox sub expire (sandbox renews fast) → EXPIRED notification →
      gate re-locks to the paywall.
- [ ] Refund (App Store Connect sandbox) → REFUND notification → access revoked.

## Test checklist (Android — license testers / internal track)

- [ ] App installed from the **internal testing** track by a license tester.
- [ ] Products load on the paywall (if empty → not on a track yet, product
      IDs mismatch, base plan inactive, or service account lacks access).
- [ ] Buy Standard Monthly → Play sheet (test card) → `/iap/google/validate`
      writes entitlement → app navigates to home.
- [ ] Kill + relaunch / reinstall → still entitled ("Restore purchases").
- [ ] Cancel in Play subscriptions → RTDN → `autoRenew=false`, card shows
      "Cancels on …".
- [ ] Let the (fast) test sub expire → RTDN → gate re-locks to the paywall.
- [ ] Refund / void in Play Console → voidedPurchase RTDN → access revoked.
</content>
