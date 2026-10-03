window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Price list & settings',
  kicker: 'reusable items, numbering, terms',
  title: 'Price list, quote settings and terms',
  summary: `
    Three small subsystems that exist purely to stop the tradesperson retyping. The price list
    is a library of services and materials with a cost and a markup; quote settings own
    reference numbering; and the term library holds the clauses that go at the foot of every
    quote. Each one seeds a document at build time — and once seeded, the copy is
    independent.`,
  blocks: [
    {
      title: 'Price list items',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>kind</code></td><td><code>PricingKind.service</code> or <code>.material</code></td></tr>
  <tr><td><code>name</code>, <code>itemCode</code></td><td>Display name and the owner's own code</td></tr>
  <tr><td><code>unitCost</code></td><td>What it costs</td></tr>
  <tr><td><code>unitMarkup</code></td><td>What is added on top — <strong>retained here</strong>, unlike labour</td></tr>
</table>
<p>
  A quote line copies the item and then layers its own economics on top:
</p>
<pre>QuoteLineDraft.lineTotal
  base  = (rate + unitMarkup) * quantity
  total = base * (1 - discount / 100)</pre>
<p>
  So the markup that was stripped out of labour lines lives on for materials and services.
  That asymmetry is deliberate: a customer expects a merchant margin on parts, but a blended
  hourly rate that hides a weekend uplift reads as a hidden charge.
</p>`,
      caption: 'Price list → quote line',
      mermaid: `graph LR
  A["PricingScreen<br/>services + materials tabs"] --> B["PricingEditScreen<br/>name, code, unit cost, markup"]
  B --> C["RTDB pricing/{uid}/{itemId}"]
  C --> D["PricingBloc stream"]
  D --> E["PricingPickerScreen<br/>opened from the quote builder"]
  E --> F["QuoteLineDraft copies the item<br/>+ rate, markup, discount, quantity"]
  F --> G["lineTotal = (rate + markup) x qty<br/>x (1 - discount%)"]
  G --> H["Quote / Invoice totals"]
  C -.->|"later edits to the library"| I["do NOT change existing quotes"]`,
    },
    {
      title: 'Quote numbering',
      html: `
<p>
  <code>QuoteSettings</code> holds two fields — <code>autoGenerateNumber</code> and
  <code>prefix</code> — edited on <code>QuoteSettingsScreen</code> and streamed by
  <code>QuoteSettingsBloc</code>. When auto-generation is on, opening the builder asks the
  repository for the next sequence and composes <em>prefix + number</em>.
</p>`,
      caption: 'Reference sequencing',
      mermaid: `graph TB
  A["Tap + on Quotes / Invoices / Jobs"] --> B{"autoGenerateNumber?"}
  B -->|"no"| C["reference field left blank<br/>for manual entry"]
  B -->|"yes"| D["repository nextSequence()"]
  D --> E["read every existing record"]
  E --> F["regex the trailing digits<br/>of each reference"]
  F --> G["max + 1"]
  G --> H["reference = prefix + number"]
  H --> I["shown pre-filled, still editable"]
  J["Jobs use the same scan-based scheme,<br/>with a thinner settings wrapper"] -.-> D`,
    },
    {
      title: 'Term library',
      html: `
<p>
  Terms are reusable paragraphs — payment terms, guarantees, access requirements. They are
  written once in <code>quote_term_edit_screen</code>, picked into a document through
  <code>quote_terms_picker_screen</code>, and then <em>copied</em> onto the record as a
  <code>QuoteTerm</code> list. The public viewer and the PDF both render them at the foot of
  the document.
</p>`,
      caption: 'Terms — write once, copy into each document',
      mermaid: `graph LR
  A["QuoteTermEditScreen<br/>title + body"] --> B["Term library"]
  B --> C["QuoteTermsPickerScreen<br/>multi-select"]
  C --> D["Quote.terms / Invoice.terms<br/>(copied, not referenced)"]
  D --> E["Flutter builder section"]
  D --> F["PDF footer block"]
  D --> G["Public viewer HTML"]`,
    },
    {
      title: 'Usage limits — the plan-aware layer',
      html: `
<p>
  <code>UsageRepository</code> and <code>UsageBloc</code> sit alongside these libraries and are
  the largest repository in the app. They read a limits table from
  <code>subscriptionsLimits/{userType}/{planId}</code>, track counts under
  <code>usages/{uid}</code>, and expose a family of <code>canCreate…</code> predicates —
  <code>canCreateJob</code>, <code>canCreateQuotation</code>, <code>canCreateInvoice</code>,
  <code>canAddCustomer</code>, <code>canAddStaffMember</code>, <code>canAddAddress</code> and
  more — plus increment / decrement counters.
</p>
<p>
  With the product collapsed to a single Standard tier the ceilings are effectively generous,
  but the machinery is fully wired and is what a future tier ladder would hang off.
</p>`,
      caption: 'Usage gate around a create action',
      mermaid: `sequenceDiagram
  autonumber
  participant S as Screen (tap +)
  participant U as UsageRepository
  participant CFG as RTDB subscriptionsLimits/{type}/{plan}
  participant CNT as RTDB usages/{uid}
  participant R as Feature repository

  S->>U: canCreateQuotation()
  U->>CFG: getUserLimits() for the active plan
  CFG-->>U: FeatureLimitsModel
  U->>CNT: getUserUsageStats()
  CNT-->>U: current counts
  alt count >= limit and not unlimited
    U-->>S: false → show an upgrade prompt
  else within limit
    U-->>S: true
    S->>R: create(record)
    R-->>S: id
    S->>U: incrementUsageCount(quotation)
    U->>CNT: update the counter
  end`,
    },
  ],
});
