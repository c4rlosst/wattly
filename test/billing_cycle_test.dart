import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/calc.dart';
import 'package:wattly/format.dart';
import 'package:wattly/main.dart';
import 'package:wattly/models.dart';
import 'package:wattly/store.dart';

void main() {
  UsageEntry at(DateTime time, double kwh) => UsageEntry(
    id: time.toString(),
    time: time,
    label: 'Fan',
    watts: kwh * 1000,
    hours: 1,
    ratePerKwh: 2,
  );

  test('cycle switches exactly at midnight on the chosen day', () {
    expect(
      billingCycleStart(DateTime(2026, 11, 14, 23, 59, 59), 15),
      DateTime(2026, 10, 15),
    );
    expect(
      billingCycleStart(DateTime(2026, 11, 15), 15),
      DateTime(2026, 11, 15),
    );
    expect(billingCycleStart(DateTime(2027, 1, 4), 15), DateTime(2026, 12, 15));
    expect(
      periodStart(Period.today, DateTime(2026, 11, 14), resetDay: 15),
      DateTime(2026, 11, 14),
    );
    expect(
      periodStart(Period.week, DateTime(2026, 11, 14), resetDay: 15),
      DateTime(2026, 11, 9),
    );
  });

  test('29th to 31st clamp in short months, then return to chosen day', () {
    for (final day in [29, 30, 31]) {
      expect(
        billingCycleStart(DateTime(2027, 2, 28), day),
        DateTime(2027, 2, 28),
      );
      expect(
        billingCycleStart(DateTime(2027, 3, day - 1), day),
        DateTime(2027, 2, 28),
      );
      expect(
        billingCycleStart(DateTime(2027, 3, day), day),
        DateTime(2027, 3, day),
      );
    }
    expect(billingCycleStart(DateTime(2028, 2, 28), 31), DateTime(2028, 1, 31));
    expect(billingCycleStart(DateTime(2028, 2, 29), 31), DateTime(2028, 2, 29));
    expect(billingCycleStart(DateTime(2026, 4, 30), 31), DateTime(2026, 4, 30));
    expect(() => billingCycleStart(DateTime(2026), 0), throwsRangeError);
    expect(() => billingCycleStart(DateTime(2026), 32), throwsRangeError);
  });

  test('every cycle contains now and ends at the next monthly boundary', () {
    for (final year in [2027, 2028]) {
      for (var month = 1; month <= 12; month++) {
        for (var day = 1; day <= DateTime(year, month + 1, 0).day; day++) {
          for (var reset = 1; reset <= 31; reset++) {
            final now = DateTime(year, month, day, 12);
            final start = billingCycleStart(now, reset);
            final end = billingCycleEnd(start, reset);
            expect(start.isAfter(now), isFalse);
            expect(end.isAfter(now), isTrue);
            expect(billingCycleStart(end, reset), end);
          }
        }
      }
    }
  });

  test('chart and totals use the same cycle across months', () {
    final now = DateTime(2026, 11, 10, 12);
    final start = periodStart(Period.month, now, resetDay: 15);
    final entries = [
      at(DateTime(2026, 10, 14, 23, 59), 10), // excluded
      at(DateTime(2026, 10, 15), 1),
      at(DateTime(2026, 10, 22), 2),
      at(DateTime(2026, 11, 5), 3),
    ];
    final bars = usageBuckets(entries, Period.month, now, resetDay: 15);
    expect(bars.map((b) => b.kwh), [1, 2, 0, 3, 0]);
    expect(bars.indexWhere((b) => b.isCurrent), 3);
    expect(estimatedKwh(entries, start), 6);
    expect(estimatedCost(entries, start), 12);
    final readings = [
      MeterReading(id: 'a', time: start, kwh: 100),
      MeterReading(id: 'b', time: now, kwh: 106),
    ];
    expect(meteredKwh(readings, start), 6);
    expect(
      usageBuckets(
        [...entries, at(DateTime(2026, 12, 1), 99)],
        Period.month,
        now,
        resetDay: 15,
      ).map((b) => b.kwh),
      bars.map((b) => b.kwh),
    );
  });

  test('31st reset produces four calendar weeks for February', () {
    final bars = usageBuckets(
      [],
      Period.month,
      DateTime(2027, 3, 20),
      resetDay: 31,
    );
    // Feb 28 through Mar 30 is 31 days: five bars.
    expect(bars.length, 5);
    expect(bars.indexWhere((b) => b.isCurrent), 2);
    expect(
      usageBuckets(
        [],
        Period.month,
        DateTime(2027, 2, 15),
        resetDay: 31,
      ).length,
      4,
    );
  });

  test('cycle labels include years across New Year', () {
    expect(
      cycleDateRange(DateTime(2026, 12, 15), DateTime(2027, 1, 15)),
      'Dec 15, 2026 – Jan 14, 2027',
    );
    expect([1, 2, 3, 11, 12, 13, 21, 31].map(ordinalDay), [
      '1st',
      '2nd',
      '3rd',
      '11th',
      '12th',
      '13th',
      '21st',
      '31st',
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reset preference persists and changing it keeps all history', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = WattlyStore(prefs);
    expect(store.monthlyResetDay, 1);
    store.addUsage(label: 'Fan', watts: 40, hours: 1, time: DateTime.now());
    store.addReading(100, DateTime.now());
    final revision = store.revision;
    store.setMonthlyResetDay(31);
    expect(store.revision, greaterThan(revision));
    final restored = WattlyStore(prefs);
    expect(restored.monthlyResetDay, 31);
    expect(restored.entries.length, 1);
    expect(restored.readings.length, 1);
    expect(() => store.setMonthlyResetDay(0), throwsRangeError);
    expect(() => store.setMonthlyResetDay(32), throwsRangeError);
  });

  test('legacy or invalid saved settings default safely to the 1st', () async {
    for (final value in [null, 0, 32, '15', 15.5]) {
      SharedPreferences.setMockInitialValues({
        'wattly_v1': jsonEncode({'monthlyResetDay': value, 'rate': 12.5}),
      });
      final store = WattlyStore(await SharedPreferences.getInstance());
      expect(store.monthlyResetDay, 1);
      expect(store.ratePerKwh, 12.5);
    }
  });

  testWidgets(
    'pick a reset day, cancel another choice, and see the cycle on Usage',
    (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      final store = WattlyStore(prefs);
      await tester.pumpWidget(WattlyApp(store: store));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly-reset-row')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('reset-day-1')))
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('reset-day-15')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('reset-day-15')))
            .properties
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('reset-day-1')))
            .properties
            .selected,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('reset-day-save')));
      await tester.pumpAndSettle();
      expect(store.monthlyResetDay, 15);
      expect(WattlyStore(prefs).monthlyResetDay, 15);
      expect(find.text('15th'), findsOneWidget);
      await tester.tap(find.byKey(const Key('monthly-reset-row')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('reset-day-15')))
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('reset-day-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.monthlyResetDay, 15);
      await tester.tap(find.text('Usage'));
      await tester.pumpAndSettle();
      expect(find.text('THIS CYCLE'), findsOneWidget);
      final start = billingCycleStart(DateTime.now(), 15);
      expect(
        find.text(cycleDateRange(start, billingCycleEnd(start, 15))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
