import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../models/address_model.dart';
import '../../../models/location_model.dart';
import '../../../services/address_geocoder.dart';
import '../../customers/address_search_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

/// Step 2 (final) of the onboarding flow.
///
/// Mirrors the postcode-search + manual-fields pattern from
/// `settings/address_edit_screen.dart`. On Finish we save the address
/// (and best-effort lat/lng from the geocoder), then route to the
/// home screen and clear the navigation stack so the user can't
/// drift back into the onboarding flow.
class AddressStep extends StatefulWidget {
  const AddressStep({super.key});

  @override
  State<AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<AddressStep> {
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  final _line1Focus = FocusNode();
  final _line2Focus = FocusNode();
  final _cityFocus = FocusNode();
  final _countyFocus = FocusNode();
  final _postcodeFocus = FocusNode();

  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  void _hydrate() {
    if (_hydrated) return;
    final user = context.read<AuthBloc>().state.userDetails;
    if (user != null) {
      final addr = user.address;
      _line1Ctrl.text = addr.addressLine1;
      _line2Ctrl.text = addr.addressLine2 ?? '';
      _cityCtrl.text = addr.city;
      _countyCtrl.text = addr.county ?? '';
      _postcodeCtrl.text = addr.postcode;
      _lat = user.location?.latitude;
      _lng = user.location?.longitude;
    }
    setState(() => _hydrated = true);
  }

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _countyCtrl.dispose();
    _postcodeCtrl.dispose();
    _line1Focus.dispose();
    _line2Focus.dispose();
    _cityFocus.dispose();
    _countyFocus.dispose();
    _postcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _searchPostcode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final r = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(
          initialQuery: _postcodeCtrl.text.trim().isEmpty
              ? null
              : _postcodeCtrl.text.trim(),
        ),
      ),
    );
    if (r == null) return;
    setState(() {
      _line1Ctrl.text = r.line1;
      _line2Ctrl.text = r.line2 ?? '';
      _cityCtrl.text = r.city;
      _countyCtrl.text = r.county ?? '';
      _postcodeCtrl.text = r.postcode;
      _lat = r.latitude;
      _lng = r.longitude;
    });
  }

  bool get _canFinish {
    if (_saving) return false;
    if (_line1Ctrl.text.trim().isEmpty) return false;
    if (_cityCtrl.text.trim().isEmpty) return false;
    if (_postcodeCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _onFinish() async {
    if (!_canFinish) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);

    final line1 = _line1Ctrl.text.trim();
    final city = _cityCtrl.text.trim();
    final postcode = _postcodeCtrl.text.trim();

    // Re-geocode the postcode so manual edits end up with fresh
    // coords. Best-effort only — failure here doesn't block onboarding.
    double? lat = _lat;
    double? lng = _lng;
    try {
      final candidates = await AddressGeocoder.forPostcode(postcode);
      final match = AddressGeocoder.bestMatch(candidates, line1);
      if (match != null) {
        if (match.latitude != null) lat = match.latitude;
        if (match.longitude != null) lng = match.longitude;
      }
    } catch (_) {
      // Swallow — address still saves without lat/lng.
    }

    final address = AddressModel(
      addressLine1: line1,
      addressLine2: _line2Ctrl.text.trim(),
      city: city,
      county: _countyCtrl.text.trim(),
      postcode: postcode,
    );
    final location = LocationModel(
      address: address.formatted,
      latitude: lat,
      longitude: lng,
    );

    if (!mounted) return;
    context.read<AuthBloc>().add(
      UpdateUserDetailsRequested(
        updates: {
          'address': address.toJson(),
          'location': location.toJson(),
          'lastAddressUpdatedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    // Wait for the stream listener to flush so the home screen reads
    // the latest userDetails on first paint.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    // Onboarding finished. The pro app hands off to its subscription gate
    // here; a customer has nothing to subscribe to, so this goes straight
    // home.
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Always the second of two: there is no company step in this app.
    const totalSteps = 2;
    const stepNumber = 2;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        setState(() => _saving = false);
        CommonToasts.error(context, state.errorMessage ?? 'Save failed');
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text('Your address'),
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
                step: stepNumber,
                total: totalSteps,
                title: 'Where you\'re based',
                subtitle:
                    'Helps us localise your invoices and shows on the '
                    'PDF footer. Editable later from Settings.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _searchPostcode,
                  icon: const Icon(LucideIcons.search, size: 18),
                  label: const Text('Search by postcode'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Group(
                children: [
                  _LabelledField(
                    label: 'Address line 1',
                    child: TextField(
                      controller: _line1Ctrl,
                      focusNode: _line1Focus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _line2Focus.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '100 Argyle Street',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'Address line 2 (optional)',
                    child: TextField(
                      controller: _line2Ctrl,
                      focusNode: _line2Focus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _cityFocus.requestFocus(),
                      decoration: InputDecoration(
                        hintText: 'Flat 2/1',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'City',
                    child: TextField(
                      controller: _cityCtrl,
                      focusNode: _cityFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _countyFocus.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Glasgow',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'County (optional)',
                    child: TextField(
                      controller: _countyCtrl,
                      focusNode: _countyFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _postcodeFocus.requestFocus(),
                      decoration: InputDecoration(
                        hintText: 'Lanarkshire',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'Postcode',
                    child: TextField(
                      controller: _postcodeCtrl,
                      focusNode: _postcodeFocus,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9 ]'),
                        ),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'G2 8BU',
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
                  onPressed: _canFinish ? _onFinish : null,
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
                      : const Text('Finish setup'),
                ),
              ),
            ],
          ),
        ),
      ),
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
            style: const TextStyle(
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
