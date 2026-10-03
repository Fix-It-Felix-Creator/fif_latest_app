/// How the customer is expected to settle this invoice. Stored on the
/// invoice doc and rendered on the PDF / send screen so the customer
/// knows where the money should go.
enum InvoicePaymentMethod { cash, bankDeposit }

extension InvoicePaymentMethodX on InvoicePaymentMethod {
  String get label {
    switch (this) {
      case InvoicePaymentMethod.cash:
        return 'Cash';
      case InvoicePaymentMethod.bankDeposit:
        return 'Bank deposit';
    }
  }

  String get wire => name;

  static InvoicePaymentMethod fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'bankdeposit':
        return InvoicePaymentMethod.bankDeposit;
      default:
        return InvoicePaymentMethod.cash;
    }
  }
}
