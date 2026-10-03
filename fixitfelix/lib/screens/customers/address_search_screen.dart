import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../services/geocoding_service.dart';
import 'manual_address_screen.dart';

const _brand = Color(0xFFF64C13);

/// Result returned from [AddressSearchScreen] via `Navigator.pop`.
class AddressResult {
  const AddressResult({
    required this.formatted,
    this.line1 = '',
    this.line2,
    this.city = '',
    this.postcode = '',
    this.county,
    this.latitude,
    this.longitude,
  });

  final String formatted;
  final String line1;
  final String? line2;
  final String city;
  final String postcode;
  final String? county;
  final double? latitude;
  final double? longitude;
}

/// UK postcode full-match pattern, e.g. `SW1A 1AA`, `G74 3NN`, `M1 1AE`.
final _ukPostcodeRe = RegExp(
  r'^([A-Z]{1,2}\d[A-Z\d]?)\s?(\d[A-Z]{2})$',
  caseSensitive: false,
);

/// UK address search.
///
/// - Full postcode → **getAddress.io** `/find/{postcode}` returns the full
///   list of houses / flats at that postcode (PAF data).
/// - Partial postcode → **postcodes.io** autocomplete chips so the user
///   can pick the full postcode quickly.
/// - Postcode metadata banner (district / county) also from postcodes.io.
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  http.Client? _client;

  List<AddressResult> _results = const [];
  bool _loading = false;
  String? _error;

  String? get _osPlacesKey {
    final k = dotenv.env['OS_PLACES_API_KEY'];
    if (k == null || k.isEmpty) return null;
    return k;
  }

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    // DEBUG — confirm what dotenv actually saw at startup.
    debugPrint(
      'AddressSearch: dotenv loaded keys = ${dotenv.env.keys.toList()}',
    );
    debugPrint(
      'AddressSearch: OS_PLACES_API_KEY present = '
      '${dotenv.env.containsKey("OS_PLACES_API_KEY")} '
      'len=${dotenv.env["OS_PLACES_API_KEY"]?.length ?? 0}',
    );
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _run(widget.initialQuery!);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _client?.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Coordinates for a postcode the house search could not answer for.
  ///
  /// Held so the manual form can be handed a pin it did not have to find
  /// again, and so the screen can say the postcode is real even when the
  /// address list is empty.
  GeoPoint? _fallbackPoint;

  Future<void> _resolveFallback(String postcode) async {
    final point = await GeocodingService.locate(postcode);
    if (!mounted) return;
    setState(() => _fallbackPoint = point);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(trimmed));
  }

  Future<void> _run(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
      _fallbackPoint = null;
    });

    final isFullPostcode = _ukPostcodeRe.hasMatch(query);

    try {
      if (!isFullPostcode) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Type a full UK postcode — e.g. G74 3NN';
        });
        return;
      }
      final addresses = await _osPlacesFind(query);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = addresses;
        _error = addresses.isEmpty
            ? 'No addresses found for this postcode'
            : null;
      });
      // A postcode that listed no houses is still a real place. Resolve it
      // anyway so the manual form below opens with a pin already found —
      // otherwise an OS Places outage costs the user their coordinates as
      // well as the house list, and the coordinates are the part that
      // actually matters.
      if (addresses.isEmpty) unawaited(_resolveFallback(query));
    } catch (e) {
      if (!mounted) return;
      unawaited(_resolveFallback(query));
      setState(() {
        _loading = false;
        _error = 'Could not search addresses';
      });
    }
  }

  /// Ordnance Survey Places API — house-level UK addresses.
  /// `GET https://api.os.uk/search/places/v1/postcode?postcode=...&key=...`
  /// Returns the DPA (Delivery Point Address) records for the postcode.
  Future<List<AddressResult>> _osPlacesFind(String postcode) async {
    final key = _osPlacesKey;
    if (key == null) {
      throw const _MissingKeyException();
    }
    final uri = Uri.parse(
      'https://api.os.uk/search/places/v1/postcode'
      '?postcode=${Uri.encodeQueryComponent(postcode)}'
      '&output_srs=EPSG:4326'
      '&dataset=DPA'
      '&maxresults=100'
      '&key=$key',
    );
    final res = await _client!.get(uri, headers: const {
      'Accept': 'application/json',
    });
    if (res.statusCode == 400 || res.statusCode == 404) return const [];
    if (res.statusCode != 200) {
      throw Exception('OS Places HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'];
    if (results is! List) return const [];

    final parsed = <AddressResult>[];
    for (final row in results.whereType<Map<String, dynamic>>()) {
      final dpa = (row['DPA'] ?? row['LPI']);
      if (dpa is! Map) continue;
      final m = dpa.cast<String, dynamic>();

      final sub = _s(m['SUB_BUILDING_NAME']);
      final bldg = _s(m['BUILDING_NAME']);
      final number = _s(m['BUILDING_NUMBER']);
      final thr = _s(m['THOROUGHFARE_NAME']);
      final dep = _s(m['DEPENDENT_LOCALITY']);
      final town = _s(m['POST_TOWN']);
      final pc = _s(m['POSTCODE']);

      final line1Parts = <String>[
        if (sub.isNotEmpty) sub,
        if (bldg.isNotEmpty) bldg,
        if (number.isNotEmpty && thr.isNotEmpty) '$number $thr',
        if (number.isEmpty && thr.isNotEmpty) thr,
      ];
      final line1 = line1Parts.join(', ');

      parsed.add(AddressResult(
        formatted: _s(m['ADDRESS']),
        line1: line1,
        line2: dep.isEmpty ? null : dep,
        city: town,
        postcode: pc,
        latitude: (m['LAT'] as num?)?.toDouble(),
        longitude: (m['LNG'] as num?)?.toDouble(),
      ));
    }

    // OS returns results unsorted; sort numerically by building number
    // when available so "1, 2, 3, …" appear in order.
    parsed.sort((a, b) {
      final ai = _leadingNumber(a.line1);
      final bi = _leadingNumber(b.line1);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.line1.compareTo(b.line1);
    });
    return parsed;
  }

  static String _s(Object? v) => v?.toString() ?? '';

  static int? _leadingNumber(String s) {
    final m = RegExp(r'^(\d+)').firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    final missingKey = _osPlacesKey == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Search address'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: _run,
                decoration: InputDecoration(
                  hintText: 'UK postcode (e.g. G74 3NN)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon:
                      Icon(LucideIcons.search, color: Colors.grey.shade500),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(LucideIcons.x,
                              size: 16, color: Colors.grey.shade500),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (missingKey)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.triangleAlert,
                          size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'OS_PLACES_API_KEY missing in .env — house-level '
                          'lookup is disabled.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading) const _LoadingStrip(),
            if (_error != null && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            Expanded(
              child: ListView.separated(
                // One extra row on the end: the way out for anybody the
                // search cannot help. Always present rather than appearing
                // only after a failed search — somebody who knows their
                // new-build is not on PAF yet should not have to fail first
                // to be offered the form.
                itemCount: _results.length + 1,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.shade200,
                  indent: 56,
                ),
                itemBuilder: (_, i) {
                  if (i == _results.length) {
                    return _ManualEntryRow(
                      // Carries whatever they typed across, so a postcode
                      // already entered is not typed twice.
                      postcode: _ukPostcodeRe.hasMatch(_controller.text.trim())
                          ? _controller.text.trim().toUpperCase()
                          : null,
                      prominent: _results.isEmpty,
                      knownPoint: _fallbackPoint,
                    );
                  }
                  final r = _results[i];
                  return ListTile(
                    leading: Icon(LucideIcons.mapPin,
                        color: Colors.grey.shade500, size: 20),
                    title: Text(
                      r.line1.isEmpty
                          ? r.formatted.split(',').first
                          : r.line1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _subtitle(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AddressResult r) {
    final parts = [
      if (r.line2 != null && r.line2!.isNotEmpty) r.line2!,
      if (r.city.isNotEmpty) r.city,
      if (r.postcode.isNotEmpty) r.postcode,
    ];
    return parts.isEmpty ? r.formatted : parts.join(' • ');
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
      ),
    );
  }
}

class _MissingKeyException implements Exception {
  const _MissingKeyException();
}

/// The way out of the search, for addresses it cannot find.
class _ManualEntryRow extends StatelessWidget {
  const _ManualEntryRow({
    required this.postcode,
    required this.prominent,
    this.knownPoint,
  });

  final String? postcode;

  /// A pin already found for this postcode by another provider, so the form
  /// does not have to look it up a second time — and so somebody typing an
  /// address during an OS Places outage still ends up on the map.
  final GeoPoint? knownPoint;

  /// Louder when there are no results to choose from, quiet when it is the
  /// last row under a list somebody is about to pick from.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        LucideIcons.squarePen,
        size: 20,
        color: prominent ? _brand : Colors.grey.shade500,
      ),
      title: Text(
        'Enter the address manually',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: prominent ? _brand : Colors.black87,
        ),
      ),
      subtitle: Text(
        prominent
            ? (knownPoint != null
                ? 'We found the postcode on the map — just add your street'
                : 'New builds and units are often missing from the search')
            : 'If yours is not listed above',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: () async {
        final result = await Navigator.of(context).push<AddressResult>(
          MaterialPageRoute(
            builder: (_) => ManualAddressScreen(
              initialPostcode: postcode,
              knownPoint: knownPoint,
            ),
          ),
        );
        if (result == null || !context.mounted) return;
        // Straight back out to whoever opened the search, carrying the typed
        // address — the search screen has nothing left to add.
        Navigator.of(context).pop(result);
      },
    );
  }
}
