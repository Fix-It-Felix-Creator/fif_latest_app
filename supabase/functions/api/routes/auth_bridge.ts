import { admin, callerIp, json, rateLimit } from '../lib/context.ts';

/**
 * POST /auth/bridge  — one-time password migration.
 *
 * Firebase scrypt hashes cannot be imported into Supabase, so migrated users
 * were created WITHOUT a password. Rather than force a reset email on the
 * entire user base at cutover, this verifies the old password against Firebase
 * once, then sets the Supabase password to the same value. The user notices
 * nothing: they type the password they have always used and are signed in.
 *
 * Flow, driven by the app:
 *   1. Supabase sign-in fails for a migrated user (no password set)
 *   2. app POSTs here with the same email + password
 *   3. verified against Firebase's identitytoolkit
 *   4. password set on the Supabase account
 *   5. app retries the Supabase sign-in, which now succeeds
 *
 * Security notes:
 *   - Public by necessity: the caller has no session yet. It is therefore a
 *     password-guessing surface, so it is rate-limited by IP AND by email.
 *   - Only migrated accounts qualify (`firebase_uid` is set). A native
 *     Supabase account can never be bridged, so this cannot be used to
 *     overwrite a password that was set here.
 *   - Once bridged, `firebase_uid` alone is not cleared — `password_migrated_at`
 *     records the crossing, and a second attempt is refused.
 *   - It returns the SAME response whether the email is unknown, not migrated,
 *     or the password is wrong. Distinguishing them would turn this into an
 *     account-enumeration oracle.
 */

const GENERIC = {
  success: false,
  message: 'Could not verify those details.',
};

export async function authBridge(req: Request): Promise<Response> {
  const ip = callerIp(req);

  // Two limits: a broad one per IP, and a tight one per email so a single
  // account cannot be brute-forced from a botnet.
  if (!await rateLimit(`bridge:ip:${ip}`, 20, 300)) {
    return json({ success: false, message: 'Too many attempts.' }, 429);
  }

  let email = '';
  let password = '';
  try {
    const body = await req.json() as { email?: string; password?: string };
    email = (body.email ?? '').trim().toLowerCase();
    password = body.password ?? '';
  } catch { /* validated below */ }

  if (!email || !password) {
    return json({ success: false, message: 'email and password required' }, 400);
  }

  if (!await rateLimit(`bridge:email:${email}`, 5, 300)) {
    return json({ success: false, message: 'Too many attempts.' }, 429);
  }

  const apiKey = Deno.env.get('FIREBASE_WEB_API_KEY');
  if (!apiKey) {
    console.error('authBridge: FIREBASE_WEB_API_KEY not set');
    return json({ success: false, message: 'Bridge not configured.' }, 503);
  }

  try {
    // Only migrated accounts qualify.
    const { data: profile } = await admin()
      .from('profiles')
      .select('id, firebase_uid, password_migrated_at')
      .eq('email', email)
      .maybeSingle();

    if (!profile?.firebase_uid) return json(GENERIC, 401);
    if (profile.password_migrated_at) {
      // Already bridged — the correct password now works against Supabase
      // directly, so a second bridge would be pointless and is refused.
      return json(GENERIC, 401);
    }

    // Verify against Firebase. This is the whole point: Firebase still holds
    // the only copy of the password that can be checked.
    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: false }),
      },
    );

    if (!res.ok) {
      // INVALID_PASSWORD / EMAIL_NOT_FOUND / USER_DISABLED all land here and
      // all return the same generic failure.
      return json(GENERIC, 401);
    }

    const fb = await res.json() as { localId?: string };

    // The Firebase account that answered must be the one this profile was
    // migrated from. Without this check, someone who controls a DIFFERENT
    // Firebase account with the same email could claim this one.
    if (fb.localId !== profile.firebase_uid) {
      console.warn('authBridge: uid mismatch for', email);
      return json(GENERIC, 401);
    }

    const { error } = await admin().auth.admin.updateUserById(profile.id, {
      password,
      email_confirm: true,
    });
    if (error) {
      console.error('authBridge: set password failed', error.message);
      return json({ success: false, message: 'Could not complete sign-in.' }, 500);
    }

    await admin()
      .from('profiles')
      .update({ password_migrated_at: new Date().toISOString() })
      .eq('id', profile.id);

    console.log('authBridge: migrated password for', profile.id);
    return json({ success: true });
  } catch (err) {
    console.error('authBridge failed', String(err));
    return json({ success: false, message: 'Could not complete sign-in.' }, 500);
  }
}
