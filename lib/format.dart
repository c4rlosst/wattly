/// The number alone, e.g. "3.20" or "118.4".
String formatKwhValue(double kwh) => kwh.toStringAsFixed(kwh < 10 ? 2 : 1);

String formatKwh(double kwh) => '${formatKwhValue(kwh)} kWh';

String formatMoney(String currency, double amount) =>
    '$currency${amount.toStringAsFixed(2)}';

/// A number without a pointless ".0": 8 not 8.0, but 1.5 stays 1.5. (Dart
/// prints doubles differently in the browser and elsewhere; this doesn't.)
String trimNumber(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

String formatDateTime(DateTime t) =>
    '${_months[t.month - 1]} ${t.day}, ${formatTime(t)}';

/// Whole days since 1970 for the calendar day of [t]; equal for any two times
/// on the same day, so it is a cheap way to tell days apart.
int dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

/// "Today", "Yesterday", or e.g. "Mon, Oct 20".
String dayLabel(DateTime day, DateTime now) {
  final diff = dayNumber(now) - dayNumber(day);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';
}

/// "Today, 9:41 AM" or "Oct 20, 9:41 AM".
String whenLabel(DateTime t, DateTime now) {
  final same = t.year == now.year && t.month == now.month && t.day == now.day;
  return same ? 'Today, ${formatTime(t)}' : formatDateTime(t);
}

/// Parses user input, accepting a comma as the decimal separator.
double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
