window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'FOUNDATION',
  nav: 'App bootstrap',
  kicker: 'main() → runApp → first screen',
  title: 'App bootstrap — the launch pipeline',
  summary: `
    <code>main()</code> runs eight initialisation steps before <code>runApp</code>. Six of them
    are network calls, and every one of those is wrapped in <code>_bootStep()</code> — a helper
    with a hard timeout — because a plain <code>try/catch</code> rescues <em>errors</em> but
    not <em>hangs</em>. An un-timed Realtime Database read was once the cause of a permanent
    white screen on device, so no boot step is allowed to block the first frame.`,
  blocks: [
    {
      title: 'The full boot sequence',
      html: `
<p>
  Order matters. The cache and connectivity singletons come up first because repositories
  depend on them. Firebase must be initialised before anything Firebase-shaped. The env file
  must be loaded before <code>ConfigService</code>, which every URL getter reads. The FCM
  background handler must be registered <em>before</em> <code>runApp</code> or the background
  isolate cannot be spawned.
</p>`,
      caption: 'main() — ordered boot steps with their timeouts',
      mermaid: `graph TB
  A["WidgetsFlutterBinding.ensureInitialized()"] --> B["CacheService().initialize()<br/>Hive boxes open"]
  B --> C["ConnectivityService().initialize()"]
  C --> D["Firebase.initializeApp(DefaultFirebaseOptions)"]
  D --> E["Decide env<br/>dart-define / build parity / debug"]
  E --> F["dotenv.load(config/&lt;env&gt;/.env)"]
  F --> G["_bootStep RemoteConfig.initialize — 12s"]
  G --> H["FirebaseAppCheck.activate<br/>PlayIntegrity / DeviceCheck<br/>(debug providers in kDebugMode)"]
  H --> I["SystemChrome overlay style"]
  I --> J["_bootStep ConfigService.initialize — 12s"]
  J --> K["_bootStep DatabaseService.initialize — 8s"]
  K --> L["_bootStep AppConfigService.initialize — 10s<br/>reads RTDB config/ subtree"]
  L --> M["_bootStep IapService.initialize — 10s<br/>attach purchaseStream"]
  M --> N["FirebaseMessaging.onBackgroundMessage(handler)"]
  N --> O["runApp(FixItFelixApp)"]
  O --> P["SplashScreen"]`,
    },
    {
      title: 'Why _bootStep exists',
      html: `
<p>
  The comment in <code>main.dart</code> is unusually direct about this, and it is worth
  repeating because it is the failure mode most likely to come back:
</p>
<ul>
  <li>Every wrapped service already has safe in-memory defaults — canonical env URLs,
      <code>AppConfigModel.empty</code>, the previously cached Remote Config template.</li>
  <li>The screens that need the data refresh once connectivity returns.</li>
  <li>So continuing past a timed-out step <em>degrades</em>; blocking on it
      <em>freezes</em>.</li>
</ul>
<p>
  The specific trigger that produced a white screen: <code>AppConfigService.initialize()</code>
  does an RTDB <code>.get()</code> on <code>config/</code>. On a side-loaded build App Check
  can block that read in a way that never resolves and never errors. Ten seconds later the app
  now shrugs and boots with defaults.
</p>`,
      caption: '_bootStep — timeout, not just try/catch',
      mermaid: `graph LR
  A["_bootStep(name, step, timeout)"] --> B["await step().timeout(t)"]
  B -->|"completes"| C["continue"]
  B -->|"throws"| D["debugPrint: failed — continuing with defaults"]
  B -->|"never completes"| E["TimeoutException after t"]
  E --> F["debugPrint: timed out — continuing with defaults"]
  D --> C
  F --> C
  C --> G["next boot step<br/>runApp always reached"]`,
    },
    {
      title: 'What happens after runApp',
      html: `
<p>
  <code>FixItFelixApp</code> builds the provider stack, then shows <code>SplashScreen</code>.
  <code>AuthBloc</code> is created with <code>AuthStarted()</code> already queued, so the
  authentication routing gate begins evaluating while the splash is still on screen. The whole
  app is additionally wrapped in <code>AppStatusWrapper</code>, which can pre-empt any route
  with the maintenance or force-update screen.
</p>`,
      caption: 'From runApp to the first real screen',
      mermaid: `sequenceDiagram
  autonumber
  participant M as main()
  participant APP as FixItFelixApp
  participant TP as ThemeProvider
  participant RP as MultiRepositoryProvider
  participant BP as MultiBlocProvider
  participant AB as AuthBloc
  participant AR as AuthRepository
  participant NAV as Navigator

  M->>APP: runApp
  APP->>TP: initialize() — read stored theme mode
  APP->>APP: build AuthRepository + TradesmanRepository<br/>with remoteConfigRepository
  APP->>APP: register AuthRepository.onBeforeSignOut<br/>→ PushNotificationsService.clearToken()
  APP->>RP: provide 18 repositories
  RP->>BP: provide 16 BLoCs
  BP->>AB: create + add(AuthStarted())
  APP->>NAV: home = SplashScreen, wrapped in AppStatusWrapper
  AB->>AR: handleAuthentication()
  AR->>NAV: pushNamedAndRemoveUntil(target)
  Note over NAV: target is one of<br/>/force_update, /maintenance, /signIn,<br/>/emailVerify, /accountDisabled,<br/>/onboarding/personal, /choosePlan,<br/>/tradesmanHome`,
    },
    {
      title: 'Singletons created at boot',
      html: `
<table>
  <tr><th>Singleton</th><th>Responsibility</th><th>Failure mode if it times out</th></tr>
  <tr><td><code>CacheService</code></td><td>Hive boxes — cached user record, usage stats</td><td>Not wrapped; must succeed (local only)</td></tr>
  <tr><td><code>ConnectivityService</code></td><td>Online / offline signal for repositories</td><td>Not wrapped; local only</td></tr>
  <tr><td><code>ConfigurationRepository</code></td><td>Remote Config fetch + activate</td><td>Falls back to the last activated template</td></tr>
  <tr><td><code>ConfigService</code></td><td>APP_TYPE, backend URL, DB URL, support links, force-update and maintenance flags</td><td>Falls back to canonical per-env URLs</td></tr>
  <tr><td><code>DatabaseService</code></td><td>Binds the <code>FirebaseDatabase</code> instance for the active env</td><td>Falls back to the URL derived from APP_TYPE</td></tr>
  <tr><td><code>AppConfigService</code></td><td>RTDB <code>config/</code> — plans, limits, admin roles</td><td><code>AppConfigModel.empty</code>; screens refresh later</td></tr>
  <tr><td><code>IapService</code></td><td>Attaches the global <code>purchaseStream</code></td><td>Store marked unavailable; paywall shows an error rather than bypassing</td></tr>
</table>
<p>
  <code>PushNotificationsService</code> is the exception — only its background handler is
  registered at boot. Permission prompt, token fetch and listeners are deferred until the user
  actually reaches the home screen, so a first-run user is not hit with a system dialog before
  they have seen the app.
</p>`,
    },
  ],
});
