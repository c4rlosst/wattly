import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/main.dart';
import 'package:wattly/store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logging a device updates the dashboard', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    store.setRate(0.5);
    await tester.pumpWidget(WattlyApp(store: store));

    expect(find.text('0.00'), findsWidgets);

    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Heater');
    await tester.enterText(find.byKey(const Key('watts')), '1500');
    await tester.enterText(find.byKey(const Key('hours')), '2');
    await tester.pump();
    expect(find.text('3.00'), findsOneWidget); // live preview in the sheet

    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('3.00'), findsWidgets);
    expect(find.text('≈ \$1.50'), findsOneWidget);
  });

  testWidgets('tabs switch between usage, history and settings',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Price per kWh'), findsOneWidget);
  });

  test('data survives a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = WattlyStore(prefs)
      ..setRate(0.25)
      ..addAppliance('Fan', 40)
      ..addReading(123.4, DateTime(2026, 10, 1));

    final second = WattlyStore(prefs);
    expect(second.ratePerKwh, 0.25);
    expect(second.appliances.single.name, 'Fan');
    expect(second.readings.single.kwh, 123.4);
    first.dispose();
    second.dispose();
  });
}
