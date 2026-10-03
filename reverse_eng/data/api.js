window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PLATFORM',
  nav: 'Cloud Functions API',
  kicker: 'the complete HTTP surface',
  title: 'Cloud Functions — the complete HTTP surface',
  summary: `
    One Express application, built by <code>buildApp(env)</code> and exported twice as
    <code>api</code> (staging) and <code>apiProd</code> (production), plus two background
    database triggers. Routes fall into three authorisation tiers, and the order they are
    registered in <strong>is</strong> the security model — public routes are mounted before the
    Firebase middleware so it never sees them.`,
  blocks: [
    {
      title: 'Middleware order — read this first',
      html: `
<p>
  Express matches in registration order, so this listing is also a decision tree. Anything
  registered after <code>app.use(verifyFirebaseToken)</code> requires a valid Firebase ID token
  issued by this project; anything before it does not.
</p>`,
      caption: 'Express pipeline and the three authorisation tiers',
      mermaid: `graph TB
  REQ["Incoming request"] --> M1["1. runWithEnv(env)<br/>binds staging or production<br/>for the whole async lifetime"]
  M1 --> M2["2. cors({ origin: true })"]
  M2 --> M3["3. express.json({ limit: 1mb })"]

  M3 --> T1["TIER 1 — PUBLIC, token is the auth"]
  T1 --> P1["GET  /q/:token"]
  T1 --> P2["POST /q/:token/respond"]
  T1 --> P3["GET  /i/:token"]
  T1 --> P4["GET  /q/:token/:mode(v|d)/:kind/:id"]
  T1 --> P5["GET  /i/:token/:mode(v|d)/:kind/:id"]

  M3 --> T2["TIER 2 — STORE WEBHOOKS, no Firebase token possible"]
  T2 --> W1["POST /iap/apple/notifications"]
  T2 --> W2["POST /iap/google/notifications"]

  M3 --> M4["4. verifyFirebaseToken<br/>Bearer ID token → req.uid"]
  M4 --> T3["TIER 3 — AUTHENTICATED"]
  T3 --> A1["IAP validate, trial, account,<br/>quotes, invoices, notifications, ping"]
  T3 --> M5["5. requireAdmin<br/>(only on /notifications/send)"]
  M5 --> AD["admin fan-out"]`,
    },
    {
      title: 'Full route table',
      html: `
<table>
  <tr><th>Method + path</th><th>Auth</th><th>Extra gate</th><th>What it does</th></tr>

  <tr><td><code>GET /q/:token</code></td><td>Token</td><td>—</td><td>Server-rendered quote viewer; stamps <code>viewedAt</code> and notifies the owner on first view</td></tr>
  <tr><td><code>POST /q/:token/respond</code></td><td>Token</td><td>—</td><td>Accept / reject; writes the quote status, notifies the owner; 409 if already answered</td></tr>
  <tr><td><code>GET /i/:token</code></td><td>Token</td><td>—</td><td>Read-only invoice viewer</td></tr>
  <tr><td><code>GET /q/:token/:mode/:kind/:id</code></td><td>Token</td><td>—</td><td>Attachment proxy — <code>v</code> inline, <code>d</code> download</td></tr>
  <tr><td><code>GET /i/:token/:mode/:kind/:id</code></td><td>Token</td><td>—</td><td>Same for invoices</td></tr>

  <tr><td><code>POST /iap/apple/notifications</code></td><td>None</td><td>—</td><td>App Store Server Notifications V2 — decode as a signal, re-query Apple, write entitlement</td></tr>
  <tr><td><code>POST /iap/google/notifications</code></td><td>None</td><td>—</td><td>Play Real-time Developer Notifications, same shape</td></tr>

  <tr><td><code>POST /iap/apple/validate</code></td><td>Firebase</td><td>—</td><td>Re-fetch the transaction from Apple by id, map the product, write entitlement</td></tr>
  <tr><td><code>POST /iap/google/validate</code></td><td>Firebase</td><td>—</td><td>Re-query Play with the purchase token, write entitlement</td></tr>
  <tr><td><code>POST /subscriptions/activate-trial</code></td><td>Firebase</td><td>—</td><td>One-shot 30-day trial; 409 if any member record already exists</td></tr>

  <tr><td><code>POST /account/request-deletion</code></td><td>Firebase</td><td>—</td><td>Soft delete: <code>deletion_pending</code> + revoke refresh tokens</td></tr>
  <tr><td><code>POST /account/recover</code></td><td>Firebase</td><td>—</td><td>Restore to active inside the recovery window; 410 after it</td></tr>
  <tr><td><code>GET /account/export-data</code></td><td>Firebase</td><td>—</td><td>Version-3 JSON export with internal identifiers stripped</td></tr>

  <tr><td><code>POST /quotes/share-link</code></td><td>Firebase</td><td>Active subscription</td><td>Mint or return the share token + URL, idempotent</td></tr>
  <tr><td><code>POST /quotes/send-email</code></td><td>Firebase</td><td>Active subscription</td><td>Mint if needed, flip draft → sent, relay via Resend</td></tr>
  <tr><td><code>POST /quotes/delete</code></td><td>Firebase</td><td>Active subscription</td><td>Delete + tombstone the share index atomically</td></tr>

  <tr><td><code>POST /invoices/share-link</code></td><td>Firebase</td><td>Active subscription</td><td>As above</td></tr>
  <tr><td><code>POST /invoices/send-email</code></td><td>Firebase</td><td>Active subscription</td><td>As above</td></tr>
  <tr><td><code>POST /invoices/delete</code></td><td>Firebase</td><td>Active subscription</td><td>As above</td></tr>

  <tr><td><code>POST /notifications/mark-read</code></td><td>Firebase</td><td>—</td><td>One id, or all</td></tr>
  <tr><td><code>POST /notifications/clear</code></td><td>Firebase</td><td>—</td><td>One id, or all</td></tr>
  <tr><td><code>POST /notifications/send</code></td><td>Firebase</td><td><strong>Admin</strong></td><td>Fan-out records + FCM push + stale-token pruning</td></tr>

  <tr><td><code>GET /ping</code></td><td>Firebase</td><td>—</td><td>Health check; echoes the bound env</td></tr>
</table>`,
    },
    {
      title: 'Function configuration',
      html: `
<pre>region:         europe-west1
memory:         512MiB
timeoutSeconds: 60
secrets:        APPSTORE_SECRETS, GOOGLE_PLAY_SECRETS, RESEND_API_KEY</pre>
<table>
  <tr><th>Export</th><th>Type</th><th>Binds</th></tr>
  <tr><td><code>api</code></td><td><code>onRequest</code></td><td>staging — <code>fifcloud-default-rtdb</code>, App Store Sandbox</td></tr>
  <tr><td><code>apiProd</code></td><td><code>onRequest</code></td><td>production — <code>fifcloud-production</code>, App Store Production</td></tr>
  <tr><td><code>onVerificationStatusChanged</code></td><td><code>onValueWritten</code></td><td>staging RTDB, <code>users/{uid}/verificationStatus</code></td></tr>
  <tr><td><code>onVerificationStatusChangedProd</code></td><td><code>onValueWritten</code></td><td>production RTDB, same path</td></tr>
</table>`,
    },
    {
      title: 'The subscription gate on the server',
      html: `
<p>
  <code>requireActiveSubscription(uid, res)</code> guards the six quote / invoice endpoints.
  This is the second enforcement point for entitlement — the client gate stops the user
  reaching the screens, and this stops a crafted request reaching the actions. Without it,
  someone with an expired subscription could still send emails and mint share links by calling
  the API directly.
</p>`,
      caption: 'Two enforcement points, one entitlement record',
      mermaid: `graph TB
  DB["RTDB users/{uid}/subscription/member"] --> C["CLIENT gate<br/>_needsSubscription in handleAuthentication"]
  DB --> S["SERVER gate<br/>requireActiveSubscription"]
  C -->|"fails"| P["/choosePlan — cannot reach the screens"]
  S -->|"fails"| E["HTTP error — cannot perform the action"]
  C -->|"passes"| H["home + feature screens"]
  H --> R["POST /quotes/send-email"]
  R --> S
  S -->|"passes"| A["email relayed, token minted"]`,
    },
    {
      title: 'The background trigger',
      html: `
<p>
  Two exports, one shared implementation, because a database trigger is bound to a specific
  RTDB instance and there are two. Each wraps its work in
  <code>runWithEnv(env, …)</code> so the profile read hits the same instance the write came
  from — a detail that is easy to get wrong and produces a "user has no email" log line
  against a perfectly populated record in the other database.
</p>`,
      caption: 'onVerificationStatusChanged',
      mermaid: `sequenceDiagram
  autonumber
  participant W as Write to users/{uid}/verificationStatus
  participant T as onValueWritten trigger
  participant E as runWithEnv(env)
  participant DB as RTDB (same instance)
  participant TPL as emailTemplates
  participant R as Resend

  W->>T: before, after
  T->>T: after != "verified" → return
  T->>T: before == "verified" → return (no transition)
  T->>E: bind the environment
  E->>DB: read users/{uid}
  alt no email on the profile
    DB-->>T: warn and stop
  else
    DB-->>T: { email, firstName, accountType }
    T->>TPL: businessVerifiedEmail or tradesmanVerifiedEmail
    TPL-->>T: subject, html, text
    T->>R: sendEmail
    R-->>T: dispatched
  end`,
    },
    {
      title: 'Client-side call convention',
      html: `
<p>
  Every authenticated call from the app follows the same six lines, and every repository
  implements them independently rather than sharing a client:
</p>
<pre>final user  = FirebaseAuth.instance.currentUser;      // null → bail
final token = await user.getIdToken();                // null → bail
final base  = ConfigService().stripeBackendUrl;       // empty → bail
await http.post(
  Uri.parse('$base/quotes/send-email'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({ 'quoteId': id }),
);</pre>
<p>
  Failures are decoded best-effort — the handler's <code>message</code> field is surfaced to
  the user when present, with a generic fallback otherwise. The property name
  <code>stripeBackendUrl</code> is a leftover from the Stripe era; it is now simply "the
  backend base URL".
</p>`,
    },
  ],
});
