window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Quotes',
  kicker: 'build, share, accept/reject',
  title: 'Quotes — build, send, and the public viewer',
  summary: `
    The quote is the only record in the app that a person outside the account can act on. It
    is composed from three sources — priced line items, labour lines drawn from the staff rate
    card, and terms — then sent as a link. The customer opens a server-rendered web page with
    no login, presses Accept or Reject, and the tradesperson's phone gets a push. Nothing about
    that path requires the customer to install anything.`,
  blocks: [
    {
      title: 'Anatomy of a quote',
      html: `
<table>
  <tr><th>Part</th><th>Source</th><th>Editor</th></tr>
  <tr><td>Reference</td><td>Auto-sequenced, configurable prefix</td><td><code>QuoteSettingsScreen</code></td></tr>
  <tr><td>Customer</td><td>Snapshot from the customer book</td><td>Picker on the quote builder</td></tr>
  <tr><td>Material / service lines</td><td><code>QuoteLineDraft</code>, optionally seeded from the price list</td><td><code>quote_line_edit_screen</code>, <code>pricing_picker_screen</code></td></tr>
  <tr><td>Labour lines</td><td><code>QuoteStaffDraft</code> — a staff member, a rate method, a quantity</td><td><code>quote_staff_edit_screen</code></td></tr>
  <tr><td>Terms</td><td><code>QuoteTerm</code> list from a reusable library</td><td><code>quote_term_edit_screen</code>, <code>quote_terms_picker_screen</code></td></tr>
  <tr><td>Attachments</td><td>Tools locker references</td><td>Picker screens</td></tr>
  <tr><td>Expiry</td><td><code>QuoteExpiry</code> — a duration, resolved to a date on the viewer</td><td>Quote builder</td></tr>
  <tr><td>Lifecycle stamps</td><td><code>sentAt</code>, <code>viewedAt</code>, <code>respondedAt</code>, <code>shareToken</code></td><td>Server-written</td></tr>
</table>`,
    },
    {
      title: 'Pipeline — building a quote',
      html: `
<p>
  Everything on the builder is local state until Save. The labour row is the interesting part:
  choosing a rate method (Standard / Weekend / Emergency / Sociable) refills the rate field
  from the staff member's rate card, and the row renders the method as a badge above
  "<em>N days × £rate</em>". There is no hidden markup on labour — see
  <em>Staff &amp; labour rates</em> for why that was deliberately removed.
</p>`,
      caption: 'Quote builder composition',
      mermaid: `graph TB
  NQ["NewQuoteScreen"] --> CUST["Pick customer<br/>→ snapshot embedded"]
  NQ --> LINES["Add line items"]
  LINES --> PP["PricingPickerScreen<br/>seed from the price list"]
  LINES --> QLE["QuoteLineEditScreen<br/>description, qty, unit price, markup"]
  NQ --> LAB["Add labour"]
  LAB --> QSE["QuoteStaffEditScreen"]
  QSE --> RM["Rate method dropdown<br/>Standard / Weekend /<br/>Emergency / Sociable"]
  RM --> FILL["refills the rate field from<br/>Staff.rateFor(method)"]
  NQ --> TERMS["QuoteTermsPickerScreen<br/>reusable term library"]
  NQ --> ATT["Attach photos / videos /<br/>files / notes"]
  NQ --> SAVE["Save"]
  SAVE --> REPO["QuotesRepository.create / update"]
  REPO --> DB["RTDB quotes/{uid}/{quoteId}"]
  DB --> BLOC["QuotesBloc stream tick"]
  BLOC --> LIST["QuotesScreen list refreshes"]`,
    },
    {
      title: 'Pipeline — send by email',
      html: `
<p>
  The app deliberately does <em>not</em> mint the token, flip the status, or format the email
  itself. It POSTs a quote id and the Cloud Function does all four things atomically. That
  keeps the token unforgeable (it is generated with <code>randomBytes(16)</code> server-side)
  and keeps the customer-facing copy in one place.
</p>
<p>
  Reply-To is set to the tradesperson's own address, so a customer who just hits reply lands
  in their inbox rather than a no-reply void.
</p>`,
      caption: 'Send quote email — token, status flip, Resend relay',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant QS as QuoteSendScreen
  participant R as QuotesRepository
  participant FN as POST /quotes/send-email
  participant SUB as requireActiveSubscription
  participant DB as RTDB
  participant RS as Resend
  participant C as Customer inbox

  U->>QS: optional covering message, tap Send
  QS->>R: sendQuoteEmail(quoteId, message)
  R->>FN: POST { quoteId, message } + Bearer token
  FN->>SUB: gate on a live subscription
  alt not entitled
    SUB-->>FN: reject
    FN-->>R: 402/403 with a message
    R-->>QS: (ok: false, error)
  else entitled
    FN->>DB: read quotes/{uid}/{quoteId} + users/{uid}
    alt no shareToken yet
      FN->>DB: atomic multi-path write<br/>quoteShares/{token} = { uid, quoteId, createdAt }<br/>quotes/{uid}/{id}/shareToken = token
    end
    alt status is still draft
      FN->>DB: status = sent, sentAt = now
    end
    FN->>RS: send HTML email<br/>From noreply@fixitfelix.app<br/>Reply-To the tradesperson<br/>link https://fifcloud.web.app/q/{token}
    RS-->>C: delivered
    FN-->>R: 200
    R-->>QS: (ok: true)
  end`,
    },
    {
      title: 'Pipeline — copy a share link instead',
      html: `
<p>
  Same token, no email — for sending over WhatsApp or SMS. <code>getShareLink</code> is
  idempotent: if the quote already has a token it returns the same URL, so a link previously
  given to a customer never stops working.
</p>`,
      caption: 'Mint or return the share URL',
      mermaid: `graph LR
  A["Share button"] --> B["QuotesRepository.getShareLink(id)"]
  B --> C["POST /quotes/share-link + Bearer"]
  C --> D["requireActiveSubscription"]
  D --> E["read quotes/{uid}/{id}"]
  E --> F{"shareToken present?"}
  F -->|"yes"| G["return the same token — idempotent"]
  F -->|"no"| H["randomBytes(16).base64url"]
  H --> I["atomic multi-path write:<br/>quoteShares/{token} index<br/>+ quote.shareToken"]
  I --> G
  G --> J["{ token, url }"]
  J --> K["share_plus OS sheet"]`,
    },
    {
      title: 'Pipeline — the customer opens the link',
      html: `
<p>
  <code>GET /q/:token</code> is public: <strong>the token is the authorisation</strong>. It is
  registered before <code>verifyFirebaseToken</code> in the Express app so the Firebase
  middleware never sees it. Because a single Hosting site serves both environments' links, the
  handler first resolves which database instance owns the token, then re-binds the environment
  for the rest of the request.
</p>
<p>
  First view is tracked exactly once — <code>viewedAt</code> is stamped on both the share index
  and the quote, and the owner gets a push. Subsequent opens are silent, so a customer
  re-reading the quote does not spam the tradesperson.
</p>`,
      caption: 'Public quote viewer — resolve env, render, notify on first view',
      mermaid: `sequenceDiagram
  autonumber
  participant C as Customer browser
  participant H as Hosting fifcloud.web.app
  participant FN as viewSharedQuote
  participant ENV as resolveEnvForPath
  participant DB as RTDB (resolved instance)
  participant N as notifyOneUser
  participant T as Tradesperson device

  C->>H: GET /q/{token}
  H->>FN: rewrite to the Cloud Function
  FN->>ENV: probe quoteShares/{token}<br/>production first, then staging
  alt neither instance has it
    ENV-->>FN: null
    FN-->>C: 404 page
  else found
    ENV-->>FN: env
    FN->>FN: rebindEnv(env)
    FN->>DB: read the share index → { uid, quoteId }
    FN->>DB: read quotes/{uid}/{quoteId} + owner profile
    alt first view (no viewedAt)
      FN->>DB: multi-path write viewedAt on<br/>the index AND the quote
      FN->>N: notifyOneUser("your quote was opened")
      N->>T: in-app record + FCM push
    end
    FN-->>C: server-rendered HTML —<br/>line items, labour charges with<br/>rate-method badges, terms,<br/>expiry, Accept / Reject buttons
  end
  Note over C,FN: attachments load through<br/>GET /q/:token/:mode/:kind/:id<br/>(v = view inline, d = download)`,
    },
    {
      title: 'Pipeline — accept or reject',
      html: `
<p>
  The response endpoint is public too, and idempotent by rejection: a second response after
  the first returns <strong>409</strong>, so a customer cannot flip a decision by re-opening
  the mail.
</p>`,
      caption: 'Customer decision → quote status → push to owner',
      mermaid: `sequenceDiagram
  autonumber
  participant C as Customer
  participant FN as POST /q/{token}/respond
  participant ENV as resolveEnvForPath + rebindEnv
  participant DB as RTDB
  participant N as notifyOneUser
  participant T as Tradesperson
  participant B as QuotesBloc

  C->>FN: { action: "accept" | "reject" }
  FN->>FN: validate the action value
  FN->>ENV: locate + bind the token's instance
  alt token unknown
    ENV-->>FN: null → 404
  end
  FN->>DB: read quoteShares/{token}
  alt already has respondedAt
    DB-->>FN: responded
    FN-->>C: 409 — already answered
  else first response
    FN->>DB: quotes/{uid}/{id}.status = accepted / rejected
    FN->>DB: share index respondedAt + respondedAction
    FN->>N: notifyOneUser("quote accepted" / "rejected")
    N->>T: in-app record + FCM push
    FN-->>C: 200 { success, status } — page confirms
    DB-->>B: owner's live stream tick
    B-->>T: the list row now shows the new status
  end`,
    },
    {
      title: 'Pipeline — PDF export',
      html: `
<p>
  Entirely local. <code>QuotePdfService</code> composes the document with the <code>pdf</code>
  package, using the bundled Roboto faces (Google Fonts are not fetched at render time), and
  hands the bytes to the OS share sheet through <code>printing</code> /
  <code>share_plus</code>. No network, works offline, and the server never sees the file.
</p>`,
      caption: 'On-device PDF generation',
      mermaid: `graph LR
  A["Quote detail → Export PDF"] --> B["QuotePdfService.build(quote, profile)"]
  B --> C["load bundled Roboto-Regular / Bold<br/>from assets/fonts"]
  C --> D["compose pages:<br/>header + company details,<br/>customer block, line items,<br/>labour rows 'Name — Method rate',<br/>totals, terms"]
  D --> E["Uint8List bytes"]
  E --> F["printing / share_plus<br/>OS share sheet"]
  F --> G["Mail, Messages, Files,<br/>AirDrop, print…"]`,
    },
    {
      title: 'Quote status model',
      html: `
<p>
  Four statuses, and only two of the transitions are driven by the tradesperson.
</p>`,
      caption: 'Quote lifecycle — who moves it',
      mermaid: `stateDiagram-v2
  [*] --> draft: created in the app
  draft --> sent: send-email, or markAsSent
  sent --> sent: customer opens (viewedAt stamped, push sent)
  sent --> accepted: customer presses Accept
  sent --> rejected: customer presses Reject
  accepted --> [*]: becomes a job
  rejected --> [*]
  note right of sent
    the server flips draft to sent
    inside send-email so the client
    and server never disagree
  end note`,
    },
  ],
});
