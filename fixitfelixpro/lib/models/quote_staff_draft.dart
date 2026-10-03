import 'staff.dart';

/// A staff line on the quote — one entry per assigned staff member.
/// `rateType` records which labour rate (standard / weekend / emergency /
/// sociable) applies, so the customer quote shows exactly what they are
/// charged. `rate` is the per-unit amount for that method and `payType`
/// decides whether the quantity is days or hours.
class QuoteStaffDraft {
  QuoteStaffDraft({
    required this.id,
    required this.staff,
    required this.payType,
    required this.rateType,
    required this.rate,
    required this.quantity,
  });

  final String id;
  final Staff staff;
  final StaffPayType payType;
  final LabourRateType rateType;
  final double rate;
  final int quantity;

  double get lineTotal {
    final total = rate * quantity;
    return total < 0 ? 0 : total;
  }
}
