import 'package:flutter/material.dart';

/// The Pro app's inset-grouped list primitives.
///
/// Lifted from `fixitfelixpro/lib/screens/quotes/new_quote_screen.dart`, where
/// they are private. They live here rather than being copied into each screen
/// that wants them: a customer confirming a job and a tradesperson writing a
/// quote are looking at the same product, and two copies of a design are two
/// designs as soon as one of them is touched.
///
/// The shape is a plain-language grouped list — a small grey caption, then a
/// white card of rows divided by hairlines, on a grey page.

/// The grey caption above a group.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// A white card of rows. Deliberately borderless — the grey page behind it is
/// what separates it, and a border as well reads as a box inside a box.
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The line between two rows of a group.
///
/// Inset from the left so it starts under the text rather than cutting the
/// row's leading icon or thumbnail in half.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),
      );
}
