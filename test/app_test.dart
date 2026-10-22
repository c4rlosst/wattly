import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/main.dart';
import 'package:wattly/store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logging a device updates the dashboard', (tester) async {
    final store = WattlyStore(await SharedPreferences.getInstance());
    store.setRate(0.5);
    await tester.pumpWidget(WattlyApp(store: store));

    expect(find.text('0.00 kWh'), findsWidgets);

    await tester.tap(find.text('Log usage'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Device name'), 'Heater');
    await tester.enterText(find.widgetWithText(TextField, 'Watts'), '1500');
    await tester.enterText(find.widgetWithText(TextField, 'Hours used'), '2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('3.00 kWh'), findsWidgets);
    expect(find.text('≈ \$1.50'), findsOneWidget);
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
