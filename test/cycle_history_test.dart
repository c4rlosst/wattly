import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/calc.dart';
import 'package:wattly/cycle_history.dart';
import 'package:wattly/format.dart';
import 'package:wattly/main.dart';
import 'package:wattly/models.dart';
import 'package:wattly/store.dart';

UsageEntry entry(DateTime time, double kwh, {double rate = 10}) => UsageEntry(
  id: time.toString(),
  time: time,
  label: 'Heater',
  watts: kwh * 1000,
  hours: 1,
  ratePerKwh: rate,
);
MeterReading reading(DateTime time, double kwh) =>
    MeterReading(id: time.toString(), time: time, kwh: kwh);

void main() {
  test('full cycles share boundary readings without double-counting usage', () {
    final cycles = cycleHistory(
      [],
      [
        reading(DateTime(2027, 1, 31), 100),
        reading(DateTime(2027, 2, 28), 140),
        reading(DateTime(2027, 3, 31), 190),
      ],
      DateTime(2027, 4, 2),
      resetDay: 31,
    );
    expect(cycles.length, 3);
    expect(cycles[0].isCurrent, isTrue);
    expect(cycles[0].kwh, isNull);
    expect(cycles[1].meteredKwh, 50);
    expect(cycles[2].meteredKwh, 40);
    expect(cycles[1].fullMeterCoverage, isTrue);
    expect(cycles[2].fullMeterCoverage, isTrue);
    expect(cycles[1].differenceFrom(cycles[2]), 10);
    expect(cycles[1].cost(15), 750);
    expect(cycles[1].cost(0), isNull);
    expect(
      meteredKwh([
        reading(DateTime(2027, 1, 31), 100),
        reading(DateTime(2027, 2, 28), 140),
        reading(DateTime(2027, 3, 31), 190),
      ], DateTime(2027, 2, 28)),
      50,
    );
  });

  test('old cycles exclude newer entries and use saved device rates', () {
    final cycles = cycleHistory(
      [
        entry(DateTime(2026, 12, 14), 1, rate: 2),
        entry(DateTime(2026, 12, 15), 3, rate: 5),
        entry(DateTime(2027, 1, 14, 23, 59), 2, rate: 10),
        entry(DateTime(2027, 1, 15), 9),
      ],
      [],
      DateTime(2027, 1, 20),
      resetDay: 15,
    );
    expect(cycles.map((c) => c.estimatedKwh), [9, 5, 1]);
    expect(cycles[1].cost(999), 35);
    expect(cycles[1].differenceFrom(cycles[2]), 4);
    expect(cycles.first.differenceFrom(cycles[1]), isNull);
  });

  test(
    'missing cycles are unknown, not zero, and meter gaps are not assigned',
    () {
      final cycles = cycleHistory(
        [],
        [
          reading(DateTime(2027, 1, 20), 100),
          reading(DateTime(2027, 3, 20), 250),
        ],
        DateTime(2027, 3, 25),
        resetDay: 15,
      );
      expect(cycles.length, 3);
      expect(cycles.map((c) => c.kwh), [null, null, null]);
      expect(cycles[1].readings, isEmpty);
    },
  );

  test('partial meter coverage remains explicit and cannot be compared', () {
    final cycles = cycleHistory(
      [],
      [
        reading(DateTime(2027, 1, 16), 100),
        reading(DateTime(2027, 1, 25), 110),
        reading(DateTime(2027, 2, 15), 120),
        reading(DateTime(2027, 3, 15), 150),
      ],
      DateTime(2027, 3, 20),
      resetDay: 15,
    );
    expect(cycles[2].meteredKwh, 20);
    expect(cycles[2].fullMeterCoverage, isFalse);
    expect(cycles[1].fullMeterCoverage, isTrue);
    expect(cycles[1].differenceFrom(cycles[2]), isNull);
  });

  test('a meter replacement cannot be hidden by a later higher reading', () {
    final cycles = cycleHistory(
      [entry(DateTime(2027, 1, 20), 2)],
      [
        reading(DateTime(2027, 1, 15), 100),
        reading(DateTime(2027, 1, 20), 50),
        reading(DateTime(2027, 2, 15), 120),
      ],
      DateTime(2027, 2, 20),
      resetDay: 15,
    );
    expect(cycles.last.meterDecreased, isTrue);
    expect(cycles.last.meteredKwh, isNull);
    expect(cycles.last.usesMeter, isFalse);
    expect(cycles.last.kwh, 2);
  });

  test('future data is excluded and a zero-usage cycle is still valid', () {
    final cycles = cycleHistory(
      [entry(DateTime(2028, 1, 1), 999)],
      [
        reading(DateTime(2027, 1, 1), 100),
        reading(DateTime(2027, 2, 1), 100),
        reading(DateTime(2028, 1, 1), 900),
      ],
      DateTime(2027, 2, 5),
      resetDay: 1,
    );
    expect(cycles.length, 2);
    expect(cycles.last.kwh, 0);
    expect(cycles.last.fullMeterCoverage, isTrue);
    expect(cycles.last.cost(10), 0);
  });

  test(
    'sorting is independent of input order and reset changes regroup data',
    () {
      final entries = [
        entry(DateTime(2027, 1, 30), 2),
        entry(DateTime(2027, 2, 5), 3),
      ];
      final now = DateTime(2027, 2, 20);
      expect(cycleHistory(entries, [], now, resetDay: 1).map((c) => c.kwh), [
        3,
        2,
      ]);
      expect(
        cycleHistory(entries.reversed, [], now, resetDay: 15).map((c) => c.kwh),
        [null, 5],
      );
      expect(cycleHistory([], [], now, resetDay: 15), isEmpty);
      expect(entries.length, 2);
    },
  );

  testWidgets('open Cycles from History, view older cycle and navigate back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = WattlyStore(await SharedPreferences.getInstance())
      ..setMonthlyResetDay(15);
    final current = billingCycleStart(DateTime.now(), 15);
    final previous = billingBoundary(current.year, current.month - 1, 15);
    store.addUsage(label: 'Fan', watts: 1000, hours: 2, time: previous);
    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cycle-history')));
    await tester.pumpAndSettle();
    expect(find.text('Current cycle · In progress'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(cycleDateRange(previous, current, showYear: true)),
      findsOneWidget,
    );
    expect(find.text('2.00 kWh'), findsOneWidget);
    expect(find.text('Device estimate'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cycle-history')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cycle history explains how to start', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cycle-history')));
    await tester.pumpAndSettle();
    expect(find.text('No cycles yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
