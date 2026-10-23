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
  return switch (period) {
    Period.today => DateTime(now.year, now.month, now.day),
    // Calendar arithmetic (the constructor rolls days over months), not
    // `subtract(Duration(days: n))`, which is off by an hour across a
    // daylight-saving change.
    Period.week => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
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
///
/// One pass with no copying or sorting, so it stays cheap with many readings;
/// [readings] may be in any order.
double? meteredKwh(Iterable<MeterReading> readings, DateTime from) {
  MeterReading? before; // latest reading taken before the period
  MeterReading? first; // earliest reading inside the period
  MeterReading? last; // latest reading inside the period
  for (final r in readings) {
    if (r.time.isBefore(from)) {
      if (before == null || r.time.isAfter(before.time)) before = r;
    } else {
      if (first == null || r.time.isBefore(first.time)) first = r;
      if (last == null || r.time.isAfter(last.time)) last = r;
    }
  }
  if (last == null) return null;
  final baseline = before ?? first!;
  if (identical(baseline, last)) return null;
  final used = last.kwh - baseline.kwh;
  return used < 0 ? null : used;
}

/// Picks the meter reading out of the text a photo scan recognised (which can
/// include stray digits from labels and serial numbers). Looks for numbers of
/// 3 to 9 digits; with a [last] reading to go by, takes the one closest to it,
/// otherwise one with a decimal part, then the longest. Null if nothing looks like a reading.
double? readingFromScan(String raw, {double? last}) {
  final candidates = <double>[];
  for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(raw)) {
    final text = m.group(0)!;
    final digits = text.replaceAll('.', '').length;
    if (digits < 3 || digits > 9) continue;
    final v = double.tryParse(text);
    if (v != null) candidates.add(v);
  }
  if (candidates.isEmpty) return null;
  if (last != null) {
    candidates.sort((a, b) => (a - last).abs().compareTo((b - last).abs()));
    return candidates.first;
  }
  // Meters show a decimal digit, and serial numbers don't: prefer those.
  candidates.sort((a, b) {
    final d = (b % 1 != 0 ? 1 : 0) - (a % 1 != 0 ? 1 : 0);
    return d != 0 ? d : b.toString().length.compareTo(a.toString().length);
  });
  return candidates.first;
}
