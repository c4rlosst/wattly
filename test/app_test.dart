import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/logo.dart';
import 'package:wattly/main.dart';
import 'package:wattly/store.dart';
import 'package:wattly/widgets.dart';

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

  testWidgets('on a wide screen the app is a centered phone-width column',
      (tester) async {
    tester.view.physicalSize = const Size(2800, 1800); // 1400 x 900 logical
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    final page = find.byType(Scaffold).first;
    expect(tester.getSize(page).width, PhoneColumn.maxWidth);
    expect(tester.getSize(page).height, 900);
    expect(tester.getTopLeft(page).dx, (1400 - PhoneColumn.maxWidth) / 2);

    // Inside the column the app is phone-sized and portrait, even though the
    // window is landscape, so the large iOS titles still expand.
    final inside = MediaQuery.of(tester.element(page));
    expect(inside.size.width, PhoneColumn.maxWidth);
    expect(inside.orientation, Orientation.portrait);

    // Sheets stay inside the column as well.
    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byType(BottomSheet)).width, PhoneColumn.maxWidth);
  });

  testWidgets('on a phone the app uses the full width', (tester) async {
    tester.view.physicalSize = const Size(780, 1688); // 390 x 844 logical
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    final page = find.byType(Scaffold).first;
    expect(tester.getSize(page).width, 390);
    expect(tester.getTopLeft(page).dx, 0);
  });

  testWidgets('the app is light even when the device is in dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));
    Brightness shown() =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
    expect(shown(), Brightness.light);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.appearance, Appearance.dark);
    expect(shown(), Brightness.dark);

    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(store.appearance, Appearance.system);
    expect(shown(), Brightness.dark); // follows the device, which is dark

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(store.appearance, Appearance.light);
    expect(shown(), Brightness.light);
  });

  test('appearance defaults to light and is saved', () async {
    SharedPreferences.setMockInitialValues({
      'wattly_v1': '{"rate":0.2,"currency":"\$"}', // saved before the setting
    });
    final prefs = await SharedPreferences.getInstance();
    final first = WattlyStore(prefs);
    expect(first.appearance, Appearance.light);

    first.setAppearance(Appearance.dark);
    expect(WattlyStore(prefs).appearance, Appearance.dark);
    first.dispose();
  });

  testWidgets('tapping Save twice quickly logs the entry only once',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Heater');
    await tester.enterText(find.byKey(const Key('watts')), '1500');
    await tester.enterText(find.byKey(const Key('hours')), '2');
    await tester.pump();

    // Two taps before the sheet has finished sliding away.
    await tester.tap(find.byKey(const Key('save')));
    await tester.tap(find.byKey(const Key('save')), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(store.entries.length, 1);
  });

  testWidgets('the Usage tab remembers its choices when you switch tabs',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsNothing);
  });

  testWidgets('a hidden tab catches up with changes made while it was hidden',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    // Open Settings and History once, then go back to Usage.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet'), findsOneWidget);
    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();

    // Change things from the Usage tab.
    store.addUsage(
        label: 'Desk fan', watts: 40, hours: 3, time: DateTime.now());
    store.setCurrency('₱', code: 'PHP');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Desk fan'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Philippine Peso'), findsOneWidget);
  });

  testWidgets('a price typed in Settings shows up on Usage and is saved',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    // Two meter readings 10 kWh apart: their cost uses the *current* price.
    final store = WattlyStore(prefs)
      ..addReading(100, DateTime.now().subtract(const Duration(hours: 2)))
      ..addReading(110, DateTime.now());
    await tester.pumpWidget(WattlyApp(store: store));
    expect(find.text('Set your rate in Settings to see cost'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rate')), '2.5');
    await tester.pump();
    expect(store.ratePerKwh, 2.5);

    // Leaving the field (here: by changing tab) saves it...
    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(jsonDecode(prefs.getString('wattly_v1')!)['rate'], 2.5);
    // ...and the Usage tab, built before the price existed, caught up.
    expect(find.text('Set your rate in Settings to see cost'), findsNothing);
    expect(find.text('≈ \$25.00'), findsOneWidget); // 10 kWh x 2.5
  });

  testWidgets('tapping a row\'s label focuses its field', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();

    bool hasFocus(String key) => tester
        .widget<TextField>(find.descendant(
            of: find.byKey(Key(key)), matching: find.byType(TextField)))
        .focusNode!
        .hasFocus;

    await tester.tap(find.text('Power (W)'));
    await tester.pump();
    expect(hasFocus('watts'), isTrue);

    await tester.tap(find.text('Hours used'));
    await tester.pump();
    expect(hasFocus('hours'), isTrue);
    expect(hasFocus('watts'), isFalse);
  });

  testWidgets('"Save for next time" does not create duplicate devices',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance())
      ..addAppliance('Laptop', 65);
    await tester.pumpWidget(WattlyApp(store: store));

    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'laptop'); // same device
    await tester.enterText(find.byKey(const Key('watts')), '65');
    await tester.enterText(find.byKey(const Key('hours')), '3');
    await tester.pump();
    await tester.tap(find.byType(CupertinoSwitch)); // Save for next time
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(store.entries.length, 1);
    expect(store.appliances.length, 1); // still just the one Laptop
  });

  testWidgets('a meter reading lower than the last one gets a warning',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final store = WattlyStore(await SharedPreferences.getInstance())
      ..addReading(4821.6, DateTime(2026, 10, 1));
    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.byKey(const Key('add-usage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meter reading'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reading')), '4900');
    await tester.pump();
    expect(find.textContaining('lower than your last reading'), findsNothing);

    await tester.enterText(find.byKey(const Key('reading')), '4800');
    await tester.pump();
    expect(find.textContaining('lower than your last reading'), findsOneWidget);
  });

  testWidgets('history only builds the days that are on screen',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'wattly_v1': jsonEncode({
        'rate': 0.15,
        'entries': [
          for (var i = 0; i < 3000; i++)
            {
              'id': 'e$i',
              'time': now.subtract(Duration(hours: i * 3)).toIso8601String(),
              'label': 'Device ${i % 12}',
              'watts': 60.0,
              'hours': 2.0,
              'rate': 0.15,
            },
        ],
      }),
    });
    final store = WattlyStore(await SharedPreferences.getInstance());
    expect(store.entries.length, 3000);

    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    final rows = find.byType(Dismissible, skipOffstage: false).evaluate().length;
    expect(rows, greaterThan(0));
    expect(rows, lessThan(60));
  });

  testWidgets('a new entry is brought into view even if History was scrolled',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'wattly_v1': jsonEncode({
        'entries': [
          for (var i = 0; i < 200; i++)
            {
              'id': 'e$i',
              'time': now.subtract(Duration(days: i + 1)).toIso8601String(),
              'label': 'Old $i',
              'watts': 60.0,
              'hours': 2.0,
              'rate': 0.15,
            },
        ],
      }),
    });
    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Scroll far down, then log something new.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Old 0'), findsNothing); // the top of the list is off screen

    store.addUsage(label: 'Brand new', watts: 60, hours: 1, time: now);
    await tester.pumpAndSettle();
    expect(find.text('Brand new'), findsOneWidget);
  });

  testWidgets('very large system text is capped so rows still fit',
      (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    // The test font is extremely wide, so even a capped 1.3x overflows rows
    // here; this test only checks the cap itself.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() {
      FlutterError.onError = originalOnError;
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final store = WattlyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(WattlyApp(store: store));

    final scaler =
        MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first));
    expect(scaler.scale(10), closeTo(13, 0.001)); // 1.3x, not 3x
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
