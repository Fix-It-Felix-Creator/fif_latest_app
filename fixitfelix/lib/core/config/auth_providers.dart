/// Which third-party sign-in providers this build can actually offer.
///
/// A provider is only shown once it can complete a real sign-in. Neither of
/// these fails gracefully when half-configured — Google used to kill the app
/// outright — so a flag here is the difference between a working button and a
/// broken one, not a feature toggle.
///
/// Google is ON, using the pro app's iOS OAuth client
/// (`1085413148846-2gg9…apps.googleusercontent.com`, declared as
/// `GIDClientID` in ios/Runner/Info.plist along with its reversed form as a
/// URL scheme).
///
/// Sharing one client across two bundle ids is deliberate and works because
/// of what each side actually checks:
///
///   * Supabase validates the ID token's `aud` claim against the client ids
///     registered on its Google provider. `aud` is the client id, not the
///     bundle id, and this one is already registered there because the pro
///     app uses it — so no dashboard change was needed.
///   * The shared `com.googleusercontent.apps.…` URL scheme does NOT collide
///     when both apps are installed. AppAuth drives the flow through
///     `ASWebAuthenticationSession` (Pods/AppAuth/.../OIDExternalUserAgentIOS.m,
///     initWithURL:callbackURLScheme:), which intercepts the redirect
///     in-process rather than dispatching it through the system, so neither
///     app can swallow the other's callback. The Info.plist entry exists only
///     to satisfy GoogleSignIn's own `unsupportedSchemes` sanity check.
///
/// The honest caveat: the client is registered against
/// `com.techkushx.fixitfelixpro`. iOS OAuth clients hold no secret and are
/// not bundle-id-enforced at the token endpoint, which is why this works —
/// but issuing a client for `com.techkushx.fixitfelix` is free and would
/// make the registration match reality. Swap the two Info.plist values and
/// add the new id to Supabase's Google provider if you'd rather do that.
const bool kGoogleSignInEnabled = true;

/// Apple stays OFF, and unlike Google it cannot be fixed by borrowing from
/// the pro app.
///
/// Apple mints its ID token with `aud` set to the *bundle id* that requested
/// it — `com.techkushx.fixitfelix` here. Supabase checks that against the
/// client ids on its Apple provider, which currently lists only the pro
/// app's bundle. Native sign-in would succeed and Supabase would then reject
/// the token, so the button would still be dead, just later in the flow.
///
/// ios/Runner/Runner.entitlements is written but deliberately NOT wired into
/// the Xcode target: setting CODE_SIGN_ENTITLEMENTS makes signing demand the
/// Sign In with Apple capability on the App ID, and if it is not enabled
/// there the build fails outright — a bad trade for a provider that is off.
///
/// To turn Apple on:
///   1. Enable Sign In with Apple on the `com.techkushx.fixitfelix` App ID.
///   2. Set CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements on the Runner
///      target (Xcode does this itself when you add the capability).
///   3. Add `com.techkushx.fixitfelix` to the Supabase project's Apple
///      provider client ids.
///   4. Flip this to true.
///
/// Worth knowing before submission: App Store Guideline 4.8 requires an
/// equivalent login option — offering Google without Apple is a rejection
/// risk, so this wants doing before the app ships, not after.
const bool kAppleSignInEnabled = false;

/// True when at least one provider button is shown. Used to hide the "or
/// continue with" divider, which looks broken with nothing under it.
const bool kAnySocialSignInEnabled =
    kGoogleSignInEnabled || kAppleSignInEnabled;
