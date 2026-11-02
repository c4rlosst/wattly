import 'calc.dart';
import 'models.dart';

/// A cycle is [start, end): a reading exactly at end closes this cycle and
/// starts the next. We never pull in readings outside those boundaries or
/// interpolate missing readings, which would invent usage across cycles.
class CycleSummary {
  CycleSummary({
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.entries,
    required this.readings,
  });

  final DateTime start;
  final DateTime end;
  final bool isCurrent;
  final List<UsageEntry> entries;
  final List<MeterReading> readings;

  double get estimatedKwh => entries.fold(0.0, (sum, e) => sum + e.kwh);
  double get estimatedCost => entries.fold(0.0, (sum, e) => sum + e.cost);
  bool get meterDecreased {
    for (var i = 1; i < readings.length; i++) {
      if (readings[i].kwh < readings[i - 1].kwh) return true;
    }
    return false;
  }

  double? get meteredKwh => readings.length < 2 || meterDecreased
      ? null
      : readings.last.kwh - readings.first.kwh;

  bool get usesMeter => meteredKwh != null;
  bool get fullMeterCoverage =>
      usesMeter && readings.first.time == start && readings.last.time == end;
  double? get kwh => meteredKwh ?? (entries.isEmpty ? null : estimatedKwh);

  // Old device logs keep their recorded rates. Meter readings do not have
  // historical rates, so their cost is explicitly a current-rate estimate.
  double? cost(double currentRate) => usesMeter
      ? (currentRate > 0 ? meteredKwh! * currentRate : null)
      : (entries.isEmpty ? null : estimatedCost);

  /// Compare only finished, adjacent cycles measured the same way. A partial
  /// meter interval is not comparable to a full cycle or device estimate.
  double? differenceFrom(CycleSummary previous) {
    if (isCurrent ||
        previous.end != start ||
        kwh == null ||
        previous.kwh == null ||
        usesMeter != previous.usesMeter) {
      return null;
    }
    if (usesMeter && (!fullMeterCoverage || !previous.fullMeterCoverage)) {
      return null;
    }
    return kwh! - previous.kwh!;
  }
}

List<CycleSummary> cycleHistory(
  Iterable<UsageEntry> entries,
  Iterable<MeterReading> readings,
  DateTime now, {
  required int resetDay,
}) {
  final current = billingCycleStart(now, resetDay);
  var earliest = current;
  final usageByStart = <DateTime, List<UsageEntry>>{};
  final readingsByStart = <DateTime, List<MeterReading>>{};
  for (final entry in entries) {
    if (entry.time.isAfter(now)) continue;
    final start = billingCycleStart(entry.time, resetDay);
    if (start.isBefore(earliest)) earliest = start;
    usageByStart.putIfAbsent(start, () => []).add(entry);
  }
  final sorted = readings.where((r) => !r.time.isAfter(now)).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  for (final reading in sorted) {
    final start = billingCycleStart(reading.time, resetDay);
    if (start.isBefore(earliest)) earliest = start;
    readingsByStart.putIfAbsent(start, () => []).add(reading);
  }
  if (usageByStart.isEmpty && readingsByStart.isEmpty) return [];

  final cycles = <CycleSummary>[];
  for (var start = earliest; !start.isAfter(current);) {
    final end = billingCycleEnd(start, resetDay);
    final cycleReadings = [...?readingsByStart[start]];
    // Boundary readings are intentionally shared as adjacent endpoints.
    final next = readingsByStart[end];
    if (next != null && next.first.time == end) cycleReadings.add(next.first);
    cycles.add(
      CycleSummary(
        start: start,
        end: end,
        isCurrent: start == current,
        entries: usageByStart[start] ?? const [],
        readings: cycleReadings,
      ),
    );
    start = end;
  }
  return cycles.reversed.toList();
}
