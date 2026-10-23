import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wattly/store.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Map<String, dynamic> saved() =>
      jsonDecode(prefs.getString('wattly_v1') ?? '{}') as Map<String, dynamic>;

  test('every entry gets a unique id, even when added in the same instant', () {
    final store = WattlyStore(prefs);
    for (var i = 0; i < 500; i++) {
      store.addUsage(
          label: 'Fan', watts: 40, hours: 1, time: DateTime(2026, 10, 1));
    }
    store.addReading(10, DateTime(2026, 10, 1));
    store.addAppliance('Fan', 40);
    final ids = {
      ...store.entries.map((e) => e.id),
      ...store.readings.map((r) => r.id),
      ...store.appliances.map((a) => a.id),
    };
    expect(ids.length, 502);
  });

  test('readings stay in time order and latestReading is the newest', () async {
    final store = WattlyStore(prefs);
    store.addReading(130, DateTime(2026, 10, 3));
    store.addReading(100, DateTime(2026, 10, 1));
    store.addReading(115, DateTime(2026, 10, 2));
    expect(store.readings.map((r) => r.kwh), [100, 115, 130]);
    expect(store.latestReading!.kwh, 130);

    // ...also after loading data that was saved out of order.
    SharedPreferences.setMockInitialValues({
      'wattly_v1': jsonEncode({
        'readings': [
          {'id': 'b', 'time': '2026-10-03T00:00:00.000', 'kwh': 30},
          {'id': 'a', 'time': '2026-10-01T00:00:00.000', 'kwh': 10},
        ],
      }),
    });
    final reloaded = WattlyStore(await SharedPreferences.getInstance());
    expect(reloaded.readings.map((r) => r.id), ['a', 'b']);
    expect(reloaded.latestReading!.id, 'b');
  });

  test('typing the price does not write on every keystroke', () {
    final store = WattlyStore(prefs)..addAppliance('Fan', 40);
    final before = prefs.getString('wattly_v1');

    store
      ..setRate(1)
      ..setRate(1.5)
      ..setRate(15)
      ..setRate(15.5);
    expect(prefs.getString('wattly_v1'), before); // nothing written yet
    expect(store.ratePerKwh, 15.5); // but the screen already has it

    store.flush();
    expect(saved()['rate'], 15.5);
  });

  test('a typed price is saved along with the next saved change', () {
    final store = WattlyStore(prefs)..setRate(12);
    store.addAppliance('Fan', 40); // any saved change carries the price along
    expect(saved()['rate'], 12);
  });

  test('flush with nothing pending writes nothing', () {
    final store = WattlyStore(prefs);
    store.flush();
    expect(prefs.getString('wattly_v1'), isNull);
  });

  test('setting the same price again changes nothing', () {
    final store = WattlyStore(prefs)..setRate(15);
    var notified = 0;
    store.addListener(() => notified++);
    final revision = store.revision;
    store.setRate(15);
    expect(notified, 0);
    expect(store.revision, revision);
  });

  test('the theme is only told about appearance changes', () {
    final store = WattlyStore(prefs);
    var themeChanges = 0;
    store.appearanceListenable.addListener(() => themeChanges++);

    store
      ..addUsage(label: 'Fan', watts: 40, hours: 1, time: DateTime(2026, 10, 1))
      ..setRate(15)
      ..setCurrency('₱', code: 'PHP');
    expect(themeChanges, 0);

    store.setAppearance(Appearance.dark);
    expect(themeChanges, 1);
    store.setAppearance(Appearance.dark); // same again: nothing to do
    expect(themeChanges, 1);
  });

  test('every change bumps the revision screens use to cache their work', () {
    final store = WattlyStore(prefs);
    var last = store.revision;
    void expectBumped(void Function() change) {
      change();
      expect(store.revision, greaterThan(last));
      last = store.revision;
    }

    expectBumped(() => store.addUsage(
        label: 'Fan', watts: 40, hours: 1, time: DateTime(2026, 10, 1)));
    expectBumped(() => store.addReading(1, DateTime(2026, 10, 1)));
    expectBumped(() => store.addAppliance('Fan', 40));
    expectBumped(() => store.setRate(9));
    expectBumped(() => store.setCurrency('€', code: 'EUR'));
    expectBumped(store.refresh);
  });
}
