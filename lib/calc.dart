import 'models.dart';

enum Period { today, week, month }

extension PeriodLabel on Period {
  String get label => switch (this) {
        Period.today => 'Today',
        Period.week => 'This week',
        Period.month => 'This month',
      };
}

/// Start of [period] relative to [now]. Weeks start on Monday.
DateTime periodStart(Period period, DateTime now) {
  final midnight = DateTime(now.year, now.month, now.day);
  return switch (period) {
    Period.today => midnight,
    Period.week => midnight.subtract(Duration(days: now.weekday - 1)),
    Period.month => DateTime(now.year, now.month),
  };
}

double wattHoursToKwh(double watts, double hours) => watts * hours / 1000;

/// Sum of estimated usage logged at or after [from].
double estimatedKwh(Iterable<UsageEntry> entries, DateTime from) => entries
    .where((e) => !e.time.isBefore(from))
    .fold(0.0, (sum, e) => sum + e.kwh);

double estimatedCost(Iterable<UsageEntry> entries, DateTime from) => entries
    .where((e) => !e.time.isBefore(from))
    .fold(0.0, (sum, e) => sum + e.cost);

/// kWh consumed according to meter readings from [from] until now.
///
/// The baseline is the last reading taken before [from], or the first reading
/// inside the period when there is none. Returns null when there isn't enough
/// data to measure a difference.
double? meteredKwh(Iterable<MeterReading> readings, DateTime from) {
  final sorted = readings.toList()..sort((a, b) => a.time.compareTo(b.time));
  final before = sorted.where((r) => r.time.isBefore(from)).toList();
  final inside = sorted.where((r) => !r.time.isBefore(from)).toList();
  if (inside.isEmpty) return null;
  final baseline = before.isNotEmpty ? before.last : inside.first;
  final used = inside.last.kwh - baseline.kwh;
  if (identical(baseline, inside.last)) return null;
  return used < 0 ? null : used;
}
