class Currency {
  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;
}

/// Code used when the student types their own symbol.
const customCurrencyCode = 'CUSTOM';

/// Common currencies; symbols that clash (several "$" currencies) use a short
/// prefix so a logged cost is unambiguous.
const currencies = [
  Currency('USD', '\$', 'US Dollar'),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('MXN', 'MX\$', 'Mexican Peso'),
  Currency('ARS', 'AR\$', 'Argentine Peso'),
  Currency('COP', 'COL\$', 'Colombian Peso'),
  Currency('CLP', 'CL\$', 'Chilean Peso'),
  Currency('DOP', 'RD\$', 'Dominican Peso'),
  Currency('CAD', 'C\$', 'Canadian Dollar'),
  Currency('AUD', 'A\$', 'Australian Dollar'),
  Currency('NZD', 'NZ\$', 'New Zealand Dollar'),
  Currency('SGD', 'S\$', 'Singapore Dollar'),
  Currency('HKD', 'HK\$', 'Hong Kong Dollar'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('CNY', 'CN¥', 'Chinese Yuan'),
  Currency('KRW', '₩', 'South Korean Won'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('IDR', 'Rp', 'Indonesian Rupiah'),
  Currency('MYR', 'RM', 'Malaysian Ringgit'),
  Currency('THB', '฿', 'Thai Baht'),
  Currency('VND', '₫', 'Vietnamese Dong'),
  Currency('BRL', 'R\$', 'Brazilian Real'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
];

Currency? currencyByCode(String code) {
  for (final c in currencies) {
    if (c.code == code) return c;
  }
  return null;
}

/// Best guess at which currency an older saved symbol meant.
Currency? currencyBySymbol(String symbol) {
  for (final c in currencies) {
    if (c.symbol == symbol) return c;
  }
  return null;
}
