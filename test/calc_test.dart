import 'package:flutter_test/flutter_test.dart';
import 'package:wattly/calc.dart';
import 'package:wattly/models.dart';

void main() {
  test('watts and hours convert to kWh', () {
    expect(wattHoursToKwh(1000, 1), 1);
    expect(wattHoursToKwh(65, 8), closeTo(0.52, 1e-9));
  });

  test('usage entry cost uses the rate captured at log time', () {
    final e = UsageEntry(
      id: '1',
      time: DateTime(2026, 10, 1),
      label: 'Laptop',
      watts: 100,
      hours: 10,
      ratePerKwh: 0.2,
    );
    expect(e.kwh, 1);
    expect(e.cost, closeTo(0.2, 1e-9));
  });

  test('period starts', () {
    final wed = DateTime(2026, 10, 21, 15, 30); // a Wednesday
    expect(periodStart(Period.today, wed), DateTime(2026, 10, 21));
    expect(periodStart(Period.week, wed), DateTime(2026, 10, 19));
    expect(periodStart(Period.month, wed), DateTime(2026, 10, 1));
  });

  test('the week starts on Monday across month and year boundaries', () {
    // Friday 1 Jan 2027: the week began on Monday 28 Dec 2026.
    expect(periodStart(Period.week, DateTime(2027, 1, 1, 10)),
        DateTime(2026, 12, 28));
    // A Monday is its own week start.
    expect(periodStart(Period.week, DateTime(2026, 3, 2, 8)),
        DateTime(2026, 3, 2));
    // Sunday belongs to the week that began six days earlier.
    expect(periodStart(Period.week, DateTime(2026, 10, 25, 23, 59)),
        DateTime(2026, 10, 19));
    // Midnight exactly, not a stray hour (what a Duration subtraction can give
    // across a daylight-saving change).
    final start = periodStart(Period.week, DateTime(2026, 11, 4, 12));
    expect([start.hour, start.minute, start.second], [0, 0, 0]);
  });

  test('estimatedKwh only counts entries inside the period', () {
    UsageEntry at(DateTime t) => UsageEntry(
        id: t.toString(), time: t, label: 'x', watts: 1000, hours: 1, ratePerKwh: 0);
    final entries = [at(DateTime(2026, 9, 30)), at(DateTime(2026, 10, 5))];
    expect(estimatedKwh(entries, DateTime(2026, 10, 1)), 1);
  });

  group('usageBuckets', () {
    UsageEntry at(DateTime t, double kwh) => UsageEntry(
        id: t.toString(),
        time: t,
        label: 'x',
        watts: kwh * 1000,
        hours: 1,
        ratePerKwh: 0);
    final wed = DateTime(2026, 10, 21, 15, 30); // a Wednesday

    test('today splits into four 6-hour blocks', () {
      final b = usageBuckets(
          [at(DateTime(2026, 10, 21, 2), 1), at(DateTime(2026, 10, 21, 14), 2)],
          Period.today,
          wed);
      expect(b.map((x) => x.kwh), [1, 0, 2, 0]);
      expect(b.indexWhere((x) => x.isCurrent), 2);
    });

    test('week has one bar per weekday and ignores earlier weeks', () {
      final b = usageBuckets([
        at(DateTime(2026, 10, 19, 9), 1), // Monday
        at(DateTime(2026, 10, 21, 9), 3), // Wednesday
        at(DateTime(2026, 10, 18, 9), 9), // previous Sunday: excluded
      ], Period.week, wed);
      expect(b.length, 7);
      expect(b[0].kwh, 1);
      expect(b[2].kwh, 3);
      expect(b.fold<double>(0, (s, x) => s + x.kwh), 4);
      expect(b.indexWhere((x) => x.isCurrent), 2);
    });

    test('month has one bar per week of the month', () {
      final b = usageBuckets(
          [at(DateTime(2026, 10, 3), 1), at(DateTime(2026, 10, 21), 2)],
          Period.month,
          wed);
      expect(b.length, 5); // October has 31 days
      expect(b[0].kwh, 1);
      expect(b[2].kwh, 2);
      expect(b.indexWhere((x) => x.isCurrent), 2);
    });
  });

  group('meteredKwh', () {
    MeterReading r(DateTime t, double kwh) =>
        MeterReading(id: t.toString(), time: t, kwh: kwh);
    final from = DateTime(2026, 10, 1);

    test('null with no readings or a single reading in the period', () {
      expect(meteredKwh([], from), isNull);
      expect(meteredKwh([r(DateTime(2026, 10, 3), 100)], from), isNull);
    });

    test('difference between first and last reading in the period', () {
      final readings = [
        r(DateTime(2026, 10, 3), 100),
        r(DateTime(2026, 10, 9), 112.5),
      ];
      expect(meteredKwh(readings, from), 12.5);
    });

    test('uses the last reading before the period as the baseline', () {
      final readings = [
        r(DateTime(2026, 9, 20), 80),
        r(DateTime(2026, 9, 28), 95),
        r(DateTime(2026, 10, 9), 112.5),
      ];
      expect(meteredKwh(readings, from), 17.5);
    });

    test('gives the same answer whatever order the readings come in', () {
      final readings = [
        r(DateTime(2026, 9, 28), 95),
        r(DateTime(2026, 10, 9), 112.5),
        r(DateTime(2026, 10, 3), 100),
        r(DateTime(2026, 9, 20), 80),
      ];
      expect(meteredKwh(readings, from), 17.5);
      expect(meteredKwh(readings.reversed, from), 17.5);
    });

    test('null when the meter went backwards (typo or replaced meter)', () {
      final readings = [
        r(DateTime(2026, 10, 3), 100),
        r(DateTime(2026, 10, 9), 50),
      ];
      expect(meteredKwh(readings, from), isNull);
    });
  });
}
