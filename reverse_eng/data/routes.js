window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'PLATFORM',
  nav: 'Screens & routes',
  kicker: 'the complete sitemap',
  title: 'Screens and routes — the sitemap',
  summary: `
    85 screen files behind about 50 named routes, all resolved by one <code>switch</code> in
    <code>RouteGenerator.generateRoute</code>. There is no router package: routes are strings,
    arguments are typed classes passed through <code>RouteSettings.arguments</code>, and an
    unrecognised name falls through to an error route.`,
  blocks: [
    {
      title: 'The navigation shell',
      html: `
<p>
  Once past the gate the whole app lives inside <code>TradesmanHomeScreen</code>: an
  <code>IndexedStack</code> of five tabs, so switching tabs preserves each one's scroll
  position and state. Everything else is <em>pushed on top</em> of that shell, not swapped
  into it.
</p>`,
      caption: 'Five tabs, everything else pushed over them',
      mermaid: `graph TB
  ROOT["/tradesmanHome<br/>TradesmanHomeScreen<br/>IndexedStack + bottom nav"] --> T1["Home<br/>greeting, live job timers,<br/>next up, quick actions"]
  ROOT --> T2["Jobs"]
  ROOT --> T3["Journal"]
  ROOT --> T4["Tools"]
  ROOT --> T5["Profile"]

  T1 --> QA["Quick actions →<br/>/quotes/new, /invoices/new,<br/>/jobs/new, /customers"]
  T1 --> CLK["tap a running job →<br/>/jobs/new with the existing job"]
  T4 --> TOOLS["/tools/notes<br/>/tools/photos<br/>/tools/videos<br/>/tools/files"]
  T5 --> SET["/settings"]
  ROOT --> NOTIF["app bar → /notifications"]

  WRAP["AppStatusWrapper wraps EVERYTHING —<br/>can pre-empt any route with<br/>/maintenance or /force_update"] -.-> ROOT`,
    },
    {
      title: 'Route table',
      html: `
<table>
  <tr><th>Route</th><th>Screen</th><th>Argument type</th></tr>
  <tr><td><code>/splash</code></td><td>SplashScreen</td><td>—</td></tr>
  <tr><td><code>/signIn</code></td><td>SignInScreen</td><td>—</td></tr>
  <tr><td><code>/signUp</code></td><td>SignUpScreen</td><td>—</td></tr>
  <tr><td><code>/forgotPassword</code></td><td>ForgotPasswordScreen</td><td>—</td></tr>
  <tr><td><code>/emailVerify</code></td><td>EmailVerifyScreen</td><td>—</td></tr>
  <tr><td><code>/createAccountCategory</code></td><td>SelectRoleScreen <em>(legacy)</em></td><td>—</td></tr>
  <tr><td><code>/onboarding/personal</code></td><td>PersonalDetailsStep</td><td>—</td></tr>
  <tr><td><code>/onboarding/company</code></td><td>CompanyDetailsStep</td><td>—</td></tr>
  <tr><td><code>/onboarding/address</code></td><td>AddressStep</td><td>—</td></tr>
  <tr><td><code>/tradesmanVerifyWaiting</code></td><td>TradesmanVerifyWaitingScreen <em>(legacy)</em></td><td>—</td></tr>
  <tr><td><code>/tradesmanRejected</code></td><td>TradesmanRejectedScreen <em>(legacy)</em></td><td><code>String?</code> reason</td></tr>
  <tr><td><code>/teamOnboarding</code></td><td>TeamOnboardingScreen <em>(dormant)</em></td><td>—</td></tr>
  <tr><td><code>/choosePlan</code>, <code>/businessSubscription</code>, <code>/tradesmanSubscription</code></td><td>ChoosePlanScreen — all three aliases resolve here</td><td><code>ChoosePlanArgs(fromSettings)</code></td></tr>
  <tr><td><code>/tradesmanHome</code></td><td>TradesmanHomeScreen</td><td>—</td></tr>
  <tr><td><code>/ownerHome</code></td><td>OwnerHomeScreen</td><td>—</td></tr>
  <tr><td><code>/notifications</code></td><td>NotificationsScreen</td><td>—</td></tr>
  <tr><td><code>/journalEdit</code></td><td>JournalEventEditScreen</td><td><code>JournalEditArgs</code></td></tr>
  <tr><td><code>/customers</code></td><td>CustomersScreen</td><td>—</td></tr>
  <tr><td><code>/customerEdit</code></td><td>CustomerEditScreen</td><td><code>CustomerEditArgs</code></td></tr>
  <tr><td><code>/staff</code></td><td>StaffScreen</td><td>—</td></tr>
  <tr><td><code>/staffEdit</code></td><td>StaffEditScreen</td><td><code>StaffEditArgs</code></td></tr>
  <tr><td><code>/pricing</code></td><td>PricingScreen</td><td>—</td></tr>
  <tr><td><code>/quotes</code></td><td>QuotesScreen</td><td>—</td></tr>
  <tr><td><code>/quotes/new</code></td><td>NewQuoteScreen</td><td><code>NewQuoteArgs</code> or a bare <code>Quote</code></td></tr>
  <tr><td><code>/quotes/settings</code></td><td>QuoteSettingsScreen</td><td>—</td></tr>
  <tr><td><code>/quotes/send</code></td><td>QuoteSendScreen <em>(fullscreen dialog)</em></td><td><code>QuoteSendArgs</code></td></tr>
  <tr><td><code>/invoices</code></td><td>InvoicesScreen</td><td>—</td></tr>
  <tr><td><code>/invoices/new</code></td><td>NewInvoiceScreen</td><td><code>NewInvoiceArgs</code> or a bare <code>Invoice</code></td></tr>
  <tr><td><code>/invoices/send</code></td><td>InvoiceSendScreen <em>(fullscreen dialog)</em></td><td><code>InvoiceSendArgs</code></td></tr>
  <tr><td><code>/jobs</code></td><td>JobsScreen</td><td>—</td></tr>
  <tr><td><code>/jobs/new</code></td><td>NewJobScreen</td><td><code>NewJobArgs</code> or a bare <code>Job</code></td></tr>
  <tr><td><code>/todos</code></td><td>TodoListScreen</td><td>—</td></tr>
  <tr><td><code>/tools/notes</code>, <code>/tools/notes/edit</code></td><td>NotesListScreen, NoteEditScreen</td><td><code>NoteEditArgs</code></td></tr>
  <tr><td><code>/tools/photos</code>, <code>/upload</code>, <code>/view</code></td><td>PhotosGridScreen, PhotoUploadScreen, PhotoViewerScreen</td><td><code>PhotoViewerArgs</code></td></tr>
  <tr><td><code>/tools/videos</code>, <code>/upload</code>, <code>/view</code></td><td>VideosListScreen, VideoUploadScreen, VideoPlayerScreen</td><td><code>VideoPlayerArgs</code></td></tr>
  <tr><td><code>/tools/files</code>, <code>/upload</code></td><td>FilesListScreen, FileUploadScreen</td><td>—</td></tr>
  <tr><td><code>/settings</code></td><td>SettingsScreen</td><td>—</td></tr>
  <tr><td><code>/settings/personalInfo</code></td><td>PersonalInformationScreen</td><td>—</td></tr>
  <tr><td><code>/settings/company</code></td><td>CompanyDetailsScreen</td><td>—</td></tr>
  <tr><td><code>/settings/bank</code></td><td>BankDetailsScreen</td><td>—</td></tr>
  <tr><td><code>/settings/address</code></td><td>AddressEditScreen</td><td>—</td></tr>
  <tr><td><code>/settings/webPage</code></td><td>WebViewScreen</td><td><code>Map</code> with title + url</td></tr>
  <tr><td><code>/deleteAccount</code></td><td>DeleteAccountScreen</td><td>—</td></tr>
  <tr><td><code>/accountDisabled</code></td><td>AccountDisabledScreen</td><td><code>Map</code> with the recovery-window timestamps</td></tr>
  <tr><td><code>/maintenance</code></td><td>MaintenanceScreen</td><td>—</td></tr>
  <tr><td><code>/force_update</code></td><td>ForceUpdateScreen</td><td>—</td></tr>
  <tr><td><em>default</em></td><td>Error route</td><td>—</td></tr>
</table>`,
    },
    {
      title: 'Settings — the deepest sub-tree',
      html: `
<p>
  Settings is reachable from the gear icon on the Profile tab (and on the owner home app bar).
  It is the one place where nearly every subsystem in the app surfaces at once.
</p>`,
      caption: 'Settings map',
      mermaid: `graph TB
  S["/settings"] --> P["Current plan card<br/>→ /choosePlan with fromSettings: true<br/>cancel / manage via the store"]
  S --> A["Account"]
  A --> A1["/settings/personalInfo"]
  A --> A2["/settings/company"]
  A --> A3["/settings/bank<br/>bank name, account no, sort code"]
  A --> A4["/settings/address<br/>map preview + UK postcode search"]
  A --> A5["Dark mode toggle → ThemeScope"]
  S --> N["Notifications<br/>push / email / sms toggles<br/>→ UpdateUserDetailsRequested"]
  S --> SUP["Support"]
  SUP --> SU1["Help centre / T&C / Privacy<br/>→ /settings/webPage in-app WebView"]
  SUP --> SU2["Contact support sheet<br/>→ tel: and mailto:"]
  SUP --> SU3["Rate us → in_app_review"]
  S --> D["Sign out"]
  S --> E["/deleteAccount"]`,
    },
    {
      title: 'Two navigation conventions to know',
      html: `
<ul>
  <li>
    <strong>Typed args with fallbacks.</strong> Editor routes accept either a typed args class
    (<code>NewQuoteArgs</code>, carrying an existing record <em>and</em> a next sequence
    number) or a bare model, and fall back to a blank create screen when the arguments are
    absent or the wrong type. A route can therefore never crash on a bad argument — it just
    degrades to the list or an empty form.
  </li>
  <li>
    <strong>Gate routes clear the stack.</strong> Every navigation the auth gate performs uses
    <code>pushNamedAndRemoveUntil(…, (route) => false)</code>. There is never a back button out
    of the paywall, out of maintenance, or back into a signed-out session.
  </li>
</ul>`,
      caption: 'Screen count by area',
      mermaid: `graph LR
  A["85 screen files"] --> B["authentication — 20<br/>incl. the legacy registration journey"]
  A --> C["tools — 14"]
  A --> D["quotes — 8"]
  A --> E["settings — 7"]
  A --> F["tradesman shell + tabs — 7"]
  A --> G["jobs — 4"]
  A --> H["invoices — 3"]
  A --> I["todos — 3"]
  A --> J["customers — 3"]
  A --> K["staff, pricing, notifications,<br/>account, app_status, subscription,<br/>splash, shared — the rest"]`,
    },
  ],
});
