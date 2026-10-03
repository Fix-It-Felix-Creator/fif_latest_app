import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lightweight map thumbnail rendered via Google Static Maps API.
/// ~2–4 MB of heap vs ~150 MB for a full `GoogleMap` widget, so this is
/// what we use everywhere the map is read-only.
///
/// Requires `GOOGLE_MAPS_API_KEY` in `.env` and the *Maps Static API*
/// enabled on the same Cloud project as the SDK key.
class StaticMapPreview extends StatelessWidget {
  const StaticMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.zoom = 16,
    this.width = 600,
    this.height = 360,
  });

  final double lat;
  final double lng;
  final int zoom;
  final int width;
  final int height;

  String? get _apiKey {
    final k = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (k == null || k.isEmpty || k == 'PASTE_YOUR_KEY_HERE') return null;
    return k;
  }

  Uri _buildUri(double devicePixelRatio) {
    // `scale=2` gives retina tiles; Google supports 1 or 2 only.
    final scale = devicePixelRatio >= 2 ? 2 : 1;
    return Uri.parse(
      'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$lat,$lng'
      '&zoom=$zoom'
      '&size=${width}x$height'
      '&scale=$scale'
      '&markers=color:red%7C$lat,$lng'
      '&key=$_apiKey',
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _apiKey;
    if (key == null) {
      return _Placeholder(
        text: 'Set GOOGLE_MAPS_API_KEY in .env to enable map previews',
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: _buildUri(dpr).toString(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: Colors.grey.shade100),
      errorWidget: (_, __, ___) => const _Placeholder(
        text: 'Map unavailable',
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }
}
