// Item schema — every file in data/ pushes exactly one item:
//
//   window.DOCS.sections.push({
//     group:   'FOUNDATION',      // left-panel group heading
//     nav:     'Overview',        // left-panel row label
//     kicker:  'what it is',      // small second line on the row
//     title:   'Overview',        // page heading
//     summary: '<p>…</p>',        // page intro paragraph (HTML)
//     blocks: [                   // page body, in order
//       { title: 'Heading', html: '<p>…</p>' },
//       { title: 'Pipeline', caption: 'X → Y', mermaid: 'graph LR …' },
//     ],
//   });
//
// Mermaid code is plain JS text (never HTML-parsed), so <br/> and <<x>>
// may be written literally. Never use a backtick or a dollar-brace inside
// the diagram source.
window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'FOUNDATION',
  nav: 'Overview',
  kicker: 'the product idea',
  title: 'Overview — what the application is',
  summary: `
    <strong>Fix It Felix Pro</strong> is a single-operator field-service business app for UK
    tradespeople — electricians, plumbers, builders, decorators. One tradesperson (or a small
    firm owner) runs their whole back office from the phone: keep a customer book, raise a
    quote, turn it into a job, clock time against that job, invoice it, and email the customer
    a link they can open in any browser. It is a Flutter mobile app on iOS and Android backed
    entirely by Firebase, monetised with an auto-renewing store subscription after a 30-day
    free trial.`,
  blocks: [
    {
      title: 'Key facts',
      html: `
<table>
  <tr><th>Product</th><td>Fix It Felix Pro — field-service admin for UK trades</td></tr>
  <tr><th>Client</th><td>Flutter 3.44 / Dart SDK ^3.9.2, one codebase for iOS + Android</td></tr>
  <tr><th>Bundle id</th><td><code>com.techkushx.fixitfelixpro</code>, pubspec name <code>fixitfelix</code>, version <code>1.1.0+30</code></td></tr>
  <tr><th>State</th><td>BLoC (<code>flutter_bloc</code>) over repositories; <code>provider</code> only for theming</td></tr>
  <tr><th>Backend</th><td>Firebase project <code>fifcloud</code>, region <code>europe-west1</code></td></tr>
  <tr><th>Database</th><td>Firebase Realtime Database — two instances (staging / production)</td></tr>
  <tr><th>Server code</th><td>Cloud Functions v2, TypeScript, one Express app exported twice (<code>api</code>, <code>apiProd</code>)</td></tr>
  <tr><th>Money</th><td>In-App Purchase only — StoreKit (iOS) + Play Billing (Android). Stripe removed.</td></tr>
  <tr><th>Email</th><td>Resend, from <code>noreply@fixitfelix.app</code></td></tr>
  <tr><th>Public web</th><td>Firebase Hosting <code>fifcloud.web.app</code> — server-rendered quote/invoice viewer</td></tr>
</table>`,
    },
    {
      title: 'The product in one picture',
      html: `
<p>
  Everything the tradesperson does hangs off <em>one identity</em> (a Firebase Auth user) and
  <em>one entitlement</em> (an active subscription). Beyond that gate the app is a set of
  record books — customers, staff, price list, jobs, quotes, invoices, plus a media locker —
  that all write into the same per-user subtree of the Realtime Database. The only things
  that leave the phone are the emails and the public share links.
</p>`,
      caption: 'Product map — identity gate, record books, outbound surfaces',
      mermaid: `graph TB
  subgraph GATE["Gate — must pass before anything else"]
    AUTH["Firebase Auth account"]
    ONB["Profile complete<br/>(name, phone, postcode)"]
    SUB["Live subscription<br/>(trial or paid)"]
    AUTH --> ONB --> SUB
  end

  subgraph BOOKS["Record books — per-user RTDB subtrees"]
    CUST["Customers"]
    STAFF["Staff and labour rates"]
    PRICE["Price list"]
    JOB["Jobs + time clock"]
    QUOTE["Quotes"]
    INV["Invoices"]
    TOOLS["Tools locker<br/>notes / photos / videos / files"]
    TODO["To-dos"]
    JOURNAL["Journal"]
  end

  subgraph OUT["Outbound — leaves the device"]
    MAIL["Resend email to the customer"]
    WEB["Public viewer fifcloud.web.app/q/:token"]
    PDF["On-device PDF, shared via OS sheet"]
    PUSH["FCM push back to the tradesperson"]
  end

  SUB --> BOOKS
  CUST --> QUOTE
  PRICE --> QUOTE
  STAFF --> QUOTE
  QUOTE --> JOB
  JOB --> INV
  TOOLS --> JOB
  TOOLS --> QUOTE
  QUOTE --> MAIL
  INV --> MAIL
  MAIL --> WEB
  QUOTE --> PDF
  INV --> PDF
  WEB -->|"customer accepts / rejects"| PUSH`,
    },
    {
      title: 'The core loop the app exists to serve',
      html: `
<p>
  This is the money path. Every other feature is a support act for it. Notice that the quote
  and the invoice are the only two records that ever become visible to a third party, and
  both do it through the same mechanism: a server-minted opaque token that indexes back to
  the owning user.
</p>`,
      caption: 'Customer → quote → job → invoice → paid',
      mermaid: `graph LR
  A["Add customer"] --> B["Build quote<br/>lines + labour"]
  B --> C["Send quote<br/>email or share link"]
  C --> D{"Customer<br/>responds?"}
  D -->|"accept"| E["Quote status = accepted<br/>push to tradesperson"]
  D -->|"reject"| F["Quote status = rejected"]
  E --> G["Create job<br/>link the quote"]
  G --> H["Clock in / clock out<br/>time entries accrue"]
  H --> I["Log expenses<br/>attach photos"]
  I --> J["Raise invoice<br/>from the same lines"]
  J --> K["Send invoice<br/>bank details snapshot"]
  K --> L["Mark paid"]`,
    },
    {
      title: 'Who is in the system',
      html: `
<p>
  Only <strong>one</strong> human ever signs in: the tradesperson. Customers are records, not
  accounts — they never authenticate, they interact through a tokenised web page. Staff are
  also records (a rate card for labour lines), not logins. An <code>accountType</code> of
  <code>customer</code> is actively blocked at sign-in, because a separate consumer app owns
  that side of the business.
</p>
<table>
  <tr><th>Actor</th><th>Has a login?</th><th>How they touch the system</th></tr>
  <tr><td>Tradesperson / owner</td><td>Yes — Firebase Auth</td><td>The whole app</td></tr>
  <tr><td>Customer</td><td>No</td><td>Email link → <code>/q/:token</code> or <code>/i/:token</code>; can accept or reject a quote</td></tr>
  <tr><td>Staff member</td><td>No</td><td>A rate card the owner puts on labour lines</td></tr>
  <tr><td>Admin</td><td>Yes, flagged in <code>/config/admin/systemRoles</code></td><td>Only the notification fan-out endpoint</td></tr>
  <tr><td>Apple / Google</td><td>Server-to-server</td><td>Store notification webhooks into the IAP endpoints</td></tr>
</table>`,
    },
    {
      title: 'How to read this documentation',
      html: `
<p>
  The list on the left is the whole application, top to bottom. <strong>FOUNDATION</strong>
  is the shape of the thing — stack, layers, environments, boot. <strong>IDENTITY</strong> is
  everything that must succeed before a user sees a home screen.
  <strong>WORKSPACE</strong> and <strong>PRODUCTIVITY</strong> are the features themselves,
  each documented as an end-to-end pipeline: which widget fires, which BLoC event, which
  repository call, which database path, which Cloud Function, which third party.
  <strong>PLATFORM</strong> is the reference material — the HTTP surface, the data model, and
  the route table.
</p>
<p>
  Click <em>Zoom</em> on any diagram for a full-screen inspector (mouse wheel to zoom, drag to
  pan, <code>Esc</code> to close). <code>j</code> / <code>k</code> move through the list,
  <code>/</code> focuses the filter.
</p>
<p style="border-top:1px solid #000; padding-top:10px; margin-top:22px;">
  Phase 1 covers the idea, the technology, and the function pipelines. It was written by
  reading the code as it exists on branch <code>feature/options</code>: the Flutter app in
  <code>fixitfelixpro/lib/</code>, the Cloud Functions in <code>functions/src/</code>, and the
  task log in <code>CLAUDE.md</code>.
</p>`,
    },
  ],
});
