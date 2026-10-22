String formatKwh(double kwh) => '${kwh.toStringAsFixed(kwh < 10 ? 2 : 1)} kWh';

String formatMoney(String currency, double amount) =>
    '$currency${amount.toStringAsFixed(2)}';

String formatDateTime(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final suffix = t.hour < 12 ? 'AM' : 'PM';
  return '${months[t.month - 1]} ${t.day}, $hour:$minute $suffix';
}

/// Parses user input, accepting a comma as the decimal separator.
double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
