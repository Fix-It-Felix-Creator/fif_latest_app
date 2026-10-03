import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A point on the map, and where it came from.
///
/// The source travels with it because "we found a pin" and "we found the
/// middle of your postcode" are different promises, and support will want to
/// know which one was made.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final String source;
}

/// Turning an address into coordinates, with somewhere to go when a provider
/// is down.
///
/// Three providers, tried in this order, because they fail differently and
/// cost differently:
///
///   1. postcodes.io  — free, no key, no quota, UK postcodes only. Returns the
///                      centroid of the postcode, which is close enough to
///                      match a job on even when it is not the exact door.
///   2. OS Places     — the same PAF data the address search uses, so a
///                      postcode it can list houses for it can also place.
///                      Keyed, and the one that intermittently fails.
///   3. Google        — billed per request, handles free text and typos that
///                      defeat the other two. Last because it is the only one
///                      that costs money, not because it is the worst.
///
/// Nothing here throws. A caller asking "where is this" gets a point or null,
/// and null is a real answer that the UI already knows how to explain.
class GeocodingService {
  const GeocodingService._();

  static final _ukPostcode = RegExp(
    r'^([A-Z]{1,2}\d[A-Z\d]?)\s?(\d[A-Z]{2})$',
    caseSensitive: false,
  );

  static const _timeout = Duration(seconds: 8);

  /// Coordinates for a postcode or a free-text address.
  static Future<GeoPoint?> locate(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    // A bare postcode is the common case and the cheapest to answer.
    final postcode = _extractPostcode(trimmed);
    if (postcode != null) {
      final free = await _postcodesIo(postcode);
      if (free != null) return free;

      final os = await _osPlaces(postcode);
      if (os != null) return os;
    }

    return _google(trimmed);
  }

  /// The postcode inside a longer address, if there is one.
  static String? _extractPostcode(String input) {
    if (_ukPostcode.hasMatch(input)) return input.toUpperCase();
    final match = RegExp(
      r'([A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2})\s*$',
      caseSensitive: false,
    ).firstMatch(input);
    return match?.group(1)?.toUpperCase();
  }

  static Future<GeoPoint?> _postcodesIo(String postcode) async {
    try {
      final res = await http
          .get(Uri.parse(
            'https://api.postcodes.io/postcodes/'
            '${Uri.encodeComponent(postcode)}',
          ))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final result = (jsonDecode(res.body) as Map<String, dynamic>)['result'];
      if (result is! Map) return null;
      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return GeoPoint(latitude: lat, longitude: lng, source: 'postcodes.io');
    } catch (e) {
      debugPrint('GeocodingService: postcodes.io failed — $e');
      return null;
    }
  }

  static Future<GeoPoint?> _osPlaces(String postcode) async {
    final key = dotenv.env['OS_PLACES_API_KEY'];
    if (key == null || key.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(
            'https://api.os.uk/search/places/v1/postcode'
            '?postcode=${Uri.encodeQueryComponent(postcode)}'
            '&output_srs=EPSG:4326&dataset=DPA&maxresults=1&key=$key',
          ))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final results =
          (jsonDecode(res.body) as Map<String, dynamic>)['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final dpa = (first['DPA'] ?? first['LPI']);
      if (dpa is! Map) return null;
      final lat = (dpa['LAT'] as num?)?.toDouble();
      final lng = (dpa['LNG'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return GeoPoint(latitude: lat, longitude: lng, source: 'os_places');
    } catch (e) {
      debugPrint('GeocodingService: OS Places failed — $e');
      return null;
    }
  }

  static Future<GeoPoint?> _google(String address) async {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json'
            '?address=${Uri.encodeQueryComponent(address)}'
            // Bias to the UK. Without it "Richmond" is as likely to be
            // Virginia as Surrey, and a job posted in Surrey would be matched
            // against tradespeople 3,500 miles away.
            '&region=uk'
            '&components=country:GB'
            '&key=$key',
          ))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') {
        // Logged rather than swallowed silently: REQUEST_DENIED and
        // OVER_QUERY_LIMIT are billing problems, not address problems, and
        // they look identical to "no such address" from the outside.
        debugPrint(
          'GeocodingService: Google returned ${body['status']} '
          '${body['error_message'] ?? ''}',
        );
        return null;
      }
      final results = body['results'];
      if (results is! List || results.isEmpty) return null;
      final loc = (results.first as Map)['geometry']?['location'];
      if (loc is! Map) return null;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return GeoPoint(latitude: lat, longitude: lng, source: 'google');
    } catch (e) {
      debugPrint('GeocodingService: Google failed — $e');
      return null;
    }
  }
}
