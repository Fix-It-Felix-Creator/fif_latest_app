window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Customers',
  kicker: 'the address book',
  title: 'Customers — the address book',
  summary: `
    The simplest record book in the app, and the template every other one follows: a live
    stream from one RTDB path, four operations, no server involvement. Its one piece of
    substance is the address — the same Ordnance Survey postcode lookup used in onboarding
    captures coordinates, which is what makes "Get directions" work later.`,
  blocks: [
    {
      title: 'The record',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>name</code>, <code>email</code>, <code>phone</code></td><td><code>email</code> is what the quote / invoice send flow uses as the recipient</td></tr>
  <tr><td><code>company</code></td><td>Optional — commercial customers</td></tr>
  <tr><td><code>addressLine1</code>, <code>addressLine2</code>, <code>city</code>, <code>county</code>, <code>postcode</code></td><td>Structured, from the OS lookup or typed manually</td></tr>
  <tr><td><code>formattedAddress</code></td><td>Pre-joined display string</td></tr>
  <tr><td><code>latitude</code>, <code>longitude</code></td><td>Powers static-map previews and directions</td></tr>
  <tr><td><code>notes</code></td><td>Free text</td></tr>
  <tr><td><code>createdAt</code>, <code>updatedAt</code></td><td>Client-stamped</td></tr>
</table>
<p>
  The model also parses a legacy shape: if <code>addressLine1</code> is missing it falls back
  to an older unstructured address field, so records written by earlier builds still load.
</p>`,
    },
    {
      title: 'Pipeline — the canonical CRUD loop',
      html: `
<p>
  This is the pattern to internalise. Customers, staff, pricing items, to-dos, notes, photos,
  videos, files and journal entries are all <em>this</em>, with a different path and a
  different model. Once you know it, those six items in the list hold no surprises.
</p>`,
      caption: 'Canonical record-book CRUD',
      mermaid: `sequenceDiagram
  autonumber
  participant S as CustomersScreen
  participant B as CustomersBloc
  participant R as CustomersRepository
  participant DB as RTDB customers/{uid}
  participant E as CustomerEditScreen

  S->>B: StartWatching (on first build)
  B->>R: watchAll()
  R->>DB: ref.onValue
  DB-->>R: full collection snapshot
  R->>R: map to List of Customer, sort by name
  R-->>B: stream event
  B-->>S: CustomersLoaded(list)

  S->>E: tap + or a row
  E->>R: create(c) / update(c) / delete(id)
  R->>DB: push().set() / update() / remove()
  Note over R,B: no state is emitted here —<br/>the OPEN listener does the work
  DB-->>R: onValue fires again
  R-->>B: new list
  B-->>S: CustomersLoaded — the row appears / changes / vanishes`,
    },
    {
      title: 'Pipeline — address capture and directions',
      html: `
<p>
  <code>AddressSearchScreen</code> wraps the same <code>AddressGeocoder</code> used by
  onboarding. Once coordinates exist on the record, three different screens offer a
  "Get directions" action — and all three had to be taught the same platform lesson.
</p>`,
      caption: 'Directions — the platform branch',
      mermaid: `graph TB
  A["Get directions tapped<br/>(customer edit / new job /<br/>tradesman home)"] --> B{"Platform.isAndroid?"}
  B -->|"yes"| C["_openGoogleMaps() directly"]
  B -->|"no — iOS"| D["Cupertino action sheet"]
  D --> E["Apple Maps"]
  D --> F["Google Maps"]
  C --> G["url_launcher external"]
  E --> G
  F --> G
  H["Before the fix, Android also showed<br/>an 'Apple Maps' row — an app that<br/>cannot exist on that platform"] -.-> B`,
    },
    {
      title: 'How the customer flows into everything else',
      html: `
<p>
  A customer is never referenced by id from a quote, job or invoice — it is
  <strong>snapshotted</strong> into them. That is why renaming a customer does not silently
  rewrite the name on an invoice sent six months ago, and why the customer book can be edited
  freely without auditing what it might break.
</p>`,
      caption: 'Snapshot fan-out',
      mermaid: `graph LR
  A["Customer record"] -->|"snapshot"| Q["Quote.customer"]
  A -->|"snapshot"| J["Job.customer"]
  A -->|"snapshot"| I["Invoice.customer"]
  A -->|"email"| M["send-email recipient"]
  A -->|"lat / lng"| D["Directions + static map"]
  A -->|"name + address"| P["PDF header block"]`,
    },
  ],
});
