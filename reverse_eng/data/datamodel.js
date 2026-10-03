window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PLATFORM',
  nav: 'Data model',
  kicker: 'RTDB tree, Storage, ER',
  title: 'Data model — where everything lives',
  summary: `
    The Realtime Database is a flat set of top-level collections, each immediately keyed by
    <strong>uid</strong>. That shape is the security model: a rule of "you may read and write
    the subtree under your own uid" secures nearly the whole database. The two exceptions —
    the share indexes and the <code>config</code> subtree — are exactly the places where a
    Cloud Function has to mediate.`,
  blocks: [
    {
      title: 'Top-level RTDB layout',
      html: `
<pre>/users/{uid}                      profile, companyDetails, address, location,
                                  subscription/member, notificationPreferences,
                                  accountStatus + deletion timestamps, fcmTokens/{key}

/customers/{uid}/{customerId}     the address book
/staff/{uid}/{staffId}            rate cards
/pricing/{uid}/{itemId}           services + materials library
/quotes/{uid}/{quoteId}           quotes, incl. shareToken / sentAt / viewedAt / respondedAt
/invoices/{uid}/{invoiceId}       invoices, incl. bankSnapshot + paidAt
/jobs/{uid}/{jobId}               jobs, incl. clockInAt + timeEntries + expenses
/todos/{uid}/{todoId}             checklist
/journalEvents/{uid}/{entryId}    diary
/userTools/{uid}/notes|photos|videos|files      the tools locker
/notifications/{uid}/{id}         in-app notification records
/usages/{uid}                     per-feature counters

/quoteShares/{token}              SERVER-ONLY index → { uid, quoteId, createdAt,
                                  viewedAt, respondedAt, respondedAction, deletedAt }
/invoiceShares/{token}            same shape for invoices

/config/...                       plan definitions, feature limits, image limits,
                                  accountDeletion windows, admin/systemRoles
/subscriptions/{userType}/{planId}   plan + limits tables</pre>
<p>
  A caveat worth knowing: <code>lib/generated/database_paths.dart</code> is a large,
  older catalogue of paths (including <code>quotations/</code>,
  <code>customers/{uid}/customers</code>, <code>staff/{uid}/members</code>,
  <code>jobPool/</code>, <code>reviews/</code>, <code>properties/</code>,
  <code>projects/</code>, <code>stripeCustomers/</code>). The <strong>newer feature
  repositories address RTDB directly with the flatter paths listed above</strong>, so
  <code>DatabasePaths</code> is authoritative for Storage and for the user / config subtrees,
  but not for the record books. Trust the repository.
</p>`,
    },
    {
      title: 'Entity relationships',
      html: `
<p>
  The dashed relationships are the important ones: a quote's customer, an invoice's bank
  details and a job's customer are all <strong>embedded copies</strong>, not foreign keys.
  Nothing in the schema enforces referential integrity, and that is by design — a sent document
  is a historical record.
</p>`,
      caption: 'ER — solid = owns, dashed = snapshot copy',
      mermaid: `erDiagram
  USER ||--o{ CUSTOMER : owns
  USER ||--o{ STAFF : owns
  USER ||--o{ PRICING_ITEM : owns
  USER ||--o{ QUOTE : owns
  USER ||--o{ INVOICE : owns
  USER ||--o{ JOB : owns
  USER ||--o{ TODO : owns
  USER ||--o{ JOURNAL_ENTRY : owns
  USER ||--o{ TOOL_ASSET : owns
  USER ||--o{ NOTIFICATION : receives
  USER ||--o{ FCM_TOKEN : registers
  USER ||--|| SUBSCRIPTION : "has one"
  USER ||--|| USAGE : "has one"

  QUOTE ||--o{ QUOTE_LINE : contains
  QUOTE ||--o{ LABOUR_LINE : contains
  QUOTE ||--o{ QUOTE_TERM : contains
  QUOTE ||--o| QUOTE_SHARE : "indexed by token"
  INVOICE ||--o{ QUOTE_LINE : contains
  INVOICE ||--o{ LABOUR_LINE : contains
  INVOICE ||--o| INVOICE_SHARE : "indexed by token"
  JOB ||--o{ TIME_ENTRY : accrues
  JOB ||--o{ JOB_EXPENSE : accrues

  PRICING_ITEM ||..o{ QUOTE_LINE : "copied into"
  STAFF ||..o{ LABOUR_LINE : "rate copied into"
  CUSTOMER ||..o{ QUOTE : "snapshot"
  CUSTOMER ||..o{ INVOICE : "snapshot"
  CUSTOMER ||..o{ JOB : "snapshot"
  TOOL_ASSET ||..o{ JOB : "referenced by"
  TOOL_ASSET ||..o{ QUOTE : "referenced by"

  USER {
    string uid PK
    string email
    string firstName
    string lastName
    string phoneNumber
    string accountType
    string accountStatus
    object address
    object location
    object companyDetails
    object notificationPreferences
  }
  SUBSCRIPTION {
    string status
    bool autoRenew
    bool cancelAtPeriodEnd
    string provider
    string productId
    string originalTransactionId
    string planType
    string billingCycle
    number currentPeriodEnd
  }
  QUOTE {
    string id PK
    string reference
    string status
    number total
    string shareToken
    number sentAt
    number viewedAt
    number respondedAt
  }
  INVOICE {
    string id PK
    string reference
    string status
    number total
    number dueDate
    string paymentMethod
    object bankSnapshot
    number paidAt
  }
  JOB {
    string id PK
    string reference
    string status
    number startDate
    number clockInAt
  }
  QUOTE_SHARE {
    string token PK
    string uid
    string quoteId
    number viewedAt
    string respondedAction
    number deletedAt
  }`,
    },
    {
      title: 'Cloud Storage layout',
      html: `
<p>
  The Storage root is the one place the environment split shows up in a path rather than a
  URL: <code>DatabasePaths.storageUsers</code> returns <code>users</code> in development and
  <code>pod_users</code> in production, so the two environments' blobs never mix inside the
  single bucket.
</p>
<pre>{users|pod_users}/{uid}/
    documents/passport/{ts}.jpg
    documents/idcard/front/{ts}.jpg
    documents/idcard/back/{ts}.jpg
    documents/tradeQualifications/...
    profile/...
    tools/photos/{photoId}/{filename}
    tools/videos/{videoId}/{filename}
    tools/files/{fileId}/{filename}
    tradeCard/{ts}.{ext}
    chat/{jobId}/...</pre>
<p>
  Note that the tools repositories currently write the literal prefix <code>users/</code>
  rather than going through <code>storageUsers</code> — worth knowing when tracing a
  production asset.
</p>`,
    },
    {
      title: 'Two serialisation conventions',
      html: `
<p>
  There are two timestamp styles in the codebase and both are live. Neither is wrong; they just
  arrived at different times, and mixing them up is the most common source of "why is this date
  1970" bugs.
</p>
<table>
  <tr><th>Convention</th><th>Used by</th><th>Example</th></tr>
  <tr><td><code>DateTime</code> serialised by the repository</td><td>Quotes, invoices, jobs, customers, staff</td><td><code>_quoteToRtdb</code> / <code>_jobToRtdb</code> encode, <code>_jobFromRtdb</code> decodes</td></tr>
  <tr><td>Raw epoch <code>int</code> on the model</td><td>To-dos, journal entries, notifications, tool assets</td><td><code>dueAt</code>, <code>startAt</code>, <code>createdAt</code></td></tr>
  <tr><td>ISO 8601 string</td><td>Subscription <code>startDate</code> / <code>endDate</code>, <code>lastAddressUpdatedAt</code></td><td>Written by the Cloud Function entitlement writer</td></tr>
  <tr><td><code>YYYY-MM-DD</code> string</td><td>Journal <code>date</code> — deliberately, for day grouping</td><td><code>2026-08-16</code></td></tr>
</table>
<p>
  The clock fields carry a specific hazard the code guards against explicitly:
  <code>_jobToRtdb</code> and <code>_jobFromRtdb</code> must (de)serialise
  <code>clockInAt</code> and <code>timeEntries</code>, or a full-document <code>update()</code>
  from the edit screen would silently wipe a running clock session.
</p>`,
    },
    {
      title: 'Access boundaries',
      html: `
<p>
  Everything reduces to one question: <em>can the client be trusted to write this?</em>
</p>`,
      caption: 'Who may write what',
      mermaid: `graph TB
  subgraph CLIENT["Client-writable — own uid subtree"]
    A["customers, staff, pricing,<br/>quotes, invoices, jobs, todos,<br/>journalEvents, userTools, usages"]
    B["users/{uid} profile fields<br/>+ fcmTokens"]
  end

  subgraph SERVER["Server-only — Admin SDK"]
    C["quoteShares/{token}<br/>invoiceShares/{token}"]
    D["users/{uid}/subscription/member"]
    E["users/{uid}/verificationStatus"]
    F["users/{uid}/accountStatus<br/>+ deletion timestamps"]
    G["notifications/{uid}"]
  end

  subgraph READONLY["Read-only reference data"]
    H["config/... plans, limits,<br/>accountDeletion, admin/systemRoles"]
    I["subscriptions/{type}/{plan}"]
  end

  J["Why server-only?"] --> C
  J --> D
  C -.->|"a forgeable token index<br/>would expose other users' quotes"| J
  D -.->|"a client-writable entitlement<br/>would be a free subscription"| J
  E -.->|"self-verification"| J
  F -.->|"self-reinstatement<br/>past the recovery window"| J
  G -.->|"forged notifications"| J`,
    },
  ],
});
