window.DOCS ??= { sections: [] };

window.DOCS.sections.push({
  group: 'IDENTITY',
  nav: 'Authentication',
  kicker: 'sign up, sign in, the routing gate',
  title: 'Authentication — every pipeline end to end',
  summary: `
    Three ways in — email + password, Google, Apple — all landing on the same Firebase Auth
    user. Above them sits <code>handleAuthentication()</code>, the single routing gate that
    decides, on every launch and after every credential change, which screen the user is
    allowed to see. Nothing else in the app performs that decision.`,
  blocks: [
    {
      title: 'Pipeline — create an account with email',
      html: `
<p>
  The example pipeline: <em>user creates account → Firebase Auth → email process</em>. The
  screen never touches Firebase; it dispatches an event, the BLoC calls the repository, the
  repository creates the credential and immediately asks Firebase to send the verification
  email. The verification screen then polls.
</p>`,
      caption: 'Sign up → Firebase Auth → verification email → poll → gate',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as SignUpScreen
  participant B as AuthBloc
  participant R as AuthRepository
  participant FA as Firebase Auth
  participant MAIL as Firebase email sender
  participant EV as EmailVerifyScreen
  participant GATE as handleAuthentication()

  U->>S: email + password, tap Create account
  S->>B: SignUpWithEmailRequested(email, password)
  B->>B: emit AuthLoadingState
  B->>R: signUpWithEmail(email, password)
  R->>FA: createUserWithEmailAndPassword
  alt FirebaseAuthException
    FA-->>R: code (email-already-in-use, weak-password…)
    R-->>B: throw CustomException(friendly message)
    B-->>S: AuthErrorState — inline error, stay on screen
  else created
    FA-->>R: UserCredential (emailVerified = false)
    R->>FA: user.sendEmailVerification()
    FA->>MAIL: dispatch verification email
    MAIL-->>U: "Verify your email" with action link
    R-->>B: UserCredential
    B-->>S: AuthSuccessState
    S->>EV: navigate /emailVerify
  end

  loop every few seconds while the screen is open
    EV->>FA: currentUser.reload()
    FA-->>EV: emailVerified?
  end
  U->>MAIL: taps the link in the mail client
  MAIL->>FA: confirms the address
  EV->>EV: poll sees emailVerified = true, cancels its timers
  EV->>GATE: handleAuthentication()
  GATE-->>U: next screen (onboarding, paywall or home)`,
    },
    {
      title: 'Pipeline — sign in with email',
      html: `
<p>
  Sign-in has one extra guard that is easy to miss: <code>_validateAccountType()</code>. This
  app is for tradespeople only. If the record carries
  <code>accountType == customer</code> — an account created in the consumer-side product —
  the sign-in is rejected and the session torn down, rather than letting them into a UI built
  for someone else.
</p>`,
      caption: 'Sign in with email + password',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as SignInScreen
  participant B as AuthBloc
  participant R as AuthRepository
  participant FA as Firebase Auth
  participant DB as RTDB users/{uid}
  participant GATE as handleAuthentication()

  U->>S: email + password
  S->>B: SignInWithEmailRequested
  B->>R: signInWithEmail(email, password)
  R->>FA: signInWithEmailAndPassword
  FA-->>R: UserCredential
  R->>R: _validateAccountType()
  R->>DB: read accountType
  alt accountType == customer
    DB-->>R: "customer"
    R->>FA: signOut()
    R-->>B: CustomException — account not supported here
    B-->>S: AuthErrorState
  else allowed
    DB-->>R: tradesman / business
    R-->>B: UserCredential
    B->>GATE: handleAuthentication()
    GATE-->>U: routed screen
  end`,
    },
    {
      title: 'Pipeline — sign in with Google',
      html: `
<p>
  Google returns a display name for free, so the repository harvests it. Splitting on
  whitespace gives first / last, and <code>_persistOAuthNameIfMissing()</code> writes them into
  <code>users/{uid}</code> — but <strong>only if a name is not already stored</strong>. That
  one guard is what stops a returning user's edited name from being clobbered on every
  sign-in.
</p>`,
      caption: 'Google sign-in with name harvesting',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as SignInScreen
  participant R as AuthRepository
  participant G as GoogleSignIn (native sheet)
  participant FA as Firebase Auth
  participant DB as RTDB users/{uid}

  U->>S: tap Continue with Google
  S->>R: signInWithGoogle()
  R->>G: signIn(scopes: [email])
  alt user dismisses the sheet
    G-->>R: null
    R-->>S: return null — silent, no error toast
  else authorised
    G-->>R: GoogleSignInAccount
    R->>G: authentication (accessToken + idToken)
    R->>FA: signInWithCredential(GoogleAuthProvider.credential)
    FA-->>R: UserCredential
    R->>R: split displayName into first / last
    R->>DB: _persistOAuthNameIfMissing
    Note over DB: writes firstName / lastName / id / email<br/>ONLY when no name is stored yet
    R->>R: _validateAccountType()
    R-->>S: UserCredential → handleAuthentication()
  end`,
    },
    {
      title: 'Pipeline — Sign in with Apple',
      html: `
<p>
  Apple is mandatory on iOS (App Store Guideline 4.8) and has a trap that once caused a
  rejection under Guideline 4: <strong>Apple only returns the user's name on the very first
  authorisation</strong>. If you do not capture it then, you never get it again, and the app
  ends up asking for a name Apple already provided — exactly what Guideline 4 forbids.
</p>
<p>
  So the flow generates a raw nonce, hashes it with SHA-256 for the Apple request, exchanges
  the identity token for a Firebase credential, and persists <code>givenName</code> /
  <code>familyName</code> through the same
  <code>_persistOAuthNameIfMissing()</code> guard. <code>PersonalDetailsStep</code> also
  pre-fills from the Firebase <code>displayName</code> as a second safety net.
</p>`,
      caption: 'Apple sign-in — nonce, first-authorisation name capture',
      mermaid: `sequenceDiagram
  autonumber
  participant U as User
  participant S as SignInScreen
  participant R as AuthRepository
  participant AP as SignInWithApple (native)
  participant FA as Firebase Auth
  participant DB as RTDB users/{uid}

  U->>S: tap Sign in with Apple
  S->>R: signInWithApple()
  R->>R: rawNonce = random, nonce = sha256(rawNonce)
  R->>AP: getAppleIDCredential(scopes: email + fullName, nonce)
  AP-->>R: identityToken, authorizationCode,<br/>givenName + familyName (FIRST TIME ONLY)
  alt identityToken missing
    R-->>S: CustomException — could not get Apple identity token
  else
    R->>FA: signInWithCredential(OAuthProvider apple.com,<br/>idToken, rawNonce)
    FA-->>R: UserCredential
    R->>DB: _persistOAuthNameIfMissing(givenName, familyName)
    Note over R,DB: bootstraps id + email too —<br/>never overwrites an existing name
    R->>R: _validateAccountType()
    R-->>S: handleAuthentication()
  end`,
    },
    {
      title: 'Pipeline — forgot password',
      html: `
<p>
  The simplest pipeline in the app, and intentionally so — Firebase owns the whole reset
  ceremony. The app's only job is to hand over an address and report the outcome. Note the
  BLoC uses dedicated states (<code>PasswordResetLoading/Success/Error</code>) rather than the
  generic ones, so the screen can show a confirmation without triggering navigation.
</p>`,
      caption: 'Password reset',
      mermaid: `graph LR
  A["ForgotPasswordScreen<br/>email entered"] --> B["AuthBloc<br/>PasswordResetRequested"]
  B --> C["emit PasswordResetLoadingState"]
  C --> D["AuthRepository<br/>sendPasswordResetEmail(email)"]
  D --> E["Firebase Auth<br/>sendPasswordResetEmail"]
  E --> F["Firebase sends reset mail<br/>with an action link"]
  F --> G["emit PasswordResetSuccessState<br/>screen shows check-your-inbox"]
  E -->|"FirebaseAuthException"| H["mapped to a friendly message"]
  H --> I["emit PasswordResetErrorState"]
  F -.->|"user opens link,<br/>sets a new password on<br/>Firebase-hosted page"| J["returns to /signIn"]`,
    },
    {
      title: 'The routing gate — handleAuthentication()',
      html: `
<p>
  This is the most consequential function in the codebase. It runs after every sign-in, after
  email verification, and on every cold start via <code>AuthStarted</code>. It drives the
  navigator directly through <code>globalNavigatorKey</code>, always with
  <code>pushNamedAndRemoveUntil</code> so there is never a back stack to escape through.
</p>
<p>
  It begins by waiting for the navigator to mount — but only for about five seconds
  (50 × 100 ms), then gives up. That bound replaced an unbounded recursion that could build an
  ever-growing async chain if the app was torn down or backgrounded mid-sign-in.
</p>`,
      caption: 'handleAuthentication — the complete decision tree',
      mermaid: `graph TB
  START["handleAuthentication()"] --> NAV{"navigator mounted?<br/>bounded wait 50 x 100ms"}
  NAV -->|"never"| ABORT["log and abort"]
  NAV -->|"ready"| FU{"ConfigService<br/>requiresForceUpdate?"}
  FU -->|"yes"| RFU["/force_update"]
  FU -->|"no"| MT{"isUnderMaintenance?"}
  MT -->|"yes"| RMT["/maintenance"]
  MT -->|"no"| RELOAD["user.reload()"]

  RELOAD --> RERR{"reload threw?"}
  RERR -->|"invalid session code<br/>token-expired / user-disabled /<br/>user-not-found / invalid-token"| SOUT["signOut → /signIn"]
  RERR -->|"network error"| CONT["continue with cached state"]
  RERR -->|"no"| CONT

  CONT --> U{"user == null?"}
  U -->|"yes"| RSI["/signIn"]
  U -->|"no"| EV{"emailVerified?"}
  EV -->|"no"| REV["/emailVerify"]
  EV -->|"yes"| FETCH["getUserDetails(forceRefresh: true)<br/>+ read users/{uid} accountStatus"]

  FETCH --> AS{"accountStatus"}
  AS -->|"deletion_pending"| RAD["/accountDisabled<br/>with recovery window dates"]
  AS -->|"disabled"| SOUT2["signOut → /signIn"]
  AS -->|"ok"| AT{"accountType == customer?"}
  AT -->|"yes"| SOUT3["signOut → /signIn"]
  AT -->|"no"| ONB{"_needsOnboarding?"}

  ONB -->|"yes"| RONB["/onboarding/personal"]
  ONB -->|"no"| SUB{"_needsSubscription?"}
  SUB -->|"no"| HOME["/tradesmanHome"]
  SUB -->|"yes"| RESTORE["_tryRestoreEntitlement()<br/>silent IAP restore + 8 x 750ms re-poll"]
  RESTORE --> SUB2{"_needsSubscription<br/>after restore?"}
  SUB2 -->|"no"| HOME
  SUB2 -->|"yes"| PAY["/choosePlan"]`,
    },
    {
      title: 'The two gate predicates',
      html: `
<p>
  Both are small, both are load-bearing, and both carry comments explaining a bug they were
  written to fix.
</p>
<h3>_needsOnboarding(details)</h3>
<table>
  <tr><th>Condition</th><th>Result</th></tr>
  <tr><td>no user record at all</td><td>needs onboarding</td></tr>
  <tr><td><code>firstName</code> blank</td><td>needs onboarding</td></tr>
  <tr><td><code>lastName</code> blank</td><td><strong>fine</strong> — Apple and Google may return no surname; requiring it would bounce those users forever</td></tr>
  <tr><td><code>phoneNumber</code> blank</td><td>needs onboarding</td></tr>
  <tr><td><code>address.postcode</code> blank</td><td>needs onboarding — postcode is the canonical "address present" probe</td></tr>
  <tr><td>date of birth</td><td>deliberately <strong>not</strong> checked, and no longer collected</td></tr>
</table>
<h3>_needsSubscription(details)</h3>
<table>
  <tr><th>Condition</th><th>Result</th></tr>
  <tr><td>no <code>subscription.member</code> record</td><td>gate closed → paywall</td></tr>
  <tr><td>status is <code>active</code> or <code>trial</code></td><td>grants access — <code>trial</code> is accepted because store intro-offers and legacy records carry it</td></tr>
  <tr><td>any other status (cancelled, expired, past_due)</td><td>gate closed</td></tr>
  <tr><td><code>endDate</code> in the past</td><td>gate closed — covers day-31 trial expiry <em>and</em> a soft-cancelled sub whose period rolled over</td></tr>
  <tr><td>soft cancel: <code>autoRenew = false</code>, status still active, <code>endDate</code> future</td><td>access <strong>kept</strong> — they paid for the period</td></tr>
</table>`,
    },
    {
      title: 'Sign out — and why it has a pre-hook',
      html: `
<p>
  Signing out naively causes a burst of permission-denied errors: every open RTDB listener is
  still attached when the token is revoked. So <code>AuthRepository</code> exposes a static
  <code>onBeforeSignOut</code> hook, registered in <code>fix_it_felix_app.dart</code>, which
  clears the FCM token first — otherwise the device would keep receiving pushes for an account
  no longer signed in on it.
</p>`,
      caption: 'Sign out ordering',
      mermaid: `sequenceDiagram
  autonumber
  participant S as Settings / Profile
  participant B as AuthBloc
  participant R as AuthRepository
  participant P as PushNotificationsService
  participant DB as RTDB users/{uid}/fcmTokens
  participant FA as Firebase Auth
  participant C as CacheService
  participant NAV as Navigator

  S->>B: AuthLogoutRequested
  B->>R: signOut()
  R->>P: onBeforeSignOut() hook
  P->>DB: remove this device token
  R->>C: clearUserCache()
  R->>FA: signOut()
  FA-->>R: session gone
  R->>NAV: pushNamedAndRemoveUntil(/signIn)`,
    },
    {
      title: 'Auth surface reference',
      html: `
<table>
  <tr><th>AuthBloc event</th><th>Repository call</th><th>Terminal state</th></tr>
  <tr><td><code>AuthStarted</code></td><td><code>handleAuthentication()</code></td><td>navigation, not a state</td></tr>
  <tr><td><code>SignInWithEmailRequested</code></td><td><code>signInWithEmail</code></td><td><code>AuthSuccessState</code> / <code>AuthErrorState</code></td></tr>
  <tr><td><code>SignInWithGoogleRequested</code></td><td><code>signInWithGoogle</code></td><td>same, or silent null on cancel</td></tr>
  <tr><td><code>SignInWithAppleRequested</code></td><td><code>signInWithApple</code></td><td>same</td></tr>
  <tr><td><code>SignUpWithEmailRequested</code></td><td><code>signUpWithEmail</code></td><td><code>AuthSuccessState</code> → <code>/emailVerify</code></td></tr>
  <tr><td><code>SendVerificationEmailRequested</code></td><td><code>sendVerificationEmail</code></td><td><code>VerificationEmailSentState</code></td></tr>
  <tr><td><code>PasswordResetRequested</code></td><td><code>sendPasswordResetEmail</code></td><td><code>PasswordResetSuccessState</code></td></tr>
  <tr><td><code>AuthUserDetailsChanged</code></td><td><code>streamUserDetails()</code> tick</td><td>state carries the new <code>UserDetailsModel</code></td></tr>
  <tr><td><code>AuthLogoutRequested</code></td><td><code>signOut</code></td><td>navigate <code>/signIn</code></td></tr>
  <tr><td><code>AuthForceLogoutRequested</code></td><td>via <code>DeviceInfoRepository.onForceLogout</code></td><td><code>ForceLogoutState</code></td></tr>
  <tr><td><code>DeleteAccountRequested</code></td><td><code>deleteAccountCompletely</code></td><td><code>DeleteAccountSuccessState</code></td></tr>
</table>`,
    },
  ],
});
