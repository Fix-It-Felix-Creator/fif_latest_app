import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/maps/static_map_preview.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/address_model.dart';
import '../../models/location_model.dart';
import '../../services/address_geocoder.dart';
import '../customers/address_search_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({super.key});

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
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
    if (user == null) return;
    final addr = user.address;
    _line1Ctrl.text = addr.addressLine1;
    _line2Ctrl.text = addr.addressLine2 ?? '';
    _cityCtrl.text = addr.city;
    _countyCtrl.text = addr.county ?? '';
    _postcodeCtrl.text = addr.postcode;
    _lat = user.location?.latitude;
    _lng = user.location?.longitude;
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

  Future<void> _save() async {
    if (_saving) return;

    final line1 = _line1Ctrl.text.trim();
    final city = _cityCtrl.text.trim();
    final postcode = _postcodeCtrl.text.trim();

    if (line1.isEmpty) {
      CommonToasts.error(context, 'Address line 1 is required');
      return;
    }
    if (city.isEmpty) {
      CommonToasts.error(context, 'City is required');
      return;
    }
    if (postcode.isEmpty) {
      CommonToasts.error(context, 'Postcode is required');
      return;
    }

    setState(() => _saving = true);

    // Re-geocode the postcode so manual edits end up with fresh coords.
    final candidates = await AddressGeocoder.forPostcode(postcode);
    final match = AddressGeocoder.bestMatch(candidates, line1);
    double? lat = _lat;
    double? lng = _lng;
    if (match != null) {
      if (match.latitude != null) lat = match.latitude;
      if (match.longitude != null) lng = match.longitude;
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

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _lat = lat;
      _lng = lng;
    });
    CommonToasts.success(context, 'Address updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        setState(() => _saving = false);
        CommonToasts.error(context, state.errorMessage ?? 'Update failed');
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text('Address Details'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _saving ? Colors.grey : _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _PrimaryAddressNotice(),
              _Group(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _searchPostcode,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Search UK postcode',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight,
                            size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),

              _Group(
                child: TextField(
                  controller: _line1Ctrl,
                  focusNode: _line1Focus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _line2Focus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Address line 1',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              _Group(
                child: TextField(
                  controller: _line2Ctrl,
                  focusNode: _line2Focus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _cityFocus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Address line 2 (optional)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              _Group(
                child: TextField(
                  controller: _cityCtrl,
                  focusNode: _cityFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _countyFocus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'City',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              _Group(
                child: TextField(
                  controller: _countyCtrl,
                  focusNode: _countyFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _postcodeFocus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'County (optional)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              _Group(
                child: TextField(
                  controller: _postcodeCtrl,
                  focusNode: _postcodeFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                  decoration: const InputDecoration(
                    hintText: 'Postcode',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

              if (_lat != null && _lng != null)
                _MapPreview(lat: _lat!, lng: _lng!),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAddressNotice extends StatelessWidget {
  const _PrimaryAddressNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _brand.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 16, color: _brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This address is your primary address. It is used across your '
              'company details and location based features.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.lat, required this.lng});
  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: StaticMapPreview(lat: lat, lng: lng),
      ),
    );
  }
}
