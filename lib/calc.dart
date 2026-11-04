import 'format.dart';
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
DateTime periodStart(Period period, DateTime now, {int resetDay = 1}) {
  return switch (period) {
    Period.today => DateTime(now.year, now.month, now.day),
    // Calendar arithmetic (the constructor rolls days over months), not
    // `subtract(Duration(days: n))`, which is off by an hour across a
    // daylight-saving change.
    Period.week => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
    Period.month => billingCycleStart(now, resetDay),
  };
}

/// A monthly boundary, clamped to the last day in shorter months.
DateTime billingBoundary(int year, int month, int resetDay) {
  RangeError.checkValueInInterval(resetDay, 1, 31, 'resetDay');
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, resetDay > lastDay ? lastDay : resetDay);
}

DateTime billingCycleStart(DateTime now, int resetDay) {
  final boundary = billingBoundary(now.year, now.month, resetDay);
  return now.isBefore(boundary)
      ? billingBoundary(now.year, now.month - 1, resetDay)
      : boundary;
}

DateTime billingCycleEnd(DateTime start, int resetDay) =>
    billingBoundary(start.year, start.month + 1, resetDay);

// Count calendar days, not elapsed hours (which change across DST).
int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

double wattHoursToKwh(double watts, double hours) => watts * hours / 1000;

/// One bar of the usage chart.
class Bucket {
  const Bucket(
    this.label,
    this.kwh, {
    this.isCurrent = false,
    this.hasData = true,
    this.detailLabel,
  });

  final String label;
  final double kwh;
  final bool isCurrent;
  final bool hasData;
  final String? detailLabel;
}

/// Shared boundaries for device logs and meter increases.
class _ChartPeriod {
  _ChartPeriod(this.period, this.now, int resetDay)
    : start = periodStart(period, now, resetDay: resetDay) {
    final end = billingCycleEnd(start, resetDay);
    labels = switch (period) {
      Period.today => const ['12a', '6a', '12p', '6p'],
      Period.week => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      Period.month => [
        for (var i = 1; i <= (_calendarDays(start, end) + 6) ~/ 7; i++) 'Wk $i',
      ],
    };
    details = [
      for (var i = 0; i < labels.length; i++)
        switch (period) {
          Period.today => const [
            '12 AM – 6 AM',
            '6 AM – 12 PM',
            '12 PM – 6 PM',
            '6 PM – 12 AM',
          ][i],
          Period.week => dayLabel(
            DateTime(start.year, start.month, start.day + i),
            DateTime(0),
          ),
          Period.month => cycleDateRange(
            DateTime(start.year, start.month, start.day + i * 7),
            DateTime(
                  start.year,
                  start.month,
                  start.day + (i + 1) * 7,
                ).isAfter(end)
                ? end
                : DateTime(start.year, start.month, start.day + (i + 1) * 7),
          ),
        },
    ];
  }

  final Period period;
  final DateTime now;
  final DateTime start;
  late final List<String> labels;
  late final List<String> details;

  int indexOf(DateTime time) => switch (period) {
    Period.today => time.hour ~/ 6,
    Period.week => time.weekday - 1,
    Period.month => _calendarDays(start, time) ~/ 7,
  };

  List<Bucket> buckets(List<double> sums, List<bool> logged) => [
    for (var i = 0; i < labels.length; i++)
      Bucket(
        labels[i],
        sums[i],
        isCurrent: i == indexOf(now),
        hasData: logged[i],
        detailLabel: details[i],
      ),
  ];
}

/// Estimated usage split into chart bars for [period]: four 6-hour blocks for
/// today, one bar per weekday for the week, one per week for the month.
List<Bucket> usageBuckets(
  Iterable<UsageEntry> entries,
  Period period,
  DateTime now, {
  int resetDay = 1,
}) {
  final chart = _ChartPeriod(period, now, resetDay);
  final sums = List.filled(chart.labels.length, 0.0);
  final logged = List.filled(sums.length, false);
  for (final e in entries) {
    if (e.time.isBefore(chart.start) || e.time.isAfter(now)) continue;
    final i = chart.indexOf(e.time);
    if (i >= 0 && i < sums.length) {
      sums[i] += e.kwh;
      logged[i] = true;
    }
  }
  return chart.buckets(sums, logged);
}

/// Meter increases grouped by the date the later reading was logged. We do not
/// invent daily consumption between readings. Like the dashboard total, use the
/// last reading before the period as the baseline unless one exists at its start.
/// Null means there is no valid pair (or the meter decreased).
List<Bucket>? meterUsageBuckets(
  Iterable<MeterReading> readings,
  Period period,
  DateTime now, {
  int resetDay = 1,
}) {
  final chart = _ChartPeriod(period, now, resetDay);
  MeterReading? before;
  final inside = <MeterReading>[];
  for (final reading in readings) {
    if (reading.time.isAfter(now)) continue;
    if (reading.time.isBefore(chart.start)) {
      if (before == null || reading.time.isAfter(before.time)) before = reading;
    } else {
      inside.add(reading);
    }
  }
  inside.sort((a, b) => a.time.compareTo(b.time));
  if (inside.isEmpty) return null;
  var previous = inside.first.time == chart.start
      ? inside.first
      : before ?? inside.first;
  final sums = List.filled(chart.labels.length, 0.0);
  final logged = List.filled(sums.length, false);
  var hasPair = false;
  for (final reading in inside) {
    if (identical(reading, previous)) continue;
    // Two values at the same instant cannot describe a consumption interval.
    if (reading.time == previous.time) {
      if (reading.kwh != previous.kwh) return null;
      continue;
    }
    final delta = reading.kwh - previous.kwh;
    if (delta < 0) return null;
    final index = chart.indexOf(reading.time);
    sums[index] += delta;
    logged[index] = true;
    hasPair = true;
    previous = reading;
  }
  return hasPair ? chart.buckets(sums, logged) : null;
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
  // A reading exactly at the boundary is the best baseline. Choosing an older
  // reading would also count consumption from the previous cycle.
  final baseline = first!.time == from ? first : before ?? first;
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
