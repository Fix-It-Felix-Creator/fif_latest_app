window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'FOUNDATION',
  nav: 'Architecture',
  kicker: 'layers and the rules between them',
  title: 'Architecture — layers, BLoCs and repositories',
  summary: `
    Four layers, one direction of travel: <strong>screen → BLoC → repository → Firebase</strong>.
    Screens never touch Firebase. Repositories never import Flutter widgets. Every BLoC is
    constructed once, at the root of the widget tree, with its repository injected — so any
    screen anywhere in the app can read the same live stream without re-subscribing.`,
  blocks: [
    {
      title: 'The layer diagram',
      html: `
<p>
  <code>fix_it_felix_app.dart</code> is the composition root. It builds 18 repositories, wraps
  them in <code>MultiRepositoryProvider</code>, then builds 16 BLoCs in
  <code>MultiBlocProvider</code> on top of them. Below that sits <code>ShadApp</code> with
  <code>onGenerateRoute: RouteGenerator.generateRoute</code> and an
  <code>AppStatusWrapper</code> that can slam a maintenance or force-update screen over the
  whole app at any moment.
</p>`,
      caption: 'Layered architecture with the composition root',
      mermaid: `graph TB
  subgraph L1["Presentation — lib/screens, lib/widgets"]
    SCREEN["Screens (85 files)"]
    WIDGET["Shared widgets"]
    ROUTE["RouteGenerator<br/>named routes + typed args"]
  end

  subgraph L2["State — lib/blocs (16 BLoCs)"]
    BLOC["AuthBloc, JobsBloc, QuotesBloc,<br/>InvoicesBloc, CustomersBloc, StaffBloc,<br/>PricingBloc, TodoBloc, NotesBloc,<br/>PhotosBloc, VideosBloc, FilesBloc,<br/>JournalBloc, NotificationsBloc,<br/>QuoteSettingsBloc, UsageBloc"]
  end

  subgraph L3["Data — lib/repositories (18) + lib/services"]
    REPO["Repositories<br/>watchAll / create / update / delete"]
    SVC["Services<br/>IapService, PushNotificationsService,<br/>PDF services, ConfigService,<br/>AppConfigService, geocoder"]
    PATHS["DatabasePaths<br/>every RTDB and Storage path"]
  end

  subgraph L4["Platform"]
    FB["Firebase SDKs"]
    HTTP["http → Cloud Functions"]
    OSAPI["OS device APIs"]
  end

  SCREEN --> BLOC
  WIDGET --> BLOC
  SCREEN --> ROUTE
  BLOC --> REPO
  SCREEN -.->|"direct call for<br/>one-shot actions"| REPO
  SCREEN --> SVC
  REPO --> PATHS
  SVC --> PATHS
  REPO --> FB
  REPO --> HTTP
  SVC --> FB
  SVC --> HTTP
  SVC --> OSAPI`,
    },
    {
      title: 'The BLoC pattern used here',
      html: `
<p>
  Every record-book BLoC follows the same three-part shape, so learning one teaches you all
  of them. The BLoC does not own the data — the RTDB stream does. The BLoC owns the
  <em>subscription</em> to that stream and turns it into states the UI can switch on.
</p>
<table>
  <tr><th>Event</th><th>What the BLoC does</th></tr>
  <tr><td><code>StartWatching</code></td><td>Cancels any prior subscription, subscribes to <code>repository.watchAll()</code>, emits a loading state</td></tr>
  <tr><td>internal <code>_Received</code></td><td>Fires on every stream tick; emits a loaded state carrying the full list</td></tr>
  <tr><td><code>StopWatching</code></td><td>Cancels the subscription — used before sign-out so a dead listener cannot fire on a revoked token</td></tr>
</table>`,
      caption: 'Record-book BLoC lifecycle',
      mermaid: `stateDiagram-v2
  [*] --> Initial
  Initial --> Loading: StartWatching
  Loading --> Loaded: stream emits a list
  Loading --> Failure: stream error / permission denied
  Loaded --> Loaded: stream emits again
  Loaded --> Initial: StopWatching (sign-out)
  Failure --> Loading: StartWatching (retry)`,
    },
    {
      title: 'The write path is not the read path',
      html: `
<p>
  This is the single most important thing to understand about the app's data flow. Writes do
  <strong>not</strong> go back through the BLoC. A screen calls the repository directly,
  the repository does an RTDB <code>set</code> / <code>update</code> / <code>remove</code>,
  and the already-open listener pushes the new value back into the BLoC, which re-emits, which
  rebuilds the screen. The UI never optimistically mutates its own list.
</p>`,
      caption: 'Write once, read back through the live stream',
      mermaid: `sequenceDiagram
  autonumber
  participant S as Screen
  participant R as Repository
  participant DB as Realtime Database
  participant B as BLoC
  participant U as Every listening widget

  S->>R: create(record)
  R->>DB: push() then set(json)
  DB-->>R: server ack (id)
  R-->>S: returns the new id
  Note over DB,B: the listener opened by StartWatching<br/>is still attached
  DB-->>B: onValue fires with the whole collection
  B->>B: parse to models, sort
  B-->>U: emit Loaded(list)
  U->>U: rebuild — the new row appears`,
    },
    {
      title: 'Where the layering is deliberately broken',
      html: `
<p>
  Three places bypass the BLoC on purpose, and each is worth knowing because they are the
  usual sources of surprise:
</p>
<ul>
  <li>
    <strong>Navigation from the repository.</strong>
    <code>AuthRepository.handleAuthentication()</code> drives the navigator itself via a
    <code>globalNavigatorKey</code>. It is the routing gate — see <em>Authentication</em> — and
    it decides between sign-in, email verification, onboarding, paywall and home.
  </li>
  <li>
    <strong>One-shot actions call repositories directly.</strong> Clock in/out, mark-as-sent,
    mark-as-paid, share-link minting and email sending are all fire-and-forget calls made from
    the screen. The refreshed record arrives back through the open stream.
  </li>
  <li>
    <strong>Singleton services with global state.</strong> <code>ConfigService</code>,
    <code>DatabaseService</code>, <code>CacheService</code>, <code>ConnectivityService</code>,
    <code>AppConfigService</code>, <code>IapService</code> and
    <code>PushNotificationsService</code> are all singletons initialised in
    <code>main()</code> before <code>runApp</code>.
  </li>
</ul>`,
    },
    {
      title: 'Directory map',
      html: `
<pre>fif_pro/
├── fixitfelixpro/                 the Flutter app
│   ├── lib/
│   │   ├── main.dart              boot sequence, env selection
│   │   ├── fix_it_felix_app.dart  composition root (repos + BLoCs + ShadApp)
│   │   ├── routes.dart            RouteGenerator — the whole named-route table
│   │   ├── globals.dart           globalNavigatorKey
│   │   ├── blocs/                 16 BLoCs, each event/state/bloc
│   │   ├── repositories/          18 repositories — the only Firebase callers
│   │   ├── services/              IAP, push, PDF, config, geocoding, reminders
│   │   ├── models/                ~70 immutable Equatable models
│   │   ├── screens/               85 screens grouped by feature
│   │   ├── widgets/               shared UI, incl. job clock and notification badge
│   │   ├── core/                  config service, cache, connectivity, database, enums
│   │   ├── generated/database_paths.dart   every RTDB + Storage path in one file
│   │   └── theme/                 FixItFelix colour scheme, ThemeProvider
│   ├── config/staging/.env        APP_TYPE + API keys
│   ├── config/production/.env
│   └── assets/                    images, fonts, terms + privacy JSON
├── functions/src/                 Cloud Functions (TypeScript)
│   ├── index.ts                   Express app factory, exported as api + apiProd
│   ├── lib/                       env binding, auth, mail, appstore, googleplay, notify
│   ├── iap/  quotes/  invoices/  notifications/  account/  subscriptions/  triggers/
├── docs/                          operational notes (IAP migration, push setup…)
└── reverse_eng/                   this documentation</pre>`,
    },
  ],
});
