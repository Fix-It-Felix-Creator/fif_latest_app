import { requireUser, json } from '../_shared/auth.ts';

/**
 * Sets verification_status / rejection_reason on a profile.
 *
 * `profiles_guard_server_columns` reserves these for the service role, and
 * rightly so: a tradesman must not be able to mark themselves verified. The
 * old app wrote them straight from the client
 * (tradesman_repository.dart:827-853), which the schema now refuses.
 *
 * Two operations are allowed here:
 *   reset  — the caller clears THEIR OWN verification so they can re-apply.
 *            This is the deleteRegistrationData flow.
 *   submit — the caller marks THEIR OWN profile as pending review.
 *
 * Approving or rejecting someone else's profile is a moderation action. It is
 * deliberately NOT exposed: there is no admin role in the client today, so
 * accepting a target user id here would let any signed-in user verify anyone.
 * That admin surface now exists: the staff panel in `fif-admin` approves and
 * rejects from its own session, writing the same columns as the service role
 * after resolving the caller's role from `admin_roles`. This function stays
 * self-scoped — it is what a tradesman calls about their own profile.
 */
Deno.serve(async (req: Request) => {
  try {
    const { userId, admin } = await requireUser(req);

    let body: { action?: string } = {};
    try {
      body = await req.json();
    } catch {
      // empty body is fine
    }

    const action = body.action ?? 'reset';

    if (action !== 'reset' && action !== 'submit') {
      return json(
        { error: `unsupported action '${action}'; expected reset or submit` },
        400,
      );
    }

    // 'waiting', not 'pending'. profiles_verification_status_check permits
    // only waiting | verified | unverified | rejected — the same four values
    // as the app's own VerificationStatus enum — so 'pending' was rejected by
    // the database and a submission never reached the review queue at all.
    const patch =
      action === 'submit'
        ? { verification_status: 'waiting', rejection_reason: null }
        : { verification_status: null, rejection_reason: null };

    const { error } = await admin
      .from('profiles')
      .update(patch)
      .eq('id', userId);

    if (error) return json({ error: error.message }, 400);

    return json({ ok: true, action, ...patch });
  } catch (e) {
    if (e instanceof Response) return e;
    return json({ error: String(e) }, 500);
  }
});
