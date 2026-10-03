import 'pricing_item.dart';

/// A single line on a quote — either a service or a material — with
/// per-line overrides for rate / unit markup / discount / quantity.
///
/// `discount` is stored as a percentage (0 – 100).
class QuoteLineDraft {
  QuoteLineDraft({
    required this.id,
    required this.kind,
    required this.item,
    required this.rate,
    required this.unitMarkup,
    required this.discount,
    required this.quantity,
  });

  final String id;
  final PricingKind kind;
  final PricingItem item;
  final double rate;
  final double unitMarkup;
  final double discount;
  final int quantity;

  double get lineTotal {
    final base = (rate + unitMarkup) * quantity;
    final pct = discount.clamp(0, 100) / 100;
    final total = base * (1 - pct);
    return total < 0 ? 0 : total;
  }
}
