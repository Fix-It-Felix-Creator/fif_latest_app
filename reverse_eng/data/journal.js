window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PRODUCTIVITY',
  nav: 'Journal',
  kicker: 'the diary tab',
  title: 'Journal — the diary',
  summary: `
    A dated diary of events: site visits, deliveries, meetings. It is a tab in its own right
    on the home shell, sitting between Jobs and Tools. Structurally another record book, with
    one design choice worth calling out — the date is stored as a <em>string</em>, not a
    timestamp.`,
  blocks: [
    {
      title: 'The record',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>date</code></td><td>A <code>YYYY-MM-DD</code> <strong>string</strong> — the grouping key for the day list</td></tr>
  <tr><td><code>allDay</code></td><td>When true, the start / end times are ignored</td></tr>
  <tr><td><code>startAt</code>, <code>endAt</code></td><td>Epoch ms, only meaningful when not all-day</td></tr>
  <tr><td><code>customerId</code>, <code>customerName</code></td><td>Optional link to the customer book — the name is denormalised so the list renders without a second lookup</td></tr>
  <tr><td><code>location</code>, <code>notes</code></td><td>Free text</td></tr>
</table>
<p>
  Storing the date as a string makes day-grouping and querying trivial (string prefixes sort
  correctly) at the cost of losing timezone information. The model exposes helpers that parse
  it back into a <code>DateTime</code>, compute the end of that day, and decide whether an
  entry is past.
</p>`,
    },
    {
      title: 'Pipeline — create a journal entry',
      html: `
<p>
  Reachable two ways: the <code>+</code> on the Journal tab, or a named route
  <code>/journalEdit</code> with <code>JournalEditArgs</code> — which is how other screens hand
  off into it pre-filled.
</p>`,
      caption: 'Journal entry create / edit',
      mermaid: `graph LR
  A["Journal tab or /journalEdit"] --> B["JournalEventEditScreen"]
  B --> C["title, date (YYYY-MM-DD),<br/>all-day toggle, start / end,<br/>optional customer, location, notes"]
  C --> D["JournalRepository.create / update"]
  D --> E["RTDB journalEvents/{uid}/{entryId}"]
  E --> F["JournalBloc stream tick"]
  F --> G["JournalPage — grouped by date string"]
  C -.->|"customer picked"| H["customerId + customerName<br/>denormalised onto the entry"]`,
    },
  ],
});
