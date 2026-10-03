import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the next photo title number ("IMG000001" → "IMG000002" →
/// …) in SharedPreferences. Per-device — two devices on the same
/// account each have their own count by design.
///
/// Usage:
///   final n = await PhotoNumberSequence.peek();   // 5
///   // …user uploads…
///   await PhotoNumberSequence.consume();          // bumps to 6
class PhotoNumberSequence {
  PhotoNumberSequence._();

  static const _key = 'tools.photos.nextNumber';

  /// Read the next number to use, without advancing. Defaults to 1
  /// on first run.
  static Future<int> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getInt(_key) ?? 1;
    return n < 1 ? 1 : n;
  }

  /// Advance the counter — call after a successful upload so the
  /// next pick gets a fresh number. Returns the number that was
  /// just consumed.
  static Future<int> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 1;
    await prefs.setInt(_key, current + 1);
    return current;
  }

  /// Format helper: 5 → "IMG000005".
  static String format(int n) => 'IMG${n.toString().padLeft(6, '0')}';
}
