import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/logo.dart';
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

  testWidgets('the logo shows in the Usage header and in Settings',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    expect(find.byType(WattlyLogo), findsOneWidget);
    expect(find.text('Wattly'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(WattlyLogo), findsOneWidget);
    expect(find.text('Track your dorm’s electricity use.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing the peso changes the currency symbol', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    store.setRate(0.5);
    store.addUsage(
        label: 'Heater',
        watts: 1500,
        hours: 2,
        time: DateTime.now());
    await tester.pumpWidget(WattlyApp(store: store));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-PHP')));
    await tester.pumpAndSettle();

    expect(store.currency, '₱');
    expect(store.currencyCode, 'PHP');
    expect(find.text('Philippine Peso'), findsOneWidget);

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(find.text('≈ ₱1.50'), findsOneWidget);
  });

  test('currency choice is saved, and older saves keep their symbol', () async {
    final prefs = await SharedPreferences.getInstance();
    WattlyStore(prefs).setCurrency('₱', code: 'PHP');
    final reloaded = WattlyStore(prefs);
    expect(reloaded.currency, '₱');
    expect(reloaded.currencyCode, 'PHP');

    // Data written before the picker existed has a symbol but no code.
    SharedPreferences.setMockInitialValues({
      'wattly_v1': '{"rate":0.2,"currency":"€"}',
    });
    final legacy = WattlyStore(await SharedPreferences.getInstance());
    expect(legacy.currency, '€');
    expect(legacy.currencyCode, 'EUR');

    SharedPreferences.setMockInitialValues({
      'wattly_v1': '{"rate":0.2,"currency":"kr"}',
    });
    final custom = WattlyStore(await SharedPreferences.getInstance());
    expect(custom.currency, 'kr');
    expect(custom.currencyCode, 'CUSTOM');
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
