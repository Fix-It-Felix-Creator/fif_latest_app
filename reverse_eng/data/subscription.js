window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'IDENTITY',
  nav: 'Subscription & IAP',
  kicker: 'trial, purchase, validate, renew',
  title: 'Subscription and In-App Purchase',
  summary: `
    One tier — <strong>Standard</strong>, monthly or yearly — behind a one-time 30-day free
    trial. Payment is In-App Purchase only: StoreKit on iOS, Play Billing on Android. The
    single rule that governs the whole subsystem is that the app <strong>never</strong> grants
    access from a client receipt. The device sends a transaction id to a Cloud Function, the
    function re-queries the store's authenticated API, and only that server response is
    written to the database the gate reads.`,
  blocks: [
    {
      title: 'Products and prices',
      html: `
<table>
  <tr><th></th><th>iOS product id</th><th>Android product id</th><th>Price shown</th></tr>
  <tr><td>Standard monthly</td><td><code>com.techkushx.fixitfelixpro.standard.monthly</code></td><td><code>fixitfelixpro.standard.monthly</code></td><td>£12.99 / month</td></tr>
  <tr><td>Standard yearly</td><td><code>com.techkushx.fixitfelixpro.standard.yearly</code></td><td><code>fixitfelixpro.standard.yearly</code></td><td>£129.99 / year</td></tr>
</table>
<p>
  The ids differ per platform on purpose: Google Play caps subscription product ids at 40
  characters, and the <code>com.techkushx.</code> prefix would overflow.
  <code>IapService.standardMonthly</code> switches on <code>Platform.isAndroid</code>, so the
  rest of the code never branches.
</p>`,
    },
    {
      title: 'Pipeline — the free trial (no money, no store)',
      html: `
<p>
  The trial is not an IAP product. It is a server-written record, guarded by a one-shot rule:
  <strong>any</strong> pre-existing <code>subscription/member</code> node — active, expired or
  cancelled — blocks a new trial with a 409. That is what stops a cancel-then-restart-trial
  loop.
</p>`,
      caption: 'Start free trial → activateTrial → RTDB → gate reopens',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant CP as ChoosePlanScreen
  participant FA as Firebase Auth
  participant FN as POST /subscriptions/activate-trial
  participant DB as RTDB users/{uid}/subscription/member
  participant GATE as handleAuthentication()

  U->>CP: tap Start free trial
  CP->>FA: getIdToken()
  CP->>FN: POST { planType, accountType, billingCycle }<br/>Authorization: Bearer <id token>
  FN->>FN: verifyFirebaseToken → uid
  FN->>DB: read existing member record
  alt a record already exists (any status)
    DB-->>FN: exists
    FN-->>CP: 409 "You've already used your free trial"
    CP-->>U: toast, paid options remain
  else first time
    DB-->>FN: null
    FN->>DB: write status active, autoRenew true,<br/>startDate now, endDate now + 30 days
    FN-->>CP: 200 success
    CP->>GATE: re-run the gate
    GATE-->>U: /tradesmanHome
  end`,
    },
    {
      title: 'Pipeline — buying a subscription (the full loop)',
      html: `
<p>
  This is the longest pipeline in the app and it crosses four trust boundaries: the app, the
  operating system's purchase sheet, the Cloud Function, and the store's server API. Read it
  as: <em>the store charges the card, the server decides what that means, the database records
  it, the gate reads the database.</em>
</p>
<p>
  Two details are worth flagging. The purchase is tagged with the Firebase uid
  (<code>applicationUserName</code> → Apple's <code>appAccountToken</code> / Play's
  <code>obfuscatedAccountId</code>) so a later server notification can find the user. And the
  transaction is <strong>always</strong> finished, even when verification fails — otherwise
  StoreKit re-delivers it on every launch forever.
</p>`,
      caption: 'Purchase → StoreKit/Play → validate on server → store API → RTDB → home',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant CP as ChoosePlanScreen
  participant IAP as IapService
  participant OS as StoreKit / Play Billing
  participant FN as POST /iap/apple/validate<br/>or /iap/google/validate
  participant API as App Store Server API<br/>or Play Developer API
  participant DB as RTDB subscription/member
  participant GATE as Auth gate

  U->>CP: choose monthly / yearly, tap Subscribe
  CP->>IAP: buy(productIdFor(yearly))
  IAP->>OS: queryProductDetails(id)
  alt product not in the store catalog
    OS-->>IAP: empty
    IAP-->>CP: "isn't available right now"
  else found
    OS-->>IAP: ProductDetails
    IAP->>OS: buyNonConsumable(applicationUserName = uid)
    OS-->>U: native purchase sheet
    U->>OS: confirm and pay
    OS-->>IAP: purchaseStream → PurchaseDetails(purchased)
    IAP->>FN: POST { transactionId, productId,<br/>serverVerificationData } + Bearer token
    Note over IAP,FN: on Android the body is<br/>{ purchaseToken, productId }
    FN->>FN: verifyFirebaseToken → uid
    FN->>API: fetch the authoritative transaction<br/>(the client JWS is never trusted)
    API-->>FN: transaction + renewal state
    FN->>FN: mapProductToPlan(productId)
    alt unknown product
      FN-->>IAP: 400 unknown product
    else known
      FN->>DB: writeEntitlement — status, autoRenew,<br/>periods, planType, provider ids
      FN-->>IAP: 200 success
    end
    IAP->>OS: completePurchase — ALWAYS, even on failure
    IAP-->>CP: IapResult(success)
    CP->>GATE: re-run the gate
    GATE->>DB: read member record
    DB-->>GATE: status active
    GATE-->>U: /tradesmanHome
  end`,
    },
    {
      title: 'Pipeline — restore, manual and silent',
      html: `
<p>
  Apple requires a visible Restore button, so the paywall has one. But requiring a tap on
  every launch was a real bug: a genuine subscriber whose entitlement had not yet been
  re-validated on this device — after a reinstall, after a renewal whose webhook had not
  landed, or with a fast-expiring sandbox subscription — was parked on the paywall.
</p>
<p>
  <code>_tryRestoreEntitlement()</code> fixes it by doing silently exactly what the button
  does, but only when the gate has <em>already</em> decided to reject. Healthy subscribers
  take the fast path and pay zero latency.
</p>`,
      caption: 'Silent restore inside the gate',
      mermaid: `graph TB
  A["_needsSubscription(details) = true"] --> B{"IapService.isAvailable?"}
  B -->|"no"| Z["/choosePlan"]
  B -->|"yes"| C["iap.restore()<br/>→ restorePurchases()"]
  C --> D["store re-delivers past transactions<br/>into purchaseStream"]
  D --> E["_onPurchaseUpdates → _validate()<br/>→ POST /iap/*/validate"]
  E --> F["server writes entitlement to RTDB"]
  C --> G["bounded re-poll<br/>8 attempts x 750ms"]
  G --> H{"getUserDetails(forceRefresh)<br/>now grants access?"}
  H -->|"yes"| I["/tradesmanHome — user never saw the paywall"]
  H -->|"no, after 6s"| Z`,
    },
    {
      title: 'Pipeline — renewals, cancellations and refunds',
      html: `
<p>
  After the first purchase the app is no longer in the loop. Apple and Google call the
  webhooks directly, and neither endpoint sits behind <code>verifyFirebaseToken</code> —
  they cannot present a Firebase ID token.
</p>
<p>
  The security argument for that is written into the code: the notification body is treated as
  a <strong>signal only</strong>. It is decoded to find <em>which</em> subscription changed,
  then the state is re-fetched from the store's authenticated API and only that response is
  written. Because entitlement never derives from the push body, its signature does not have
  to be verified for the endpoint to be safe.
</p>`,
      caption: 'Store server notification → re-query → RTDB',
      mermaid: `sequenceDiagram
  autonumber
  participant ST as Apple / Google servers
  participant FN as POST /iap/apple/notifications<br/>POST /iap/google/notifications
  participant API as Store server API
  participant IDX as RTDB index<br/>originalTransactionId → uid
  participant DB as RTDB subscription/member

  ST->>FN: signed notification (no Firebase auth)
  FN->>FN: decode payload — SIGNAL ONLY
  FN->>FN: extract originalTransactionId / purchaseToken
  FN->>IDX: findUidByOriginalTxn / findUidByGoogleToken
  alt uid not found
    IDX-->>FN: null
    FN-->>ST: 200 (acknowledge, nothing to do)
  else found
    IDX-->>FN: uid
    FN->>API: getSubscriptionState(originalTransactionId)
    API-->>FN: authoritative status + renewal info
    FN->>DB: writeEntitlement
    FN-->>ST: 200
  end
  Note over DB: next app launch, the gate reads<br/>the refreshed record — no client action`,
    },
    {
      title: 'The entitlement record',
      html: `
<p>
  Everything above converges on one node: <code>users/{uid}/subscription/member</code>. It is
  the only thing the gate reads, and its shape deliberately mirrors the old Stripe webhook
  output so the Flutter model did not have to change during the migration.
</p>
<table>
  <tr><th>Field</th><th>Written from</th><th>Notes</th></tr>
  <tr><td><code>status</code></td><td><code>revoked ? cancelled : active ? active : expired</code></td><td>The gate accepts <code>active</code> and <code>trial</code></td></tr>
  <tr><td><code>autoRenew</code></td><td>Store renewal info</td><td>false + active + future endDate = soft cancel, access retained</td></tr>
  <tr><td><code>cancelAtPeriodEnd</code></td><td><code>active && !autoRenew</code></td><td>Drives the Settings copy</td></tr>
  <tr><td><code>currentPeriodStart</code> / <code>End</code></td><td>Store transaction</td><td>Epoch ms</td></tr>
  <tr><td><code>startDate</code> / <code>endDate</code></td><td>Same, ISO strings</td><td><code>endDate</code> in the past re-locks the gate</td></tr>
  <tr><td><code>provider</code>, <code>productId</code>, <code>originalTransactionId</code></td><td>Store</td><td><code>isPaid</code> keys off the store id — the trial writes none, which is how the UI tells trial from paid</td></tr>
  <tr><td><code>planType</code>, <code>accountType</code>, <code>billingCycle</code>, <code>name</code>, <code>price</code></td><td><code>mapProductToPlan()</code></td><td>Falls back to the existing values, then to standard / tradesman / monthly</td></tr>
  <tr><td><code>stripeSubscriptionId</code></td><td>—</td><td>Left null; retained for backward compatibility</td></tr>
</table>`,
    },
    {
      title: 'Compliance features baked into the paywall',
      html: `
<p>
  <code>ChoosePlanScreen</code> carries several elements that exist purely because App Review
  asked for them, and removing any of them would re-trigger a rejection:
</p>
<ul>
  <li><strong>Legal links footer</strong> — tappable Terms of Use (EULA) and Privacy Policy,
      opened externally, plus an auto-renewal disclosure. Required by Guideline 3.1.2(c).</li>
  <li><strong>Restore purchases</strong> — visible, always available.</li>
  <li><strong>Manage subscriptions</strong> — deep-links to
      <code>apps.apple.com/account/subscriptions</code> or the Play equivalent. The app may
      never cancel on the user's behalf; the stores own cancellation.</li>
  <li><strong>Two variants</strong> — a first-time user sees trial + paid; someone whose trial
      has ended sees paid-only with different copy. Reaching the screen from Settings renders
      a back-button variant instead of the sign-out one.</li>
</ul>`,
    },
  ],
});
