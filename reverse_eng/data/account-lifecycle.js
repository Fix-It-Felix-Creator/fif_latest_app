window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'IDENTITY',
  nav: 'Account lifecycle',
  kicker: 'delete, recover, export',
  title: 'Account lifecycle — deletion, recovery and data export',
  summary: `
    Deleting an account is a soft, reversible state change, not a destructive one. The record
    is flagged <code>deletion_pending</code>, refresh tokens are revoked, and Firebase Auth is
    deliberately left <strong>enabled</strong> so the user can still sign in — to change their
    mind, or to download their data — during a recovery window. Physical deletion is a separate
    retention job.`,
  blocks: [
    {
      title: 'The three states',
      html: `
<table>
  <tr><th><code>accountStatus</code></th><th>Can sign in?</th><th>Where the gate sends them</th></tr>
  <tr><td>absent / <code>active</code></td><td>Yes</td><td>Normal flow — onboarding, paywall or home</td></tr>
  <tr><td><code>deletion_pending</code></td><td>Yes, on purpose</td><td><code>/accountDisabled</code> with the recovery-window dates</td></tr>
  <tr><td><code>disabled</code></td><td>No</td><td>Immediate <code>signOut()</code> → <code>/signIn</code></td></tr>
</table>
<p>
  Two timers are stamped at request time and read from
  <code>config/accountDeletion</code> in the database, with a one-minute in-process cache and
  defaults of 14 and 90 days:
</p>
<ul>
  <li><code>recoveryWindowEndsAt</code> = now + <code>recoveryWaitDays</code> — after this,
      recovery returns <strong>410 Gone</strong>.</li>
  <li><code>personalDataRetainedUntil</code> = now + <code>personalDataRetentionDays</code> —
      when the purge job may physically delete.</li>
</ul>`,
    },
    {
      title: 'Pipeline — request deletion',
      html: `
<p>
  Note what is <em>not</em> done: the store subscription is not cancelled. An IAP subscription
  belongs to the user's Apple or Google ID, not to this app account, and only the store can
  cancel it. Once the app record is purged, the store subscription simply has no record left
  to grant entitlement to. The screen tells the user this and links them to the store.
</p>`,
      caption: 'Delete my account → soft flag → tokens revoked → recovery screen',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as DeleteAccountScreen
  participant FN as POST /account/request-deletion
  participant CFG as RTDB config/accountDeletion
  participant DB as RTDB users/{uid}
  participant FA as Firebase Auth
  participant GATE as Auth gate

  U->>S: confirm deletion
  S->>FN: POST + Bearer id token
  FN->>CFG: getAccountDeletionConfig() (1 min cache)
  CFG-->>FN: recoveryWaitDays, personalDataRetentionDays
  FN->>DB: update accountStatus = deletion_pending,<br/>deletionRequestedAt,<br/>recoveryWindowEndsAt,<br/>personalDataRetainedUntil
  FN->>FA: revokeRefreshTokens(uid)
  Note over FA: the auth account stays ENABLED —<br/>sign-in must still work for recovery
  FA-->>FN: other devices lose access immediately
  FN-->>S: 200 with the window dates
  S->>GATE: sign out / relaunch
  GATE->>DB: reads accountStatus
  DB-->>GATE: deletion_pending
  GATE-->>U: /accountDisabled with countdown`,
    },
    {
      title: 'Pipeline — recover',
      html: `
<p>
  Three guarded outcomes, each with its own status code. Recovery restores access but does not
  resurrect a subscription — if they had a paid plan they must subscribe again.
</p>`,
      caption: 'Account recovery decision',
      mermaid: `graph TB
  A["AccountDisabledScreen<br/>tap Recover my account"] --> B["POST /account/recover"]
  B --> C["read users/{uid}"]
  C --> D{"record exists?"}
  D -->|"no"| E["404 user not found"]
  D -->|"yes"| F{"accountStatus ==<br/>deletion_pending?"}
  F -->|"no"| G["400 nothing to recover"]
  F -->|"yes"| H{"now > recoveryWindowEndsAt?"}
  H -->|"yes"| I["410 recovery window has expired"]
  H -->|"no"| J["update accountStatus = active<br/>clear the deletion timestamps"]
  J --> K["200 → re-run the gate"]
  K --> L{"has a live subscription?"}
  L -->|"no"| M["/choosePlan — must re-subscribe"]
  L -->|"yes"| N["/tradesmanHome"]`,
    },
    {
      title: 'Pipeline — data export',
      html: `
<p>
  A GDPR Article 15 style export, and its design is defensive. The code comments spell out
  what is <em>excluded</em> and why: internal identifiers — the Firebase UID, store transaction
  ids, product and price ids — have no value to the end user and would be phishing ammunition
  if the file leaked or was shared. Payment methods are not included at all, because under IAP
  the card is held by Apple or Google and is never visible to this system.
</p>`,
      caption: 'GET /account/export-data — assembling a version-3 export',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as Settings
  participant FN as GET /account/export-data
  participant FA as Firebase Auth admin
  participant DB as RTDB

  U->>S: Download my data
  S->>FN: GET + Bearer id token
  FN->>FA: getUser(uid)
  FA-->>FN: email, displayName, phone, photoURL,<br/>emailVerified, creation + last sign-in
  FN->>DB: read users/{uid}
  DB-->>FN: full profile
  FN->>FN: whitelist profile fields<br/>(drop uid, store ids, product + price ids)
  FN->>DB: read subscription/member
  DB-->>FN: entitlement record
  FN->>FN: reduce to planName, billingCycle,<br/>status, period dates
  FN-->>U: JSON { notice, exportedAt, version: 3,<br/>account, profile, subscriptions }`,
    },
    {
      title: 'Hard delete — the client-side path',
      html: `
<p>
  Separate from the soft-deletion endpoints, <code>AuthRepository</code> also implements a
  full teardown used by <code>DeleteAccountRequested</code>. It has to run in a specific order,
  because once the Firebase Auth user is gone the client no longer has permission to delete
  anything it left behind.
</p>`,
      caption: 'deleteAccountCompletely() ordering',
      mermaid: `graph TB
  A["DeleteAccountRequested"] --> B["deleteUserDocuments()<br/>recursive Storage delete under<br/>users/{uid} or pod_users/{uid}"]
  B --> C["deleteUserDetails()<br/>remove the RTDB users/{uid} subtree"]
  C --> D["clearUserCache()<br/>drop the Hive-cached record"]
  D --> E["FirebaseAuth currentUser.delete()"]
  E --> F["emit DeleteAccountSuccessState"]
  F --> G["/signIn"]
  E -.->|"requires-recent-login"| H["surface a re-authenticate prompt"]`,
    },
  ],
});
