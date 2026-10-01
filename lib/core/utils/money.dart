/// Formats [amount] with the symbol of [currency] ($, €, £) or its ISO code.
String formatMoney(double amount, String currency) {
  return '${currencySymbol(currency)}${amount.toStringAsFixed(2)}';
}

String currencySymbol(String currency) {
  return switch (currency) {
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currency ',
  };
}
