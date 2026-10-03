import { admin, json } from '../lib/context.ts';
import type { Caller } from '../lib/context.ts';

/**
 * Account lifecycle and trial activation.
 *
 * All owner-scoped: the service-role client bypasses RLS, so every statement
 * filters on the caller's id explicitly.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

interface DeletionConfig {
  recoveryWaitDays: number;
  personalDataRetentionDays: number;
}

const DEFAULT_CONFIG: DeletionConfig = {
  recoveryWaitDays: 14,
  personalDataRetentionDays: 90,
};

let _cfg: { value: DeletionConfig; at: number } | null = null;

/** Was RTDB `config/accountDeletion`; now the `accountDeletion` app_config key. */
async function deletionConfig(): Promise<DeletionConfig> {
  const now = Date.now();
  if (_cfg && now - _cfg.at < 60_000) return _cfg.value;

  const { data } = await admin()
    .from('app_config')
    .select('value')
    .eq('key', 'accountDeletion')
    .maybeSingle();

  const v = (data?.value ?? {}) as Partial<DeletionConfig>;
  const value: DeletionConfig = {
    recoveryWaitDays: typeof v.recoveryWaitDays === 'number'
      ? v.recoveryWaitDays
      : DEFAULT_CONFIG.recoveryWaitDays,
    personalDataRetentionDays: typeof v.personalDataRetentionDays === 'number'
      ? v.personalDataRetentionDays
      : DEFAULT_CONFIG.personalDataRetentionDays,
  };
  _cfg = { value, at: now };
  return value;
}

/**
 * POST /account/request-deletion
 *
 * Marks the account `deletion_pending` and signs the user out everywhere.
 * Auth is deliberately NOT disabled: the user must be able to sign back in
 * during the recovery window to recover or download their data.
 *
 * The record is not physically deleted — a separate purge job does that after
 * the retention period.
 *
 * Store subscriptions (App Store / Play) are tied to the user's Apple/Google
 * ID, not this app account, so they are not cancelled here. The user manages
 * them in their store settings.
 */
export async function requestDeletion(
  _req: Request,
  caller: Caller,
): Promise<Response> {
  try {
    const config = await deletionConfig();
    const now = Date.now();
    const requestedAt = new Date(now).toISOString();
    const recoveryWindowEndsAt = now + config.recoveryWaitDays * DAY_MS;
    const personalDataRetainedUntil = now +
      config.personalDataRetentionDays * DAY_MS;

    const { error } = await admin()
      .from('profiles')
      .update({
        account_status: 'deletion_pending',
        deletion_requested_at: requestedAt,
        recovery_window_ends_at: new Date(recoveryWindowEndsAt).toISOString(),
        personal_data_retained_until: new Date(personalDataRetainedUntil)
          .toISOString(),
      })
      .eq('id', caller.uid);

    if (error) return json({ success: false, message: error.message }, 500);

    // Revoke sessions so other devices lose access immediately. The account
    // itself stays enabled for the recovery window.
    try {
      await admin().auth.admin.signOut(caller.uid, 'global');
    } catch (err) {
      console.warn('Could not revoke sessions', String(err));
    }

    return json({
      success: true,
      accountStatus: 'deletion_pending',
      deletionRequestedAt: now,
      recoveryWindowEndsAt,
      personalDataRetainedUntil,
      recoveryWaitDays: config.recoveryWaitDays,
      personalDataRetentionDays: config.personalDataRetentionDays,
      // Kept for client compatibility — store subscriptions are not
      // cancelled server-side under IAP.
      subscriptionsScheduled: 0,
      subscriptionsCancelled: 0,
    });
  } catch (err) {
    console.error('requestDeletion failed', String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}

/** POST /account/recover — undo a pending deletion inside the window. */
export async function recoverAccount(
  _req: Request,
  caller: Caller,
): Promise<Response> {
  try {
    const { data: profile } = await admin()
      .from('profiles')
      .select('account_status, recovery_window_ends_at')
      .eq('id', caller.uid)
      .maybeSingle();

    if (!profile) {
      return json({ success: false, message: 'User not found' }, 404);
    }

    if (profile.account_status !== 'deletion_pending') {
      return json({
        success: false,
        message: `Account is ${profile.account_status ?? 'active'} — nothing to recover`,
      }, 400);
    }

    const endsAt = profile.recovery_window_ends_at
      ? new Date(String(profile.recovery_window_ends_at)).getTime()
      : null;
    if (endsAt !== null && Date.now() > endsAt) {
      return json({
        success: false,
        message: 'Recovery window has expired',
      }, 410);
    }

    const { error } = await admin()
      .from('profiles')
      .update({
        account_status: 'active',
        deletion_requested_at: null,
        recovery_window_ends_at: null,
        personal_data_retained_until: null,
      })
      .eq('id', caller.uid);

    if (error) return json({ success: false, message: error.message }, 500);

    console.log('Account recovered', caller.uid);
    return json({
      success: true,
      accountStatus: 'active',
      subscriptionsReactivated: 0,
    });
  } catch (err) {
    console.error('recoverAccount failed', String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}

/** Profile fields safe to hand back. Internal ids and moderation notes stay out. */
const EXPORT_FIELDS = [
  'email',
  'first_name',
  'last_name',
  'phone',
  'account_type',
  'date_of_birth',
  'bio',
  'introduction_bio',
  'currency',
  'work_status',
  'links',
  'trade',
  'address_line1',
  'address_line2',
  'city',
  'county',
  'postcode',
  'formatted_address',
  'company_name',
  'companies_house_number',
  'company_email',
  'company_landline',
  'company_website',
  'vat_registered',
  'vat_number',
  'business_name',
  'business_email',
  'created_at',
  'updated_at',
];

/**
 * GET /account/export-data
 *
 * Returns the caller's own data as a downloadable JSON file.
 *
 * Deliberately excludes bank details, document URLs and moderation fields:
 * the export is emailed and stored by users, so it is a phishing surface. The
 * original made the same choice via a whitelist, kept here.
 */
export async function exportData(
  _req: Request,
  caller: Caller,
): Promise<Response> {
  try {
    const { data: authUser } = await admin().auth.admin.getUserById(caller.uid);
    const u = authUser?.user;

    const account = {
      email: u?.email,
      emailVerified: u?.email_confirmed_at != null,
      displayName: (u?.user_metadata?.full_name ?? null) as string | null,
      phoneNumber: u?.phone ?? null,
      photoURL: (u?.user_metadata?.avatar_url ?? null) as string | null,
      accountCreatedAt: u?.created_at,
      lastSignInAt: u?.last_sign_in_at,
      authProviders: (u?.identities ?? []).map((i) => i.provider),
    };

    const { data: profileRow } = await admin()
      .from('profiles')
      .select(EXPORT_FIELDS.join(', '))
      .eq('id', caller.uid)
      .maybeSingle();

    const { data: subRow } = await admin()
      .from('subscriptions')
      .select('name, plan_type, billing_cycle, status, provider, ' +
        'current_period_start, current_period_end, auto_renew')
      .eq('owner_id', caller.uid)
      .maybeSingle();

    const payload = {
      notice:
        'This export contains personal information about your account. ' +
        'Do not share it in public channels. If you lose control of this ' +
        'file, the risk is phishing — not account takeover.',
      exportedAt: new Date().toISOString(),
      version: 3,
      account,
      profile: profileRow ?? {},
      subscriptions: subRow ? [subRow] : [],
    };

    return new Response(JSON.stringify(payload, null, 2), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': 'attachment; filename="fixitfelix-data.json"',
      },
    });
  } catch (err) {
    console.error('exportData failed', String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}

/**
 * POST /subscriptions/activate-trial
 *
 * One-shot: the free trial can be activated exactly once per account. ANY
 * pre-existing subscription row — active, expired, cancelled — blocks a
 * re-trial, so a user cannot cancel-then-restart in a loop.
 */
export async function activateTrial(
  req: Request,
  caller: Caller,
): Promise<Response> {
  try {
    let body: Record<string, string> = {};
    try {
      body = await req.json() as Record<string, string>;
    } catch { /* validated below */ }

    if (!body.planType || !body.accountType) {
      return json(
        { success: false, message: 'planType + accountType required' },
        400,
      );
    }

    const now = Date.now();
    const oneMonth = 30 * DAY_MS;

    // Insert, not upsert: a duplicate-key error IS the "already used" signal,
    // and letting the database enforce it closes the race a read-then-write
    // check would leave open.
    const { error } = await admin().from('subscriptions').insert({
      owner_id: caller.uid,
      name: body.subscriptionName ?? body.planType,
      plan_type: body.planType,
      billing_cycle: body.billingCycle ?? 'monthly',
      // 'active', not 'trial', matching the original exactly. Both satisfy
      // the app's access gate and `isPaid` keys off transaction ids rather
      // than status, so 'trial' would be safe — but it is what the UI
      // displays, and changing that is not this migration's job.
      status: 'active',
      auto_renew: true,
      current_period_start: new Date(now).toISOString(),
      current_period_end: new Date(now + oneMonth).toISOString(),
    });

    if (error) {
      // 23505 = unique_violation on the owner_id primary key.
      if (error.code === '23505') {
        return json({
          success: false,
          message: "You've already used your free trial. Subscribe to continue.",
        }, 409);
      }
      return json({ success: false, message: error.message }, 500);
    }

    const { data: created } = await admin()
      .from('subscriptions')
      .select('*')
      .eq('owner_id', caller.uid)
      .maybeSingle();

    return json({ success: true, subscription: created });
  } catch (err) {
    console.error('activateTrial failed', String(err));
    return json({ success: false, message: String(err) }, 500);
  }
}
