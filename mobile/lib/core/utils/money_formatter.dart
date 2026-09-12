class MoneyFormatter {
  MoneyFormatter._();

  static String format(int minorUnits, {String currencyCode = 'USD'}) {
    final major = minorUnits / 100;
    final symbol = _symbolFor(currencyCode);
    return '$symbol${major.toStringAsFixed(2)}';
  }

  static String _symbolFor(String code) {
    return switch (code.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'BIF' => 'FBu ',
      _ => '$code ',
    };
  }
}
