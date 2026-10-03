window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Staff & labour rates',
  kicker: 'the rate card, and the markup that was removed',
  title: 'Staff and labour rates',
  summary: `
    Staff members are not users — they are rate cards. Each carries a standard rate plus three
    optional premium rates, and a quote's labour line names both the person and the rate method
    applied. This replaced a hidden per-unit markup, and the reason for that change is the most
    interesting design decision in the record books: the homeowner reading the quote should be
    able to see exactly what they are paying for.`,
  blocks: [
    {
      title: 'The rate card',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>name</code>, <code>email</code>, <code>phone</code></td><td>Contact details only — no login is ever created</td></tr>
  <tr><td><code>defaultPayType</code></td><td><code>StaffPayType.day</code> or <code>.hour</code></td></tr>
  <tr><td><code>rate</code></td><td>The <strong>standard</strong> rate</td></tr>
  <tr><td><code>weekendRate</code>, <code>emergencyRate</code>, <code>sociableRate</code></td><td>Premium rates; leave blank and they fall back to standard</td></tr>
</table>
<p>
  <code>Staff.rateFor(LabourRateType)</code> encodes that fallback: a premium rate of zero
  resolves to the standard rate, so an owner who only fills in one number still gets sane
  behaviour on every method.
</p>`,
      caption: 'LabourRateType resolution',
      mermaid: `graph TB
  A["rateFor(method)"] --> B{"method"}
  B -->|"standard"| C["rate"]
  B -->|"weekend"| D{"weekendRate > 0?"}
  B -->|"emergency"| E{"emergencyRate > 0?"}
  B -->|"sociable"| F{"sociableRate > 0?"}
  D -->|"yes"| G["weekendRate"]
  D -->|"no"| C
  E -->|"yes"| H["emergencyRate"]
  E -->|"no"| C
  F -->|"yes"| I["sociableRate"]
  F -->|"no"| C`,
    },
    {
      title: 'The change: hidden markup → visible rate method',
      html: `
<p>
  Labour lines used to carry a <code>unitMarkup</code>: the customer saw one blended number,
  and the uplift for weekend or emergency work was folded invisibly into it. That was replaced
  wholesale.
</p>
<table>
  <tr><th></th><th>Before</th><th>After</th></tr>
  <tr><td>Staff model</td><td><code>rate</code> + <code>unitMarkup</code></td><td><code>rate</code> + <code>weekendRate</code> + <code>emergencyRate</code> + <code>sociableRate</code></td></tr>
  <tr><td>Quote labour draft</td><td><code>unitMarkup</code></td><td><code>rateType</code></td></tr>
  <tr><td>Line total</td><td><code>(rate + markup) × qty</code></td><td><code>rate × qty</code></td></tr>
  <tr><td>Editor UI</td><td>A markup field</td><td>A rate-method dropdown showing "<em>Method · £rate</em>"; picking one refills the rate field</td></tr>
  <tr><td>Builder row</td><td>"Labour · Qty"</td><td>An orange method badge above "<em>N days × £rate</em>"</td></tr>
  <tr><td>Summary row</td><td>"Labour cost"</td><td>"Labour charges"</td></tr>
  <tr><td>PDF row</td><td>Name, blended unit price</td><td>"<em>Name — Method rate</em>", unit price = the rate itself</td></tr>
  <tr><td>Public web viewer</td><td>Bare line</td><td>Rate badge + explanatory note: "no hidden markup"</td></tr>
</table>
<p>
  Note the scope boundary: <strong>material and service line markup was left intact</strong>.
  Only labour lost its hidden uplift.
</p>`,
    },
    {
      title: 'Pipeline — a labour line, from rate card to customer screen',
      html: `
<p>
  This pipeline is worth following all the way out, because it is the one place where a model
  change had to be pushed simultaneously through the Flutter UI, the local PDF renderer,
  <em>and</em> a server-rendered HTML page — three independent presentations of the same row.
</p>`,
      caption: 'Rate card → quote line → three renderings',
      mermaid: `graph TB
  A["StaffEditScreen<br/>Standard rate + Premium rates group"] --> B["RTDB staff/{uid}/{staffId}"]
  B --> C["StaffBloc stream"]
  C --> D["QuoteStaffEditScreen<br/>pick a staff member"]
  D --> E["Rate method dropdown<br/>selectedItemBuilder shows 'Weekend rate'<br/>menu items show 'Weekend · £220'"]
  E --> F["onSelect → rateFor(method)<br/>refills the rate field"]
  F --> G["QuoteStaffDraft { staffId, name,<br/>rate, rateType, quantity }<br/>lineTotal = rate x quantity"]
  G --> H["RTDB quotes/{uid}/{id}/staff[]"]

  H --> I["Flutter _StaffRow<br/>badge 'Weekend rate'<br/>+ 'N days × £rate'"]
  H --> J["QuotePdfService<br/>'Name — Weekend rate'<br/>unit price = rate"]
  H --> K["viewSharedQuote / viewSharedInvoice<br/>server-rendered HTML<br/>.rate-badge + 'Labour charges'<br/>+ 'no hidden markup' note"]`,
    },
    {
      title: 'What staff are not',
      html: `
<p>
  There is real infrastructure on disk for staff-as-users — <code>StaffInvitationModel</code>,
  a <code>staff/{uid}/invitations</code> path, a <code>TeamOnboardingScreen</code> and a
  <code>/teamOnboarding</code> route — but the live product does not use it. A staff member
  today is data the owner types, not a person who signs in. Nothing in the auth gate, the
  subscription gate or the record books accounts for a second human on an account.
</p>`,
      caption: 'Present in code vs. present in the product',
      mermaid: `graph LR
  subgraph LIVE["Live"]
    A["Staff = rate card"]
    B["Owner types the details"]
    C["Used only on labour lines"]
  end
  subgraph DORMANT["On disk, unreached"]
    D["StaffInvitationModel"]
    E["staff/{uid}/invitations"]
    F["/teamOnboarding route"]
    G["BusinessRole on UserDetailsModel"]
  end
  A --> C
  B --> A
  D -.-> E -.-> F -.-> G`,
    },
  ],
});
