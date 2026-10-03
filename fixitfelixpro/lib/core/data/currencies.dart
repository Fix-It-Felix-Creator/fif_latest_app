class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  static const gbp = Currency(code: 'GBP', symbol: '£', name: 'Pound Sterling');

  /// All supported currencies
  static const List<Currency> all = [gbp];

  /// Look up a currency by code, defaults to GBP
  static Currency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => gbp,
    );
  }
}
