import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/calc.dart';
import 'package:wattly/main.dart';
import 'package:wattly/models.dart';
import 'package:wattly/store.dart';
import 'package:wattly/theme.dart';
import 'package:wattly/widgets.dart';

void main() {
  MeterReading reading(DateTime time, double kwh) =>
      MeterReading(id: '$time/$kwh', time: time, kwh: kwh);
  final now = DateTime(2026, 11, 4, 15);

  test(
    'meter increases appear on their reading dates without inventing days',
    () {
      final buckets = meterUsageBuckets(
        [
          reading(DateTime(2026, 11, 4, 9), 118),
          reading(DateTime(2026, 11, 1, 9), 100),
          reading(DateTime(2026, 11, 2, 9), 106),
          reading(DateTime(2026, 11, 5, 9), 999), // future
        ],
        Period.week,
        now,
      )!;
      expect(buckets.map((b) => b.kwh), [6, 0, 12, 0, 0, 0, 0]);
      expect(buckets.map((b) => b.hasData), [
        true,
        false,
        true,
        false,
        false,
        false,
        false,
      ]);
      expect(buckets[2].detailLabel, 'Wed, Nov 4');
      expect(buckets.fold<double>(0, (sum, b) => sum + b.kwh), 18);
    },
  );

  test(
    'today uses six-hour buckets, preserves zero readings, and ignores future',
    () {
      final buckets = meterUsageBuckets(
        [
          reading(DateTime(2026, 11, 3, 23), 100),
          reading(DateTime(2026, 11, 4, 5), 102),
          reading(DateTime(2026, 11, 4, 8), 102),
          reading(DateTime(2026, 11, 4, 14), 107),
          reading(DateTime(2026, 11, 4, 18), 200),
        ],
        Period.today,
        now,
      )!;
      expect(buckets.map((b) => b.kwh), [2, 0, 5, 0]);
      expect(buckets[1].hasData, isTrue);
      expect(buckets[3].hasData, isFalse);
    },
  );

  test('custom 31st cycle clamps February and exact boundary wins over older baseline', () {
    final buckets = meterUsageBuckets(
      [
        reading(DateTime(2027, 2, 25), 80),
        reading(DateTime(2027, 2, 28), 100),
        reading(DateTime(2027, 3, 2), 110),
        reading(DateTime(2027, 3, 8), 125),
        reading(DateTime(2027, 3, 16), 130),
      ],
      Period.month,
      DateTime(2027, 3, 20),
      resetDay: 31,
    )!;
    expect(buckets.map((b) => b.kwh), [10, 15, 5, 0, 0]);
    expect(buckets.first.detailLabel, 'Feb 28 – Mar 6');
    expect(buckets.last.detailLabel, 'Mar 28 – Mar 30');
    expect(buckets[2].isCurrent, isTrue);
  });

  test('insufficient readings and decreasing meters do not produce misleading bars', () {
    expect(meterUsageBuckets([], Period.week, now), isNull);
    expect(meterUsageBuckets([reading(now, 100)], Period.week, now), isNull);
    expect(
      meterUsageBuckets(
        [reading(now, 100), reading(now, 100)],
        Period.week,
        now,
      ),
      isNull,
    );
    expect(
      meterUsageBuckets(
        [reading(now, 100), reading(now, 101)],
        Period.week,
        now,
      ),
      isNull,
    );
    expect(
      meterUsageBuckets(
        [
          reading(DateTime(2026, 11, 2), 100),
          reading(DateTime(2026, 11, 3), 90),
          reading(now, 120),
        ],
        Period.week,
        now,
      ),
      isNull,
    );
  });

  testWidgets(
    'bars show relative usage and taps distinguish zero from no logs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: UsageBars(
                  buckets: const [
                    Bucket('M', 2, detailLabel: 'Monday'),
                    Bucket('T', 8, detailLabel: 'Tuesday'),
                    Bucket('W', 0, detailLabel: 'Wednesday'),
                    Bucket('T', 0, detailLabel: 'Thursday', hasData: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final short = tester.getSize(find.byKey(const Key('usage-bar-0'))).height;
      final tall = tester.getSize(find.byKey(const Key('usage-bar-1'))).height;
      expect(tall / short, closeTo(4, 0.001));
      await tester.tap(find.byKey(const Key('usage-bar-1')));
      await tester.pump();
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('8.00 kWh'), findsOneWidget);
      await tester.tap(find.byKey(const Key('usage-bar-2')));
      await tester.pump();
      expect(find.text('0.00 kWh'), findsOneWidget);
      await tester.tap(find.byKey(const Key('usage-bar-3')));
      await tester.pump();
      expect(find.text('No logs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'meter-only dashboard draws bars from the same source as its total',
    (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = WattlyStore(await SharedPreferences.getInstance());
      final time = DateTime.now();
      store.addReading(100, DateTime(time.year, time.month, time.day - 2));
      store.addReading(112, time.subtract(const Duration(minutes: 1)));
      await tester.pumpWidget(WattlyApp(store: store));
      final chart = tester.widget<UsageBars>(find.byType(UsageBars));
      expect(chart.buckets.fold<double>(0, (sum, b) => sum + b.kwh), 12);
      expect(find.text('12.0'), findsWidgets);
      expect(find.text('From meter readings'), findsOneWidget);
      expect(find.text('Increases grouped by reading date.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
