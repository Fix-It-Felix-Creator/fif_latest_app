import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Several pins on one map image.
///
/// The same Google Static Maps approach as [StaticMapPreview], for the same
/// reason: ~2-4MB of heap against ~150MB for a live map widget, and a board of
/// leads is read-only. Tapping a pin is not possible — the list below it is
/// how somebody opens one, which is also the only way to sort by distance.
class StaticJobsMap extends StatelessWidget {
  const StaticJobsMap({
    super.key,
    required this.points,
    this.home,
    this.height = 190,
  });

  /// Job locations, already rounded to about a kilometre by the server.
  final List<({double lat, double lng})> points;

  /// Where the tradesperson works from, drawn differently so the spread of
  /// work reads relative to them rather than as an abstract cluster.
  final ({double lat, double lng})? home;

  final double height;

  String? _url() {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    if (points.isEmpty && home == null) return null;

    final markers = <String>[
      if (home != null)
        'markers=color:0x2563EB|label:Y|${home!.lat},${home!.lng}',
      // Capped: every marker is another ~30 characters and Static Maps stops
      // serving somewhere past 8KB of URL. Twenty pins is already more than
      // anybody reads off a 190pt image.
      for (final p in points.take(20))
        'markers=color:0xF64C13|${p.lat},${p.lng}',
    ];

    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?size=640x320&scale=2&maptype=roadmap'
        // No centre or zoom: Static Maps frames all the markers itself, which
        // is right when the whole point is "where is the work".
        '&${markers.join('&')}'
        '&key=$key';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url();
    if (url == null) {
      return _Placeholder(
        height: height,
        message: points.isEmpty
            ? 'Jobs near you will show here'
            : 'Set GOOGLE_MAPS_API_KEY in .env to see the map',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _Placeholder(height: height),
        errorWidget: (_, __, ___) =>
            _Placeholder(height: height, message: 'Map unavailable'),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, this.message});

  final double height;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: message == null
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
    );
  }
}
