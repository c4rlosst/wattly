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

/// One bar of the usage chart.
class Bucket {
  const Bucket(this.label, this.kwh, {this.isCurrent = false});

  final String label;
  final double kwh;
  final bool isCurrent;
}

/// Estimated usage split into chart bars for [period]: four 6-hour blocks for
/// today, one bar per weekday for the week, one per week for the month.
List<Bucket> usageBuckets(
    Iterable<UsageEntry> entries, Period period, DateTime now) {
  final start = periodStart(period, now);
  final List<String> labels;
  final int current;
  final int Function(DateTime) indexOf;
  switch (period) {
    case Period.today:
      labels = const ['12a', '6a', '12p', '6p'];
      current = now.hour ~/ 6;
      indexOf = (t) => t.hour ~/ 6;
    case Period.week:
      labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      current = now.weekday - 1;
      indexOf = (t) => t.weekday - 1;
    case Period.month:
      final days = DateTime(now.year, now.month + 1, 0).day;
      labels = [for (var i = 1; i <= (days + 6) ~/ 7; i++) 'Wk $i'];
      current = (now.day - 1) ~/ 7;
      indexOf = (t) => (t.day - 1) ~/ 7;
  }
  final sums = List.filled(labels.length, 0.0);
  for (final e in entries) {
    if (e.time.isBefore(start)) continue;
    final i = indexOf(e.time);
    if (i >= 0 && i < sums.length) sums[i] += e.kwh;
  }
  return [
    for (var i = 0; i < labels.length; i++)
      Bucket(labels[i], sums[i], isCurrent: i == current),
  ];
}

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
