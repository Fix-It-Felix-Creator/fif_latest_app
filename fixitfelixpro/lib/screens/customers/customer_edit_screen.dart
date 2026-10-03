import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/maps/static_map_preview.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/customer.dart';
import '../../repositories/customers/customers_repository.dart';
import 'address_search_screen.dart';
import 'contact_import_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class CustomerEditArgs {
  const CustomerEditArgs({this.existing});
  final Customer? existing;
}

class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({super.key, this.args});
  final CustomerEditArgs? args;

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  AddressResult? _address;
  String? _existingFormattedAddress;
  String _existingLine1 = '';
  String _existingCity = '';
  String _existingPostcode = '';
  String? _existingCounty;
  double? _existingLat;
  double? _existingLng;

  bool _saving = false;

  bool get _isEditing => widget.args?.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.args?.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emailCtrl.text = e.email;
      _phoneCtrl.text = e.phone;
      _existingFormattedAddress = e.formattedAddress ?? e.address;
      _existingLine1 = e.addressLine1;
      _existingCity = e.city;
      _existingPostcode = e.postcode;
      _existingCounty = e.county;
      _existingLat = e.latitude;
      _existingLng = e.longitude;
    }

    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final r = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(
          initialQuery: _address?.postcode ?? _existingPostcode,
        ),
      ),
    );
    if (r == null) return;
    setState(() {
      _address = r;
      _existingFormattedAddress = r.formatted;
      _existingLine1 = r.line1;
      _existingCity = r.city;
      _existingPostcode = r.postcode;
      _existingCounty = r.county;
      _existingLat = r.latitude;
      _existingLng = r.longitude;
    });
  }

  Future<void> _importFromContacts() async {
    final r = await Navigator.of(context).push<ContactImportResult>(
      MaterialPageRoute(builder: (_) => const ContactImportScreen()),
    );
    if (r == null || !mounted) return;

    setState(() {
      // Overwrite rather than merge: the user asked for this contact, and a
      // half-applied import ("name changed, phone did not") is harder to
      // reason about than a clean replace they can still edit.
      _nameCtrl.text = r.name;
      _emailCtrl.text = r.email;
      _phoneCtrl.text = r.phone;

      // Only touch the address when the contact actually carries one, so
      // importing a contact with no address cannot wipe an address the user
      // already picked.
      if (r.hasAddress) {
        _address = null;
        _existingLine1 = r.line1;
        _existingCity = r.city;
        _existingPostcode = r.postcode;
        _existingCounty = r.county;
        _existingFormattedAddress = r.formattedAddress ??
            [r.line1, r.city, r.postcode]
                .where((p) => p.isNotEmpty)
                .join(', ');
        // A contact address is text, not a geocoded point. Clearing these
        // hides the map preview rather than leaving it pinned to whatever
        // address was there before.
        _existingLat = null;
        _existingLng = null;
      }
    });

    if (!mounted) return;
    CommonToasts.success(
      context,
      r.hasAddress
          ? 'Imported ${r.name}'
          : 'Imported ${r.name} — add an address below',
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      CommonToasts.error(context, 'Add a customer name');
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<CustomersRepository>();

    final existing = widget.args?.existing;
    final now = DateTime.now();

    final customer = Customer(
      id: existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      addressLine1: _existingLine1,
      city: _existingCity,
      postcode: _existingPostcode,
      county: _existingCounty,
      latitude: _existingLat,
      longitude: _existingLng,
      formattedAddress: _existingFormattedAddress,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Customer? saved;
    if (existing == null) {
      final newId = await repo.create(customer);
      if (newId != null) {
        saved = customer.copyWith(id: newId);
      }
    } else {
      final ok = await repo.update(customer);
      if (ok) saved = customer;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) {
      // Caller (e.g. pick-mode Customers list) receives the fresh row.
      Navigator.of(context).pop(saved);
    } else {
      CommonToasts.error(context, 'Could not save');
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.args?.existing;
    if (existing == null) return;

    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete this customer?',
      message:
          'This will remove ${existing.name}. This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => _performDelete(existing.id),
    );
  }

  Future<void> _performDelete(String id) async {
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await context.read<CustomersRepository>().delete(id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      CommonToasts.error(context, 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim();
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_isEditing ? 'Edit customer' : 'New customer'),
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
            // Import is offered only when creating. On an existing customer it
            // would silently overwrite saved details, which is a different and
            // more dangerous action than filling in a blank form.
            if (!_isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _importFromContacts,
                  icon: const Icon(LucideIcons.contact, size: 18),
                  label: const Text('Import from contacts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Avatar preview — initials + generated colour
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: name.isEmpty
                      ? Colors.grey.shade300
                      : avatarColorFor(name),
                  child: Text(
                    name.isEmpty ? '?' : initialsFromName(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            _Group(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _emailFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Customer name',
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
                controller: _emailCtrl,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Email',
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
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Phone',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            _Group(
              children: [
                _AddressRow(
                  address: _existingFormattedAddress,
                  onTap: _pickAddress,
                ),
              ],
            ),

            if (_existingLat != null && _existingLng != null)
              _AddressMap(
                lat: _existingLat!,
                lng: _existingLng!,
                address: _existingFormattedAddress,
              ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(
                    'Delete customer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({this.child, this.children});
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children ?? const [],
          ),
    );
  }
}

class _AddressMap extends StatelessWidget {
  const _AddressMap({
    required this.lat,
    required this.lng,
    required this.address,
  });
  final double lat;
  final double lng;
  final String? address;

  /// Prefer the full address text — Apple/Google Maps will route to the
  /// exact PAF building rather than the point our preview pin sits on
  /// (which can be a few metres off on dense urban rows).
  /// Fall back to lat/lng only if we don't have a formatted address yet.
  String _daddr() {
    final a = address?.trim();
    if (a != null && a.isNotEmpty) return a;
    return '$lat,$lng';
  }

  Future<void> _openAppleMaps() async {
    final uri = Uri(
      scheme: 'http',
      host: 'maps.apple.com',
      queryParameters: {'daddr': _daddr()},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: {'api': '1', 'destination': _daddr()},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showDirectionsSheet(BuildContext context) async {
    // Apple Maps doesn't exist on Android — go straight to Google Maps.
    if (Platform.isAndroid) {
      await _openGoogleMaps();
      return;
    }
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Get directions'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openAppleMaps();
              },
              child: const Text('Apple Maps'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openGoogleMaps();
              },
              child: const Text('Google Maps'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }

    // Other platforms — fall back to Google Maps.
    await _openGoogleMaps();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDirectionsSheet(context),
      child: Container(
        height: 180,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              StaticMapPreview(lat: lat, lng: lng),
            // Small "tap to get directions" hint chip.
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.navigation, size: 12, color: _brand),
                    SizedBox(width: 4),
                    Text(
                      'Directions',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onTap});
  final String? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = address != null && address!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.mapPin, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? address! : 'Address',
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
