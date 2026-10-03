import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../services/geocoding_service.dart';
import 'address_search_screen.dart';

const _brand = Color(0xFFF64C13);

/// Typing an address the search cannot find.
///
/// Needed more often than it sounds: a new-build that PAF has not caught up
/// with, a yard or unit with no letterbox, a flat subdivided since the last
/// postcode file. Without this those people simply cannot finish, and the only
/// thing standing between them and a working address is a form.
///
/// It still geocodes on save. Everything downstream — matching a job to a
/// tradesperson, measuring distance, offering work at all — runs on
/// coordinates, so a manually typed address with no pin is an address that
/// quietly reaches nobody.
///
/// [GeocodingService] tries three providers rather than one, because the
/// reason somebody is on this screen at all is usually that a provider was
/// having a bad day.
class ManualAddressScreen extends StatefulWidget {
  const ManualAddressScreen({
    super.key,
    this.initialPostcode,
    this.knownPoint,
  });

  final String? initialPostcode;

  /// A pin the search already found for this postcode. Saves a second lookup,
  /// and means a provider outage upstream does not cost the address its
  /// coordinates down here.
  final GeoPoint? knownPoint;

  @override
  State<ManualAddressScreen> createState() => _ManualAddressScreenState();
}

class _ManualAddressScreenState extends State<ManualAddressScreen> {
  late final _line1 = TextEditingController();
  late final _line2 = TextEditingController();
  late final _city = TextEditingController();
  late final _county = TextEditingController();
  late final _postcode =
      TextEditingController(text: widget.initialPostcode ?? '');

  bool _saving = false;
  String? _warning;

  @override
  void initState() {
    super.initState();
    for (final c in [_line1, _line2, _city, _county, _postcode]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_line1, _line2, _city, _county, _postcode]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Line 1 and a town are the minimum that makes an address findable by a
  /// human. A postcode is wanted but not demanded — some yards and rural
  /// properties genuinely struggle, and blocking them helps nobody.
  bool get _ready =>
      _line1.text.trim().isNotEmpty && _city.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() {
      _saving = true;
      _warning = null;
    });

    // The whole address, not just the postcode: Google can place "Unit 4,
    // Nerston Industrial Estate" when no postcode file has heard of it, and
    // the chain only reaches Google once the free UK lookups have failed.
    final typed = <String>[
      _line1.text.trim(),
      if (_city.text.trim().isNotEmpty) _city.text.trim(),
      if (_postcode.text.trim().isNotEmpty) _postcode.text.trim(),
    ].join(', ');

    final point = widget.knownPoint ??
        await GeocodingService.locate(
          _postcode.text.trim().isNotEmpty ? _postcode.text.trim() : typed,
        ) ??
        await GeocodingService.locate(typed);

    if (!mounted) return;

    final parts = <String>[
      _line1.text.trim(),
      if (_line2.text.trim().isNotEmpty) _line2.text.trim(),
      _city.text.trim(),
      if (_county.text.trim().isNotEmpty) _county.text.trim(),
      if (_postcode.text.trim().isNotEmpty) _postcode.text.trim().toUpperCase(),
    ];

    final result = AddressResult(
      formatted: parts.join(', '),
      line1: _line1.text.trim(),
      line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim(),
      county: _county.text.trim().isEmpty ? null : _county.text.trim(),
      postcode: _postcode.text.trim().toUpperCase(),
      latitude: point?.latitude,
      longitude: point?.longitude,
    );

    if (point == null) {
      // Said once, then saved anyway on the second tap. Refusing outright
      // would strand somebody whose postcode is simply too new.
      setState(() {
        _saving = false;
        _warning = 'We could not find that postcode on the map. Check it, or '
            'tap Save again to use the address without a map pin.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    // Second tap after a warning saves regardless.
    final saveLabel = _warning == null ? 'Save address' : 'Save anyway';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Enter address'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Field(
              label: 'Address line 1',
              hint: 'House number and street',
              controller: _line1,
              textInputAction: TextInputAction.next,
            ),
            _Field(
              label: 'Address line 2',
              hint: 'Flat, unit, building (optional)',
              controller: _line2,
              textInputAction: TextInputAction.next,
            ),
            _Field(
              label: 'Town or city',
              hint: 'e.g. East Kilbride',
              controller: _city,
              textInputAction: TextInputAction.next,
            ),
            _Field(
              label: 'County',
              hint: 'Optional',
              controller: _county,
              textInputAction: TextInputAction.next,
            ),
            _Field(
              label: 'Postcode',
              hint: 'e.g. G74 3NN',
              controller: _postcode,
              capitals: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_warning != null)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.triangleAlert,
                        size: 15, color: Color(0xFF92400E)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _warning!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'We use the postcode to place you on the map. Nobody is shown '
              'your exact address until you accept their job.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ready && !_saving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(saveLabel),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.capitals = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool capitals;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            textCapitalization: capitals
                ? TextCapitalization.characters
                : TextCapitalization.words,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.28),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brand),
              ),
            ),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
