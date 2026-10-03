import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors [PhotoNumberSequence] for the Videos tool. Tracks the
/// next title number ("VID000001" → "VID000002" → …) in
/// SharedPreferences, separately from photos so cancelling a video
/// upload doesn't burn an image number and vice versa.
class VideoNumberSequence {
  VideoNumberSequence._();

  static const _key = 'tools.videos.nextNumber';

  /// Next number to use, without advancing. Defaults to 1 on first run.
  static Future<int> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getInt(_key) ?? 1;
    return n < 1 ? 1 : n;
  }

  /// Advance the counter — call after a successful upload.
  static Future<int> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 1;
    await prefs.setInt(_key, current + 1);
    return current;
  }

  /// Format helper: 5 → "VID000005".
  static String format(int n) => 'VID${n.toString().padLeft(6, '0')}';
}
