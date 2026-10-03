import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../screens/customers/address_search_screen.dart';

/// Forward-geocodes UK postcodes against Ordnance Survey's Places API,
/// returning the same [AddressResult] shape the search screen produces so
/// lat/lng is available for map previews and distance work later.
class AddressGeocoder {
  const AddressGeocoder._();

  /// Query OS Places for a postcode and return the DPA address records.
  /// Returns an empty list if the postcode isn't a valid UK format, the
  /// API key is missing, or the request fails.
  static Future<List<AddressResult>> forPostcode(String rawPostcode) async {
    final postcode = rawPostcode.trim();
    if (!_ukPostcodeRe.hasMatch(postcode)) return const [];

    final key = dotenv.env['OS_PLACES_API_KEY'];
    if (key == null || key.isEmpty) return const [];

    final uri = Uri.parse(
      'https://api.os.uk/search/places/v1/postcode'
      '?postcode=${Uri.encodeQueryComponent(postcode)}'
      '&output_srs=EPSG:4326'
      '&dataset=DPA'
      '&maxresults=100'
      '&key=$key',
    );

    http.Response res;
    try {
      res = await http.get(uri, headers: const {'Accept': 'application/json'});
    } catch (_) {
      return const [];
    }
    if (res.statusCode != 200) return const [];

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
      parsed.add(AddressResult(
        formatted: _s(m['ADDRESS']),
        line1: line1Parts.join(', '),
        line2: dep.isEmpty ? null : dep,
        city: town,
        postcode: pc,
        latitude: (m['LAT'] as num?)?.toDouble(),
        longitude: (m['LNG'] as num?)?.toDouble(),
      ));
    }
    return parsed;
  }

  /// Pick the result whose `line1` best matches the manually-typed one.
  /// Used so manual edits to line2/county don't drop the original coords,
  /// while a brand-new line1 re-points to the new house.
  static AddressResult? bestMatch(
    List<AddressResult> candidates,
    String typedLine1,
  ) {
    if (candidates.isEmpty) return null;
    final needle = typedLine1.trim().toLowerCase();
    if (needle.isEmpty) return candidates.first;
    AddressResult? best;
    int bestScore = -1;
    for (final c in candidates) {
      final score = _score(c.line1.toLowerCase(), needle);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best ?? candidates.first;
  }

  static int _score(String a, String b) {
    if (a == b) return 1000;
    if (a.contains(b) || b.contains(a)) return 500;
    var s = 0;
    for (final t in b.split(RegExp(r'\s+'))) {
      if (t.isNotEmpty && a.contains(t)) s += 10;
    }
    return s;
  }

  static String _s(Object? v) => v?.toString() ?? '';
}

final _ukPostcodeRe = RegExp(
  r'^([A-Z]{1,2}\d[A-Z\d]?)\s?(\d[A-Z]{2})$',
  caseSensitive: false,
);
