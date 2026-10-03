window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'WORKSPACE',
  nav: 'Jobs & time clock',
  kicker: 'the unit of work',
  title: 'Jobs and the time clock',
  summary: `
    A job is the unit of work: a customer, a title, a start date, a status, and everything
    that accumulated while doing it — logged time, expenses, and attachments pulled from the
    tools locker. It is also the hinge between a quote and an invoice. The time clock is the
    most interactive feature in the app: clock in on site, a live timer runs on the home tab,
    clock out and the session is closed into a permanent log.`,
  blocks: [
    {
      title: 'The job record',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>reference</code></td><td>Auto-numbered — <code>nextSequence()</code> scans every existing job, takes the trailing digits of each reference and returns max + 1</td></tr>
  <tr><td><code>status</code></td><td><code>draft</code> → <code>active</code> → <code>completed</code> / <code>cancelled</code></td></tr>
  <tr><td><code>customer</code></td><td>An embedded snapshot, not a reference — editing the customer book later does not rewrite history</td></tr>
  <tr><td><code>clockInAt</code></td><td>Non-null means a session is running right now</td></tr>
  <tr><td><code>timeEntries</code></td><td>List of closed <code>JobTimeEntry(start, end)</code> sessions</td></tr>
  <tr><td><code>expenses</code></td><td><code>JobExpense</code> rows logged against the job</td></tr>
  <tr><td><code>attachedPhotos / Videos / Files / Notes</code></td><td>Picked from the tools locker</td></tr>
  <tr><td><code>linkedQuoteIds</code> / <code>linkedInvoiceIds</code></td><td>The paper trail on both sides</td></tr>
</table>`,
    },
    {
      title: 'Pipeline — create and edit a job',
      html: `
<p>
  The same screen, <code>NewJobScreen</code>, handles both. Passing <code>NewJobArgs</code>
  with an <code>existing</code> job puts it in edit mode. That distinction matters for the
  discard prompt: a new job asks "discard?" if any field has content, while an edit compares
  the form against <code>widget.existing</code> — otherwise opening any job and pressing back
  always prompted.
</p>`,
      caption: 'Create / edit job',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant JS as JobsScreen
  participant NJ as NewJobScreen
  participant R as JobsRepository
  participant DB as RTDB jobs/{uid}/{jobId}
  participant B as JobsBloc
  participant HOME as Home tab

  U->>JS: tap +
  JS->>R: nextSequence()
  R->>DB: read all jobs, max trailing number
  DB-->>JS: n
  JS->>NJ: push with NewJobArgs(nextSequence: n + 1)
  U->>NJ: title, description, customer,<br/>start date, attachments
  U->>NJ: Save
  NJ->>R: create(job) or update(job)
  R->>DB: push().set(json) / update(json)
  Note over R,DB: _jobToRtdb also serialises<br/>clockInAt + timeEntries, so a full-doc<br/>update from the edit screen<br/>cannot wipe a running clock
  DB-->>B: watchAll() stream tick
  B-->>JS: JobsLoaded(list)
  B-->>HOME: live-timer section re-evaluates`,
    },
    {
      title: 'Pipeline — clock in and clock out',
      html: `
<p>
  Both operations are partial <code>update()</code> calls, never full-document writes — a
  clock action must not stamp on fields the user is editing elsewhere. Clock-in also flips the
  status to <code>active</code>, because starting work is what "active" means here.
</p>
<p>
  Clock-in is one tap. Clock-out is <strong>confirmed</strong> (<code>confirmClockOut()</code>
  shows a "Keep running" / "Clock out" dialog) because an accidental clock-out silently loses
  the running session's elapsed time.
</p>`,
      caption: 'Clock in → live timer → confirm → clock out → time log',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant JC as JobClockControl
  participant R as JobsRepository
  participant DB as RTDB jobs/{uid}/{id}
  participant B as JobsBloc
  participant HA as HomeActiveJobs (home tab)
  participant TL as JobTimeLogScreen

  U->>JC: tap Clock in
  JC->>R: clockIn(id)
  R->>DB: update { clockInAt: now,<br/>status: active, updatedAt: now }
  DB-->>B: stream tick
  B-->>HA: job.isClockedIn = true
  loop every 1 second
    HA->>HA: _SecondTicker rebuilds<br/>formatJobClock → MM:SS / H:MM:SS
  end
  Note over JC: while clocked in the status row locks<br/>("Clock out to change the status")

  U->>HA: tap Clock out
  HA->>HA: confirmClockOut() warning dialog
  U->>HA: confirm
  HA->>R: clockOut(job)
  R->>R: append JobTimeEntry(start: clockInAt, end: now)
  R->>DB: update { clockInAt: null,<br/>timeEntries: [...], updatedAt: now }
  DB-->>B: stream tick
  B-->>HA: timer disappears
  U->>TL: open Time log from the job Details tab
  TL-->>U: total (incl. any live session) +<br/>newest-first session list`,
    },
    {
      title: 'The live-timer surface on the home tab',
      html: `
<p>
  The clock is not buried in the job screen — it sits directly under the greeting inside the
  orange hero, above the quick actions, so a running job is the first thing seen on opening
  the app.
</p>
<ul>
  <li>Nothing running → the section is hidden entirely.</li>
  <li>One job running → a single card with an elapsed timer and a Clock out button.</li>
  <li>Two or more → an expandable header, "<em>N jobs in progress</em>" / "<em>+N more
      working</em>", each row tappable straight into that job.</li>
</ul>
<p>
  Timers tick at <strong>1 s</strong> and display seconds. The earlier build ticked every 30 s
  and showed minutes only, so a fresh clock-in read "0m" for a full minute and looked frozen.
  Logged totals and summaries still use the coarser "Hh Mm" format.
</p>`,
      caption: 'Job status vs. clock coupling',
      mermaid: `stateDiagram-v2
  [*] --> Draft
  Draft --> Active: clock in (status forced to active)
  Draft --> Active: manual status change
  Active --> Active: clock out (session appended)
  Active --> Completed: manual status change<br/>(blocked while clocked in)
  Active --> Cancelled: manual status change<br/>(blocked while clocked in)
  Completed --> [*]
  Cancelled --> [*]
  note right of Completed
    JobClockControl is disabled on
    Completed / Cancelled — lock icon
    plus an explanatory note
  end note`,
    },
    {
      title: 'Expenses and attachments',
      html: `
<p>
  Two smaller pipelines hang off the job screen. Expenses are edited on
  <code>ExpenseEditScreen</code> and stored inline on the job document. Attachments are
  <em>picked</em>, not uploaded, from the tools locker — the picker screens
  (<code>photos_picker_screen</code>, <code>videos_picker_screen</code>,
  <code>files_picker_screen</code>, <code>notes_picker_screen</code>) return references to
  media already in Storage, so the same photo can back a job, a quote and an invoice without
  being uploaded three times.
</p>`,
      caption: 'Attaching from the tools locker',
      mermaid: `graph LR
  A["Job / Quote / Invoice screen<br/>tap Attach"] --> B["Picker screen<br/>photos / videos / files / notes"]
  B --> C["Reads the existing<br/>tools BLoC list"]
  C --> D["User multi-selects"]
  D --> E["Returns ToolPhoto / ToolVideo /<br/>ToolFile / ToolNote references"]
  E --> F["Stored on the record's<br/>attached* array"]
  F --> G["Storage object is shared —<br/>uploaded once, referenced many times"]`,
    },
    {
      title: 'Where a job sits in the money path',
      html: `
<p>
  Jobs do not create quotes or invoices automatically — the tradesperson does that — but the
  ids are linked on both sides so the record stays navigable in either direction.
</p>`,
      caption: 'Quote ↔ job ↔ invoice linkage',
      mermaid: `graph LR
  Q["Quote<br/>accepted"] -->|"linkedQuoteIds"| J["Job"]
  J -->|"time entries + expenses<br/>inform the amounts"| I["Invoice"]
  I -->|"linkedInvoiceIds"| J
  C["Customer snapshot"] --> Q
  C --> J
  C --> I
  T["Tools locker"] --> J
  T --> Q
  T --> I`,
    },
  ],
});
