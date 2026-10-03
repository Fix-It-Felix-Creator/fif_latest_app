window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PRODUCTIVITY',
  nav: 'Notifications',
  kicker: 'in-app records + FCM push',
  title: 'Notifications — in-app and push',
  summary: `
    Every server-originated notification does two things at once: it writes a durable record
    under <code>notifications/{uid}</code> so the user can read it later, and it fans out a
    native push to every device that user has registered. The two halves are always written
    together, which is why an unread badge and a push notification never disagree.`,
  blocks: [
    {
      title: 'The two halves',
      html: `
<table>
  <tr><th></th><th>In-app record</th><th>Native push</th></tr>
  <tr><td>Stored at</td><td><code>notifications/{uid}/{id}</code></td><td>Nowhere — it is a delivery</td></tr>
  <tr><td>Fields</td><td>title, body, type, payload, createdAt, read, readAt</td><td>notification + data payload</td></tr>
  <tr><td>Read by</td><td><code>NotificationsBloc</code> stream → list + badge</td><td>The OS</td></tr>
  <tr><td>Survives?</td><td>Until cleared</td><td>Until dismissed</td></tr>
  <tr><td>Needs the app open?</td><td>To be seen, yes</td><td>No</td></tr>
</table>`,
    },
    {
      title: 'Pipeline — FCM token registration',
      html: `
<p>
  A push can only be delivered to a token, and tokens rotate. The service therefore syncs on
  three triggers — initialise, <code>onTokenRefresh</code>, and every transition of
  <code>authStateChanges</code> to a signed-in user — and stores each device under a hashed key
  so re-registering the same token overwrites rather than duplicating.
</p>
<p>
  Teardown is explicit, not reactive. The auth listener cannot clean up on sign-out because by
  the time it fires with <code>null</code> the write permission for that user's subtree is
  already gone. Hence <code>AuthRepository.onBeforeSignOut</code> calls
  <code>clearToken()</code> <em>before</em> Firebase Auth actually signs out.
</p>`,
      caption: 'Token lifecycle',
      mermaid: `sequenceDiagram
  autonumber
  participant H as Home screen
  participant P as PushNotificationsService
  participant FCM as Firebase Messaging
  participant DB as RTDB users/{uid}/fcmTokens/{key}
  participant A as AuthRepository

  Note over H,P: init is DEFERRED to the home screen<br/>so a first-run user is not hit with<br/>a permission dialog before seeing the app
  H->>P: initialise()
  P->>FCM: requestPermission(alert, badge, sound)
  P->>FCM: setForegroundNotificationPresentationOptions
  P->>FCM: getInitialMessage() — launched from a push?
  FCM-->>P: RemoteMessage or null
  P->>FCM: listen onMessageOpenedApp
  P->>FCM: listen onTokenRefresh
  P->>P: listen authStateChanges

  P->>FCM: getToken()
  FCM-->>P: token
  P->>DB: set { token, platform, createdAt, lastSeenAt }

  Note over FCM,P: later — the token rotates
  FCM-->>P: onTokenRefresh(newToken)
  P->>DB: set under the new hashed key

  A->>P: onBeforeSignOut → clearToken()
  P->>DB: remove this device's entry
  Note over A: only THEN does FirebaseAuth.signOut() run`,
    },
    {
      title: 'Pipeline — admin broadcast',
      html: `
<p>
  <code>POST /notifications/send</code> is the only admin-gated endpoint in the whole API. It
  sits behind <code>requireAdmin</code>, which checks the caller's uid against
  <code>/config/admin/systemRoles</code>. It accepts either an explicit
  <code>toUserIds</code> array or <code>toAll: true</code>.
</p>
<p>
  Note the housekeeping in step 8: FCM reports
  <code>registration-token-not-registered</code> for tokens belonging to uninstalled apps, and
  those are pruned in the same pass. Without that, the token list grows forever and every
  broadcast gets slower.
</p>`,
      caption: 'Admin broadcast → records + push + stale-token cleanup',
      mermaid: `sequenceDiagram
  autonumber
  participant AD as Admin caller
  participant FN as POST /notifications/send
  participant RA as requireAdmin
  participant CFG as RTDB config/admin/systemRoles
  participant DB as RTDB notifications/{uid}
  participant TOK as RTDB users/{uid}/fcmTokens
  participant FCM as Firebase Messaging
  participant D as Devices

  AD->>FN: { title, body, type, payload,<br/>toUserIds or toAll } + Bearer
  FN->>RA: verify the caller
  RA->>CFG: is this uid an admin?
  alt not an admin
    CFG-->>FN: no → 403
  else admin
    FN->>FN: resolve recipients<br/>(listAllUserIds() when toAll)
    FN->>DB: ONE atomic multi-path update —<br/>a record per recipient
    FN->>TOK: read every recipient's tokens
    TOK-->>FN: token list
    FN->>FCM: send a Message per token
    FCM-->>D: native push
    FCM-->>FN: per-token results
    FN->>TOK: delete tokens reported as<br/>registration-token-not-registered
    FN-->>AD: { success, sent, pushSent, pushFailed }
  end`,
    },
    {
      title: 'Pipeline — a single background notification',
      html: `
<p>
  Most notifications are not broadcasts. They come from a background flow — a customer opened
  a quote, a customer accepted it — where there is no authenticated caller at all.
  <code>notifyOneUser()</code> is the helper for that case: same two-part write, no auth
  check, because the trigger is a server-side event rather than a request.
</p>`,
      caption: 'notifyOneUser — the single-recipient path',
      mermaid: `graph TB
  A["Background flow<br/>viewSharedQuote / respondToShare"] --> B["notifyOneUser({ uid, title, body,<br/>type, payload })"]
  B --> C["push() a key under<br/>notifications/{uid}"]
  C --> D["set { title, body, type, payload,<br/>createdAt, read: false, readAt: null }"]
  B --> E["read users/{uid}/fcmTokens"]
  E --> F["FCM send per token"]
  F --> G["prune stale tokens"]
  D --> H["NotificationsBloc stream tick"]
  H --> I["NotificationBadge count increases"]
  F --> J["device push banner"]`,
    },
    {
      title: 'Pipeline — reading, and the read/clear endpoints',
      html: `
<p>
  Marking read and clearing go through Cloud Functions rather than direct writes. That keeps
  the mutation rules in one place — mark-all and clear-all are single server calls instead of
  a client loop over an unbounded list.
</p>
<table>
  <tr><th>Endpoint</th><th>Body</th><th>Effect</th></tr>
  <tr><td><code>POST /notifications/mark-read</code></td><td><code>{ id }</code> or empty for all</td><td>Sets <code>read: true</code>, <code>readAt: now</code></td></tr>
  <tr><td><code>POST /notifications/clear</code></td><td><code>{ id }</code> or empty for all</td><td>Removes the record(s)</td></tr>
</table>`,
      caption: 'Notification list UI',
      mermaid: `graph TB
  A["NotificationsBloc<br/>watchAll() on notifications/{uid}"] --> B["NotificationsScreen"]
  B --> C["day grouping:<br/>Today / Yesterday / full date"]
  B --> D["NotificationBadge<br/>unread count on the app bar"]
  C --> E["tap a row"]
  E --> F["NotificationDetailScreen<br/>long body + cached image"]
  F --> G["POST /notifications/mark-read { id }"]
  B --> H["Clear all"]
  H --> I["POST /notifications/clear {}"]
  G --> A
  I --> A`,
    },
    {
      title: 'Foreground, background and terminated',
      html: `
<p>
  Three delivery contexts, three code paths — and one of them has to be registered before
  <code>runApp</code> because it runs in a separate Dart isolate.
</p>`,
      caption: 'Push delivery by app state',
      mermaid: `graph TB
  A["FCM delivers"] --> B{"app state"}
  B -->|"foreground"| C["onMessage<br/>iOS shows a banner because<br/>setForegroundNotificationPresentationOptions<br/>was set"]
  B -->|"background"| D["firebaseMessagingBackgroundHandler<br/>SEPARATE ISOLATE — must be a<br/>top-level function registered<br/>before runApp"]
  B -->|"terminated"| E["OS shows the notification"]
  C --> F["user taps"]
  D --> F
  E --> G["app launches"]
  G --> H["getInitialMessage() returns it"]
  F --> I["onMessageOpenedApp → _handleTap"]
  H --> I
  I --> J{"data.type"}
  J -->|"quote*"| K["quote_notification_nav → the quote"]
  J -->|"invoice*"| L["invoice_notification_nav → the invoice"]
  J -->|"other"| M["/notifications"]`,
    },
  ],
});
