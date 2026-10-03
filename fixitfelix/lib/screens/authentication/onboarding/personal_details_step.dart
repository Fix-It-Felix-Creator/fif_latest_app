import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../models/app_user.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../core/enum.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../repositories/authentication/authentication_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Low-opacity placeholder styling shared across every input on the
/// onboarding steps so the empty state stays subtle but visible.
final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

/// Step 1 of the simplified onboarding flow.
///
/// Captures first name, last name and phone number. On Continue we write
/// these fields onto the user's profile (creating the record if it didn't
/// exist) and route to step 2, the address.
///
/// The pro app's company step sits between the two; a customer has no company
/// to declare, so this flow is two steps rather than three.
class PersonalDetailsStep extends StatefulWidget {
  const PersonalDetailsStep({super.key});

  @override
  State<PersonalDetailsStep> createState() => _PersonalDetailsStepState();
}

class _PersonalDetailsStepState extends State<PersonalDetailsStep> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _saving = false;
  bool _hydrated = false;

  /// Set once the user types into a name field — after that we never
  /// overwrite their input with provider defaults.
  bool _nameTouched = false;
  bool _disposed = false;

  /// Whether the current Firebase user signed in via Apple or Google.
  /// We only lock the name fields for these users — App Store Guideline 4
  /// forbids re-asking for a name the provider already returned, so when
  /// we have the name from the provider we render it as locked profile
  /// info instead of editable inputs.
  bool get _isOAuthUser {
    final user = SupabaseService().auth.currentUser;
    if (user == null) return false;
    // Supabase reports providers as 'apple' / 'google' rather than Firebase's
    // 'apple.com' / 'google.com'.
    final providers = AppUser.fromSupabase(user).providerIds;
    return providers.contains('apple') || providers.contains('google');
  }

  /// True once we have a first AND last name we trust — either from the
  /// RTDB record (persisted on first Apple/Google sign-in) or from the
  /// Firebase user's displayName / linked provider profile. When this is
  /// true on an OAuth sign-in we render the name as locked summary text
  /// instead of editable inputs.
  bool get _nameKnown =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty;

  /// True only when the name fields should be locked (read-only display).
  /// We only lock for OAuth users with a known name — email/password
  /// signups always edit their own name. OAuth users with no name (e.g.
  /// re-authorized Apple ID that withheld the name) fall through to
  /// editable fields.
  bool get _nameLocked => _isOAuthUser && _nameKnown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrate();
      _pollProviderName();
    });
  }

  /// Bounded retry that keeps trying to pre-fill the name for a few seconds
  /// after the screen opens.
  ///
  /// Why this is needed: on a fresh Apple sign-in the name lives on the
  /// Firebase user's *server-side* `displayName` (Apple only returns the
  /// name on the very first authorization; we persist it there). Right
  /// after `signInWithCredential` the local `currentUser` is stale, so its
  /// `displayName` reads null until a `reload()` fetches the server
  /// profile. There is also no auth-state emission to re-drive the
  /// BlocListener when the only source is `displayName` (vs. the RTDB
  /// stream). Reloading + re-applying on a short loop covers both the
  /// race and the already-authorized-Apple-ID case (incl. the App Store
  /// reviewer reusing an Apple ID), without restructuring the auth flow.
  Future<void> _pollProviderName() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (_disposed || _nameTouched) return;
      if (_firstNameCtrl.text.trim().isNotEmpty ||
          _lastNameCtrl.text.trim().isNotEmpty) {
        return;
      }
      try {
        // Firebase had User.reload(); refreshing the session is the Supabase
        // equivalent and re-reads the server-side user metadata.
        if (SupabaseService().auth.currentSession != null) {
          await SupabaseService().auth.refreshSession();
        }
      } catch (_) {
        // Offline / transient — keep trying; _applyNameDefaults still
        // checks the bloc's userDetails which may arrive via the stream.
      }
      if (_disposed) return;
      _applyNameDefaults();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _hydrate() {
    final user = context.read<AuthBloc>().state.userDetails;
    if (!_hydrated && user != null) {
      _firstNameCtrl.text = user.firstName ?? '';
      _lastNameCtrl.text = user.lastName ?? '';
      _phoneCtrl.text = user.phoneNumber;
    }
    _applyNameDefaults();
    if (mounted) setState(() => _hydrated = true);
  }

  /// Pre-fills the first/last name from whatever the OAuth provider gave us
  /// when the form still has no name — so a fresh Apple/Google user is never
  /// asked to re-type a name we already have (App Store Guideline 4).
  ///
  /// Safe to call repeatedly: it bails once the user has typed a name, once
  /// the fields are populated, or when no provider name is available. This
  /// is driven by a BlocListener too, because on a fresh sign-in the name
  /// (DB record or Firebase displayName) often lands a beat *after* the
  /// first frame.
  void _applyNameDefaults() {
    if (_nameTouched) return;
    if (_firstNameCtrl.text.trim().isNotEmpty ||
        _lastNameCtrl.text.trim().isNotEmpty) {
      return;
    }

    // 1. DB record (set by the repository's OAuth name persist).
    final details = context.read<AuthBloc>().state.userDetails;
    var first = (details?.firstName ?? '').trim();
    var last = (details?.lastName ?? '').trim();

    // 2. Auth user displayName / linked provider profiles.
    if (first.isEmpty && last.isEmpty) {
      final rawUser = SupabaseService().auth.currentUser;
      final authUser = rawUser == null ? null : AppUser.fromSupabase(rawUser);
      var name = (authUser?.displayName ?? '').trim();
      if (name.isEmpty) {
        // Supabase merges provider profile data into userMetadata, so the
        // per-provider displayName list Firebase exposed has no equivalent —
        // identity metadata is the closest source.
        for (final identity in rawUser?.identities ?? const []) {
          final data = identity.identityData ?? const <String, dynamic>{};
          final pn = (data['full_name'] ?? data['name'] ?? '').toString().trim();
          if (pn.isNotEmpty) {
            name = pn;
            break;
          }
        }
      }
      if (name.isNotEmpty) {
        final parts =
            name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          first = parts.first;
          last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
      }
    }

    if (first.isEmpty && last.isEmpty) return;
    _firstNameCtrl.text = first;
    _lastNameCtrl.text = last;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_saving) return false;
    if (_firstNameCtrl.text.trim().length < 2) return false;
    // Last name is OPTIONAL: Apple/Google often return no surname (Apple
    // only gives the name on first authorization, and many accounts are
    // single-name), and some users genuinely have no surname. Requiring it
    // here permanently disabled Continue for those users. First name +
    // phone is enough to proceed.
    if (_phoneCtrl.text.trim().length < 7) return false;
    return true;
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);

    final auth = SupabaseService().auth.currentUser;
    final updates = <String, dynamic>{
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      // Customer, not tradesman. Carried over from the pro app, this line
      // relabelled the account on Continue and undid the claim made at
      // sign-up — the profile became a tradesperson, and the account-type
      // gate then correctly refused its owner from their own app.
      'accountType': AccountCategoryType.customer.name,
      // Bootstrap fields the backend expects on a fresh record.
      if (auth?.email != null) 'email': auth!.email,
      if (auth != null) 'uid': auth.id,
      // Note: `verificationStatus` is server-controlled (RTDB rules
      // forbid client writes). The simplified flow has no manual
      // review step, so there's nothing the client needs to set here.
    };
    context.read<AuthBloc>().add(
      UpdateUserDetailsRequested(updates: updates),
    );

    // Give the stream listener a beat to propagate before navigating
    // — step 2 hydrates from AuthBloc.state.userDetails and we want it
    // to see the latest writes.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pushNamed('/onboarding/address');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // On a fresh OAuth sign-in the name (DB record or Firebase
      // displayName) frequently arrives a frame or two after this screen
      // is first built, so re-apply the provider name defaults whenever
      // auth state changes until the user types their own.
      listenWhen: (prev, curr) => !_nameTouched,
      listener: (_, __) => _applyNameDefaults(),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      // No back button — there's nowhere meaningful to go back to from
      // step 1 of a forced onboarding flow.
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Tell us about you'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _StepHeader(
              step: 1,
              total: 2,
              title: 'Your details',
              subtitle:
                  'A few quick details so a tradesperson knows who they are\n'
                  'coming out to.',
            ),
            const SizedBox(height: 16),
            _Group(
              children: [
                _LabelledField(
                  label: 'First name',
                  child: _nameLocked
                      ? _LockedNameValue(value: _firstNameCtrl.text.trim())
                      : TextField(
                          controller: _firstNameCtrl,
                          focusNode: _firstNameFocus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _lastNameFocus.requestFocus(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r"[A-Za-z\s\-']"),
                            ),
                            LengthLimitingTextInputFormatter(40),
                          ],
                          onChanged: (_) =>
                              setState(() => _nameTouched = true),
                          decoration: InputDecoration(
                            hintText: 'James',
                            hintStyle: _hintStyle,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
                const _HairlineDivider(),
                _LabelledField(
                  label: _nameLocked ? 'Last name' : 'Last name (optional)',
                  child: _nameLocked
                      ? _LockedNameValue(value: _lastNameCtrl.text.trim())
                      : TextField(
                          controller: _lastNameCtrl,
                          focusNode: _lastNameFocus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _phoneFocus.requestFocus(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r"[A-Za-z\s\-']"),
                            ),
                            LengthLimitingTextInputFormatter(40),
                          ],
                          onChanged: (_) =>
                              setState(() => _nameTouched = true),
                          decoration: InputDecoration(
                            hintText: 'Smith',
                            hintStyle: _hintStyle,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
                const _HairlineDivider(),
                _LabelledField(
                  label: 'Phone number',
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '07700 900000',
                      hintStyle: _hintStyle,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : _onSignOut,
              child: Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sign-out escape hatch — onboarding is forced (no back button), so
  /// the only way to bail mid-flow is to log out. Uses the same warning
  /// dialog as the Settings → Sign Out flow so the chrome stays
  /// consistent app-wide.
  Future<void> _onSignOut() async {
    await CommonDialogs.showWarningBox(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      icon: LucideIcons.logOut,
      yesText: 'Yes, Sign Out',
      noText: 'No',
      onConfirm: () async {
        if (!mounted) return;
        try {
          await context.read<AuthRepository>().signOut();
        } catch (e) {
          if (!mounted) return;
          await CommonDialogs.showErrorDialog(
            context,
            title: 'Sign Out Failed',
            message: '$e',
          );
        }
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final int total;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step OF $total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: _brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      );
}

/// Locked, non-editable display of a name value pulled from the OAuth
/// provider. Renders as muted profile text with a checkmark — visually
/// distinct from a TextField so App Store reviewers can see at a glance
/// that the user isn't being asked to provide the name (Guideline 4).
class _LockedNameValue extends StatelessWidget {
  const _LockedNameValue({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Icon(LucideIcons.lock, size: 14, color: Colors.grey.shade400),
      ],
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
