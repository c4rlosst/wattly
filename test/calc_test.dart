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

  test('estimatedKwh only counts entries inside the period', () {
    UsageEntry at(DateTime t) => UsageEntry(
        id: t.toString(), time: t, label: 'x', watts: 1000, hours: 1, ratePerKwh: 0);
    final entries = [at(DateTime(2026, 9, 30)), at(DateTime(2026, 10, 5))];
    expect(estimatedKwh(entries, DateTime(2026, 10, 1)), 1);
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

    test('null when the meter went backwards (typo or replaced meter)', () {
      final readings = [
        r(DateTime(2026, 10, 3), 100),
        r(DateTime(2026, 10, 9), 50),
      ];
      expect(meteredKwh(readings, from), isNull);
    });
  });
}
