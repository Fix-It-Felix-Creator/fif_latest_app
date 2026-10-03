window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'FOUNDATION',
  nav: 'Technology stack',
  kicker: 'frameworks and packages',
  title: 'Technology stack',
  summary: `
    A deliberately narrow stack: Flutter for the client, Firebase for everything server-side,
    and exactly one non-Firebase third party in the request path (Resend, for email). There is
    no separate application server, no SQL, no ORM, no GraphQL. Every server-side behaviour
    that cannot be trusted to the client lives in one TypeScript Express app deployed twice as
    Cloud Functions.`,
  blocks: [
    {
      title: 'Client — Flutter',
      html: `
<table>
  <tr><th>Concern</th><th>Package</th><th>What it actually does here</th></tr>
  <tr><td>UI kit</td><td><code>shadcn_ui ^0.40.2</code></td><td>The app is a <code>ShadApp</code>, not a <code>MaterialApp</code>. Material is still built underneath via <code>materialThemeBuilder</code>.</td></tr>
  <tr><td>Type</td><td><code>google_fonts</code></td><td>Poppins, with bundled Roboto for PDF rendering</td></tr>
  <tr><td>State</td><td><code>flutter_bloc ^9.1.1</code>, <code>equatable</code></td><td>16 BLoCs, all provided once at the root of the widget tree</td></tr>
  <tr><td>Theming</td><td><code>provider</code></td><td>Only for <code>ThemeProvider</code> / <code>ThemeScope</code> (light / dark / system)</td></tr>
  <tr><td>Auth</td><td><code>firebase_auth</code>, <code>google_sign_in 6.2.2</code>, <code>sign_in_with_apple ^7.0.1</code>, <code>crypto</code></td><td>Email + Google + Apple. <code>crypto</code> generates the Apple nonce.</td></tr>
  <tr><td>Data</td><td><code>firebase_database ^12.0.3</code></td><td>Realtime Database — every record book streams from it</td></tr>
  <tr><td>Files</td><td><code>firebase_storage</code></td><td>Profile images, tool photos / videos / files, verification documents</td></tr>
  <tr><td>Push</td><td><code>firebase_messaging ^16.0.3</code></td><td>FCM token sync + foreground / background / tap handling</td></tr>
  <tr><td>Remote flags</td><td><code>firebase_remote_config</code></td><td>Backend URL, DB URL, force-update, maintenance, support links</td></tr>
  <tr><td>Attestation</td><td><code>firebase_app_check</code></td><td>Play Integrity (Android) / DeviceCheck (iOS); debug providers in debug builds</td></tr>
  <tr><td>Money</td><td><code>in_app_purchase ^3.2.1</code></td><td>StoreKit + Play Billing. Replaced <code>flutter_stripe</code> entirely.</td></tr>
  <tr><td>HTTP</td><td><code>http ^1.5.0</code></td><td>Every call to the Cloud Functions Express app, plus OS Places lookups</td></tr>
  <tr><td>Local cache</td><td><code>hive</code>, <code>shared_preferences</code></td><td><code>CacheService</code> caches the user record for offline / fast start</td></tr>
  <tr><td>Connectivity</td><td><code>connectivity_plus</code></td><td>Gates network reads; repositories fall back to cache when offline</td></tr>
  <tr><td>Media in</td><td><code>image_picker</code>, <code>file_picker</code>, <code>flutter_image_compress</code>, <code>video_thumbnail</code>, <code>mobile_scanner</code></td><td>Tools locker uploads and document capture</td></tr>
  <tr><td>Media out</td><td><code>video_player</code>, <code>cached_network_image</code>, <code>shimmer</code></td><td>Playback and list placeholders</td></tr>
  <tr><td>Documents</td><td><code>pdf ^3.11.3</code>, <code>printing</code>, <code>share_plus</code></td><td>Quote / invoice PDFs are rendered <em>on the device</em>, never server-side</td></tr>
  <tr><td>Local alerts</td><td><code>flutter_local_notifications</code>, <code>timezone</code></td><td>Daily to-do reminder, scheduled locally</td></tr>
  <tr><td>Web views</td><td><code>webview_flutter</code>, <code>url_launcher</code></td><td>Terms / privacy / help pages, store deep links, maps, tel: and mailto:</td></tr>
  <tr><td>Env</td><td><code>flutter_dotenv ^6.0.0</code></td><td>Loads <code>config/staging/.env</code> or <code>config/production/.env</code> at boot</td></tr>
  <tr><td>Device</td><td><code>device_info_plus</code>, <code>package_info_plus</code></td><td>Session records and build-number env selection</td></tr>
  <tr><td>Review</td><td><code>in_app_review</code></td><td>The Rate Us row in Settings</td></tr>
</table>`,
    },
    {
      title: 'Server — Cloud Functions',
      html: `
<table>
  <tr><th>Concern</th><th>Choice</th><th>Notes</th></tr>
  <tr><td>Runtime</td><td>Cloud Functions v2, Node, TypeScript</td><td>Region <code>europe-west1</code>, 512 MiB, 60 s timeout</td></tr>
  <tr><td>Routing</td><td><code>express</code> + <code>cors</code></td><td>One <code>buildApp(env)</code> factory, exported as two functions</td></tr>
  <tr><td>Admin access</td><td><code>firebase-admin</code></td><td><code>getDatabaseWithUrl</code> per environment, <code>getAuth</code>, <code>getMessaging</code></td></tr>
  <tr><td>Env binding</td><td><code>node:async_hooks</code> <code>AsyncLocalStorage</code></td><td>The active environment is bound for the whole async request lifetime</td></tr>
  <tr><td>Email</td><td><code>resend</code></td><td>API key held as a Cloud Functions secret</td></tr>
  <tr><td>Store APIs</td><td>App Store Server API, Google Play Developer API</td><td>Credentials as secrets: <code>APPSTORE_SECRETS</code>, <code>GOOGLE_PLAY_SECRETS</code></td></tr>
  <tr><td>Triggers</td><td><code>onValueWritten</code></td><td>One per RTDB instance, watching <code>verificationStatus</code></td></tr>
</table>`,
    },
    {
      title: 'How the pieces are wired together',
      html: `
<p>
  Nothing in the app talks to a third party directly except the two stores (through the OS)
  and the Ordnance Survey postcode API. Email, store validation and anything that could grant
  entitlement is routed through the Express app so it can be verified with a service
  credential the client never holds.
</p>`,
      caption: 'Runtime dependency graph — what talks to what',
      mermaid: `graph TB
  subgraph DEVICE["Device"]
    APP["Flutter app"]
    SK["StoreKit / Play Billing<br/>(OS purchase sheet)"]
    LOCAL["Hive + SharedPreferences cache"]
    PDFGEN["pdf + printing<br/>(local render)"]
  end

  subgraph FIREBASE["Firebase — project fifcloud, europe-west1"]
    FA["Firebase Auth"]
    RTDB["Realtime Database<br/>staging + production instances"]
    FS["Cloud Storage"]
    FCM["Cloud Messaging"]
    RC["Remote Config"]
    AC["App Check"]
    FN["Cloud Functions<br/>api / apiProd"]
    HOST["Hosting fifcloud.web.app"]
  end

  subgraph THIRD["Third parties"]
    RESEND["Resend<br/>transactional email"]
    APPLE["App Store Server API"]
    GOOGLE["Google Play Developer API"]
    OS["Ordnance Survey Places API"]
    GMAPS["Google Maps Static API"]
  end

  APP --> FA
  APP --> RTDB
  APP --> FS
  APP --> FCM
  APP --> RC
  APP --> AC
  APP --> LOCAL
  APP --> PDFGEN
  APP --> OS
  APP --> GMAPS
  APP -->|"Bearer ID token"| FN
  APP --> SK
  SK -->|"transaction"| APP

  FN --> RTDB
  FN --> FA
  FN --> FCM
  FN --> RESEND
  FN --> APPLE
  FN --> GOOGLE
  HOST -->|"rewrite /q/:token"| FN
  APPLE -->|"server notification"| FN
  GOOGLE -->|"server notification"| FN
  RESEND -->|"link in email"| HOST`,
    },
    {
      title: 'Deliberate omissions',
      html: `
<p>
  The stack is as interesting for what it dropped as for what it kept. The task log records
  102 pub dependencies removed in one pass, and a full payments migration.
</p>
<table>
  <tr><th>Removed</th><th>Replaced by</th><th>Why</th></tr>
  <tr><td>Stripe (<code>flutter_stripe</code>, native Stripe service, payment sheet)</td><td><code>in_app_purchase</code></td><td>App Store Guideline 3.1.1 — digital subscriptions must use IAP</td></tr>
  <tr><td>Interactive Google Maps SDK</td><td>Google Maps Static API (URL → image)</td><td>A map thumbnail is all the UI needs; drops a heavy native dependency</td></tr>
  <tr><td>Swift Package Manager</td><td>CocoaPods</td><td>Flutter's generated SPM package pins iOS 13; Firebase SPM products need 15, which broke Xcode archives</td></tr>
  <tr><td>Server-side PDF rendering</td><td>On-device <code>pdf</code> + <code>printing</code></td><td>No server round trip, works offline, shared through the OS sheet</td></tr>
  <tr><td>Date of birth collection</td><td>Nothing</td><td>Guideline 5.1.1(v) — do not require personal data that is not essential</td></tr>
</table>`,
    },
  ],
});
