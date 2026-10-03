window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PRODUCTIVITY',
  nav: 'To-dos',
  kicker: 'checklist + local daily reminder',
  title: 'To-dos and the local reminder',
  summary: `
    A plain checklist — title, optional notes, optional due date, a colour tag — plus the only
    notification in the app that never touches a server. The daily reminder is scheduled on the
    device with <code>flutter_local_notifications</code>, so it fires whether or not there is a
    network, and costs nothing to run.`,
  blocks: [
    {
      title: 'The record',
      html: `
<table>
  <tr><th>Field</th><th>Notes</th></tr>
  <tr><td><code>title</code></td><td>Required</td></tr>
  <tr><td><code>notes</code></td><td>Optional detail</td></tr>
  <tr><td><code>dueAt</code></td><td>Epoch ms; drives the overdue styling</td></tr>
  <tr><td><code>completed</code>, <code>completedAt</code></td><td>Toggled with <code>setCompleted()</code>, a targeted partial update</td></tr>
  <tr><td><code>tagColor</code></td><td>Stored as an int colour value</td></tr>
</table>
<p>
  All timestamps on this model are epoch integers rather than ISO strings — worth noting
  because quotes and invoices use <code>DateTime</code> objects serialised differently. Both
  conventions exist in the codebase.
</p>`,
    },
    {
      title: 'Pipeline — the daily reminder',
      html: `
<p>
  Three details make this robust. It <strong>cancels before scheduling</strong>, so there is
  only ever one queued reminder under a single fixed notification id — re-opening the settings
  screen cannot stack duplicates. It computes the next fire time in the device's local zone via
  the <code>timezone</code> package, rolling to tomorrow if today's slot has passed. And it
  uses <code>matchDateTimeComponents: DateTimeComponents.time</code> so a single schedule call
  repeats daily rather than needing a re-arm.
</p>`,
      caption: 'Set a reminder time → local schedule → daily fire → deep link',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as TodoReminderSettingsScreen
  participant T as TodoReminderService
  participant TZ as timezone package
  participant OS as OS notification scheduler
  participant N as Navigator

  U->>S: pick a time, enable the reminder
  S->>T: schedule(hour, minute, title, body)
  T->>T: initialise() if needed<br/>(channel + permissions)
  T->>OS: cancel(_notificationId)
  Note over T,OS: cancel-first guarantees<br/>exactly one queued reminder
  T->>TZ: _nextInstance(hour, minute)
  TZ-->>T: today at that time, or tomorrow<br/>if it has already passed
  T->>OS: zonedSchedule(id, title, body, first,<br/>matchDateTimeComponents: time,<br/>payload: "todos")
  Note over OS: Android inexactAllowWhileIdle<br/>iOS absoluteTime interpretation

  loop every day at that local time
    OS-->>U: notification appears
  end
  U->>OS: tap it
  OS->>T: _handleTap(response) with payload "todos"
  T->>N: navigate to /todos`,
    },
    {
      title: 'Local vs. remote notifications',
      html: `
<p>
  The app has two entirely separate notification systems and they share nothing but the user's
  attention. Knowing which is which saves a lot of debugging.
</p>
<table>
  <tr><th></th><th>To-do reminder</th><th>Everything else</th></tr>
  <tr><td>Package</td><td><code>flutter_local_notifications</code></td><td><code>firebase_messaging</code></td></tr>
  <tr><td>Origin</td><td>The device itself</td><td>A Cloud Function calling FCM</td></tr>
  <tr><td>Needs network?</td><td>No</td><td>Yes</td></tr>
  <tr><td>Channel</td><td>Its own to-do channel</td><td>The default FCM channel declared in the Android manifest</td></tr>
  <tr><td>Tap handling</td><td><code>TodoReminderService._handleTap</code></td><td><code>PushNotificationsService._handleTap</code></td></tr>
  <tr><td>Leaves a record?</td><td>No</td><td>Yes — a row under <code>notifications/{uid}</code></td></tr>
</table>`,
      caption: 'Two notification paths',
      mermaid: `graph TB
  subgraph LOCAL["Local — device only"]
    A["TodoReminderService.schedule"] --> B["OS scheduler"]
    B --> C["daily notification"]
    C --> D["tap → /todos"]
  end
  subgraph REMOTE["Remote — server driven"]
    E["Cloud Function<br/>notifyOneUser / sendNotification"] --> F["RTDB notifications/{uid}"]
    E --> G["FCM fan-out to fcmTokens"]
    G --> H["push on the device"]
    H --> I["tap → PushNotificationsService<br/>→ deep link by payload type"]
    F --> J["NotificationsScreen list + badge"]
  end`,
    },
  ],
});
