enum QuoteExpiry { days7, days14, days28, days90, none }

extension QuoteExpiryX on QuoteExpiry {
  String get label {
    switch (this) {
      case QuoteExpiry.days7:
        return '7 days';
      case QuoteExpiry.days14:
        return '14 days';
      case QuoteExpiry.days28:
        return '28 days';
      case QuoteExpiry.days90:
        return '90 days';
      case QuoteExpiry.none:
        return 'No expiry';
    }
  }

  String get wire => name;

  static QuoteExpiry fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'days7':
        return QuoteExpiry.days7;
      case 'days28':
        return QuoteExpiry.days28;
      case 'days90':
        return QuoteExpiry.days90;
      case 'none':
        return QuoteExpiry.none;
      default:
        return QuoteExpiry.days14;
    }
  }
}
