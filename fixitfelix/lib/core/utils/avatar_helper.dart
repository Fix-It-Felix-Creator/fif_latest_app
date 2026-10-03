import 'package:flutter/material.dart';

/// Initials from a full name — e.g. "Namesh Kushantha" → "NK".
/// Falls back to the first 2 chars if there's only one word.
String initialsFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) {
    final one = parts[0];
    return (one.length >= 2 ? one.substring(0, 2) : one).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Deterministic avatar colour for a name — same input always yields the
/// same hue. Saturation / lightness are fixed so the palette stays
/// on-brand.
Color avatarColorFor(String name) {
  var h = 0;
  for (final c in name.trim().toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0xfffffff;
  }
  final hue = (h % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.55, 0.48).toColor();
}
