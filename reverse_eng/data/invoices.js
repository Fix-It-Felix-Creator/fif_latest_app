window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Invoices',
  kicker: 'bill, send, get paid',
  title: 'Invoices — the same machine, one direction less',
  summary: `
    An invoice is structurally a quote that asks for money instead of a decision. It reuses the
    same line-item and labour-line models, the same share-token mechanism, the same email
    relay and the same public viewer. The differences are all at the edges: a due date instead
    of an expiry, a payment method, a frozen snapshot of the bank details, and a public page
    that is <strong>read-only</strong> — there is no Accept button, because paying happens
    outside the system.`,
  blocks: [
    {
      title: 'What differs from a quote',
      html: `
<table>
  <tr><th></th><th>Quote</th><th>Invoice</th></tr>
  <tr><td>Date field</td><td><code>expiry</code> — a duration resolved on the viewer</td><td><code>dueDate</code> — an absolute date</td></tr>
  <tr><td>Statuses</td><td>draft → sent → accepted / rejected</td><td>draft → sent → paid (plus overdue by date)</td></tr>
  <tr><td>Customer can act?</td><td>Yes — Accept / Reject</td><td>No — the page is read-only</td></tr>
  <tr><td>Who closes it</td><td>The customer</td><td>The tradesperson, via <code>markAsPaid</code></td></tr>
  <tr><td>Payment details</td><td>—</td><td><code>paymentMethod</code> (cash / bank deposit) + <code>bankSnapshot</code></td></tr>
  <tr><td>Public routes</td><td><code>/q/:token</code>, <code>/q/:token/respond</code></td><td><code>/i/:token</code> only</td></tr>
</table>`,
    },
    {
      title: 'Why the bank details are a snapshot',
      html: `
<p>
  <code>bankSnapshot</code> is a copy of the bank name, account number and sort code
  <em>as they were when the invoice was raised</em>, not a live reference to the Settings
  record. If the tradesperson later changes bank, an invoice sent last month must keep showing
  the account the customer was told to pay into. The same reasoning applies to the embedded
  customer snapshot on quotes, jobs and invoices alike: sent documents are historical records,
  not live views.
</p>`,
      caption: 'Snapshot vs. live reference',
      mermaid: `graph TB
  A["Settings → Bank details<br/>BankDetailsModel"] -->|"copied at raise time"| B["Invoice.bankSnapshot"]
  A -->|"user later edits"| C["new bank details"]
  C -.->|"does NOT propagate"| B
  B --> D["PDF + public viewer<br/>show the original account"]
  E["Customer book record"] -->|"copied at raise time"| F["Invoice.customer"]
  E -->|"user later edits"| G["updated customer"]
  G -.->|"does NOT propagate"| F`,
    },
    {
      title: 'Pipeline — raise, send, mark paid',
      html: `
<p>
  The send half is byte-for-byte the quote pipeline against different paths
  (<code>/invoices/share-link</code>, <code>/invoices/send-email</code>,
  <code>invoiceShares/{token}</code>). What is unique is the closing move: getting paid happens
  in the real world — cash in hand, or a bank transfer — so the system cannot observe it. The
  tradesperson asserts it.
</p>`,
      caption: 'Invoice lifecycle end to end',
      mermaid: `sequenceDiagram
  autonumber
  participant U as Tradesperson
  participant NI as NewInvoiceScreen
  participant R as InvoicesRepository
  participant DB as RTDB invoices/{uid}
  participant FN as Cloud Function
  participant RS as Resend
  participant C as Customer
  participant HOST as fifcloud.web.app

  U->>NI: lines, labour, due date,<br/>payment method, terms
  Note over NI: bankSnapshot copied from<br/>Settings at this moment
  U->>NI: Save
  NI->>R: create(invoice)
  R->>DB: push().set(json) — status draft

  U->>R: sendInvoiceEmail(id, message)
  R->>FN: POST /invoices/send-email + Bearer
  FN->>FN: requireActiveSubscription
  FN->>DB: mint invoiceShares/{token} if absent<br/>flip draft → sent, stamp sentAt
  FN->>RS: relay, Reply-To the tradesperson
  RS-->>C: email with /i/{token}

  C->>HOST: open the link
  HOST->>FN: viewSharedInvoice
  FN->>DB: resolve env, stamp viewedAt on first view
  FN-->>C: read-only invoice page<br/>(no Accept / Reject)

  U->>R: markAsPaid(id)
  R->>DB: update { status: paid, paidAt: now }
  DB-->>U: list row moves to Paid`,
    },
    {
      title: 'Pipeline — delete, and why it goes through the server',
      html: `
<p>
  Deleting is the one operation that could <em>not</em> be a direct database call. If the
  client simply removed <code>invoices/{uid}/{id}</code>, the share index would still point at
  a hole and a customer opening their emailed link would see a bare "unavailable" error. So
  delete is a Cloud Function that tombstones the share index and removes the record in the
  same atomic write — the public page can then say something honest.
</p>`,
      caption: 'Delete with a tombstoned share index',
      mermaid: `graph TB
  A["Delete invoice"] --> B["POST /invoices/delete + Bearer"]
  B --> C["verify ownership of invoices/{uid}/{id}"]
  C --> D["atomic multi-path write"]
  D --> E["invoices/{uid}/{id} = null"]
  D --> F["invoiceShares/{token}/deletedAt = now"]
  E --> G["stream tick → row disappears"]
  F --> H["public viewer renders<br/>'the tradesperson withdrew this invoice'<br/>instead of a generic error"]
  I["Quotes use the identical<br/>POST /quotes/delete path"] -.-> D`,
    },
    {
      title: 'Invoice status model',
      html: `
<p>
  Overdue is not a stored status — it is derived by comparing <code>dueDate</code> against now
  for an invoice still in <code>sent</code>. That keeps the record honest without a scheduled
  job having to rewrite documents at midnight.
</p>`,
      caption: 'Invoice lifecycle',
      mermaid: `stateDiagram-v2
  [*] --> draft
  draft --> sent: send-email (server flips it) or markAsSent
  sent --> sent: customer opens — viewedAt stamped
  sent --> paid: tradesperson taps Mark as paid
  paid --> [*]
  note right of sent
    "overdue" is derived at read time
    from dueDate, never stored
  end note`,
    },
    {
      title: 'Notification deep-links back into the record',
      html: `
<p>
  <code>invoice_notification_nav.dart</code> and <code>quote_notification_nav.dart</code> exist
  so that tapping a push — "your invoice was opened" — does not just dump the user on the home
  screen. The notification payload carries the record id; the nav helper resolves it through
  the repository and pushes the right editor screen.
</p>`,
      caption: 'Push → payload → record → screen',
      mermaid: `graph LR
  A["FCM push tapped"] --> B["PushNotificationsService._handleTap"]
  B --> C["read payload type + id"]
  C --> D{"type"}
  D -->|"quote"| E["quote_notification_nav<br/>QuotesRepository.findById"]
  D -->|"invoice"| F["invoice_notification_nav<br/>InvoicesRepository.findById"]
  D -->|"other"| G["/notifications list"]
  E --> H["push /quotes/new with the existing quote"]
  F --> I["push /invoices/new with the existing invoice"]`,
    },
  ],
});
