window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'FOUNDATION',
  nav: 'Environments',
  kicker: 'staging vs production split',
  title: 'Environments and configuration',
  summary: `
    One Firebase project, two completely separate ledgers. Staging and production have their
    own Realtime Database instance, their own Cloud Function, their own Storage prefix and
    their own App Store environment (Sandbox vs Production). Which one a build talks to is
    decided by <strong>build-number parity</strong> — an odd build number is staging, an even
    one is production — so the exact same Xcode archive flow can ship either variant.`,
  blocks: [
    {
      title: 'The two ledgers',
      html: `
<table>
  <tr><th></th><th>Staging</th><th>Production</th></tr>
  <tr><th>Env file</th><td><code>config/staging/.env</code> (APP_TYPE=DEVELOPMENT)</td><td><code>config/production/.env</code> (APP_TYPE=PRODUCTION)</td></tr>
  <tr><th>RTDB</th><td><code>fifcloud-default-rtdb</code></td><td><code>fifcloud-production</code></td></tr>
  <tr><th>Cloud Function</th><td><code>api</code></td><td><code>apiProd</code></td></tr>
  <tr><th>Base URL</th><td><code>…cloudfunctions.net/api</code></td><td><code>…cloudfunctions.net/apiProd</code></td></tr>
  <tr><th>Storage prefix</th><td><code>users/</code></td><td><code>pod_users/</code></td></tr>
  <tr><th>App Store env</th><td>Sandbox</td><td>Production</td></tr>
  <tr><th>Remote Config keys</th><td><code>dev_variable</code>, <code>dev_maintenance</code>, <code>dev_force_app_update</code></td><td><code>prod_variable</code>, <code>prod_maintenance</code>, <code>force_app_update</code></td></tr>
</table>`,
    },
    {
      title: 'How a build picks its environment',
      html: `
<p>
  Three rules, highest priority first. The ambiguous case falls back to <em>staging</em> on
  purpose: a misconfigured production build hitting the staging backend fails safely, while
  the reverse would write test data into the real ledger.
</p>`,
      caption: 'Environment selection at boot (main.dart)',
      mermaid: `graph TB
  START["main() starts"] --> Q1{"--dart-define=ENV<br/>provided?"}
  Q1 -->|"yes"| USE["buildEnv = that value"]
  Q1 -->|"no"| Q2{"kReleaseMode?"}
  Q2 -->|"no — debug / profile"| STG["buildEnv = staging"]
  Q2 -->|"yes"| READ["PackageInfo.fromPlatform()<br/>parse leading integer of buildNumber"]
  READ --> Q3{"parsed?"}
  Q3 -->|"no"| STG
  Q3 -->|"even"| PROD["buildEnv = production"]
  Q3 -->|"odd"| STG
  USE --> LOAD
  STG --> LOAD
  PROD --> LOAD["dotenv.load(config/&lt;env&gt;/.env)"]
  LOAD --> CFG["ConfigService reads APP_TYPE<br/>APP_TYPE is AUTHORITATIVE"]`,
    },
    {
      title: 'The self-healing config rule',
      html: `
<p>
  There is a hard-won safety rule inside <code>ConfigService</code>. The backend URL and the
  database URL come from Remote Config (<code>dev_variable</code> /
  <code>prod_variable</code>), but a cached or stale Remote Config template once caused a
  production build to POST into the staging backend — subscriptions were written to the wrong
  ledger and the paywall re-appeared on every launch.
</p>
<p>
  The fix: the compile-time <code>APP_TYPE</code> is treated as the authority. If Remote
  Config is empty, or disagrees with <code>APP_TYPE</code>, the getters <em>self-heal</em> to
  the canonical per-environment URL and log a loud mismatch tripwire. A production build can
  no longer be talked into using the staging backend by a bad flag value.
</p>`,
      caption: 'ConfigService.stripeBackendUrl / databaseUrl resolution',
      mermaid: `graph LR
  A["getter called"] --> B["read APP_TYPE from .env"]
  B --> C{"Remote Config<br/>value present?"}
  C -->|"no"| D["return canonical URL<br/>for APP_TYPE"]
  C -->|"yes"| E{"does it match<br/>the APP_TYPE env?"}
  E -->|"yes"| F["return the Remote Config value"]
  E -->|"no"| G["log env-mismatch tripwire"]
  G --> D`,
    },
    {
      title: 'The same trick on the server',
      html: `
<p>
  The Cloud Functions side solves the identical problem differently. There is only
  <strong>one</strong> code bundle. <code>buildApp(env)</code> is called twice, and its very
  first middleware wraps the whole request in <code>runWithEnv(env, …)</code>, which stores
  the environment in an <code>AsyncLocalStorage</code>. Every later call to <code>db()</code>
  or <code>currentAppStoreEnv()</code> reads it back out — so handlers and helpers never have
  to thread a request object around, and a missing wrapper throws loudly instead of silently
  defaulting to the wrong database.
</p>`,
      caption: 'One bundle, two functions, env bound per request',
      mermaid: `sequenceDiagram
  autonumber
  participant C as Client
  participant F as onRequest export
  participant M as runWithEnv middleware
  participant H as Route handler
  participant DBF as db() helper
  participant R as RTDB instance

  C->>F: POST /quotes/share-link
  Note over F: api → "staging"<br/>apiProd → "production"
  F->>M: dispatch
  M->>M: AsyncLocalStorage.run({env})
  M->>H: next()
  H->>DBF: db()
  DBF->>DBF: currentEnv() from ALS
  DBF-->>H: getDatabaseWithUrl(RTDB_URL[env])
  H->>R: read / write
  R-->>H: data
  H-->>C: 200 JSON`,
    },
    {
      title: 'The exception: public share links',
      html: `
<p>
  Share links break the rule, and the code says so explicitly. Both environments mint tokens,
  but a <em>single</em> Hosting site (<code>fifcloud.web.app</code>) serves
  <code>/q/:token</code> and <code>/i/:token</code>. The viewer therefore cannot trust the
  environment bound to its own request — the token might live in the other instance.
</p>
<p>
  <code>resolveEnvForPath()</code> probes production first, then staging, and
  <code>rebindEnv()</code> re-binds the AsyncLocalStorage for the rest of the request so the
  quote read, the status write and the owner notification all land in the right ledger.
</p>`,
      caption: 'Public viewer resolves the token home instance first',
      mermaid: `graph TB
  A["GET /q/:token"] --> B["resolveEnvForPath(quoteShares/token)"]
  B --> C{"exists in<br/>PRODUCTION?"}
  C -->|"yes"| D["rebindEnv(production)"]
  C -->|"no"| E{"exists in<br/>STAGING?"}
  E -->|"yes"| F["rebindEnv(staging)"]
  E -->|"no"| G["404 — quote not found"]
  D --> H["render viewer from that instance"]
  F --> H`,
    },
    {
      title: 'Remote Config surface',
      html: `
<table>
  <tr><th>Key</th><th>Shape</th><th>Drives</th></tr>
  <tr><td><code>dev_variable</code> / <code>prod_variable</code></td><td>JSON</td><td>databaseUrl, backend URL, debug flag, privacy / terms / help URLs, support email + phone + WhatsApp + hours, YouTube and Facebook links</td></tr>
  <tr><td><code>dev_maintenance</code> / <code>prod_maintenance</code></td><td>JSON</td><td><code>isEnabled</code>, title, message, <code>allowBypass</code> — routes to <code>/maintenance</code></td></tr>
  <tr><td><code>dev_force_app_update</code> / <code>force_app_update</code></td><td>JSON</td><td>Minimum version per platform — routes to <code>/force_update</code></td></tr>
</table>
<p>
  Separately, <code>AppConfigService</code> reads a <code>config/</code> subtree straight from
  RTDB for subscription plan definitions, feature limits, image limits and the admin role
  list. That read happens pre-authentication, so a permission-denied warning at boot is
  expected and already guarded by a fallback.
</p>`,
    },
  ],
});
