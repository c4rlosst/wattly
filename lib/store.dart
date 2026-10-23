import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calc.dart';
import 'currencies.dart';
import 'models.dart';

/// How the app picks light or dark. Light is the default on every device,
/// including computers set to dark mode; [system] follows the device instead.
enum Appearance { light, dark, system }

/// All app state, persisted on-device only (no accounts, no server).
class WattlyStore extends ChangeNotifier {
  WattlyStore(this._prefs) {
    _load();
  }

  static const _key = 'wattly_v1';
  static int _idCounter = 0;

  final SharedPreferences _prefs;

  double ratePerKwh = 0;
  String currency = '\$';
  String currencyCode = 'USD';
  final List<Appliance> appliances = [];
  final List<UsageEntry> entries = [];

  /// Meter readings, oldest first.
  final List<MeterReading> readings = [];

  final ValueNotifier<Appearance> _appearance = ValueNotifier(Appearance.light);

  /// Changes only when the student picks Light, Dark or Auto, so the app's
  /// theme isn't rebuilt every time something else changes.
  ValueListenable<Appearance> get appearanceListenable => _appearance;
  Appearance get appearance => _appearance.value;

  /// Bumped on every change, so screens can reuse work between rebuilds.
  int revision = 0;

  bool _unsaved = false;

  static int _byTime(MeterReading a, MeterReading b) =>
      a.time.compareTo(b.time);

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      ratePerKwh = (data['rate'] as num?)?.toDouble() ?? 0;
      currency = data['currency'] as String? ?? currency;
      // Data saved before the picker existed has only a symbol.
      currencyCode = data['currencyCode'] as String? ??
          currencyBySymbol(currency)?.code ??
          customCurrencyCode;
      _appearance.value =
          Appearance.values.asNameMap()[data['appearance']] ?? Appearance.light;
      appliances.addAll((data['appliances'] as List? ?? [])
          .map((e) => Appliance.fromJson(e as Map<String, dynamic>)));
      entries.addAll((data['entries'] as List? ?? [])
          .map((e) => UsageEntry.fromJson(e as Map<String, dynamic>)));
      readings
        ..addAll((data['readings'] as List? ?? [])
            .map((e) => MeterReading.fromJson(e as Map<String, dynamic>)))
        ..sort(_byTime);
    } catch (_) {
      // Corrupt data: start fresh rather than crash on launch.
      appliances.clear();
      entries.clear();
      readings.clear();
    }
  }

  void _persist() {
    _unsaved = false;
    _prefs.setString(
      _key,
      jsonEncode({
        'rate': ratePerKwh,
        'currency': currency,
        'currencyCode': currencyCode,
        'appearance': appearance.name,
        'appliances': appliances.map((e) => e.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'readings': readings.map((e) => e.toJson()).toList(),
      }),
    );
  }

  /// Saves right away and tells the screens. Used for everything except typing
  /// the price: those changes are one-off taps, so saving at once is cheap.
  void _commit() {
    revision++;
    _persist();
    notifyListeners();
  }

  /// Writes a typed-but-unsaved value. Called when the price field is left and
  /// when the app goes to the background.
  void flush() {
    if (_unsaved) _persist();
  }

  /// Makes screens recompute date-based figures, e.g. after the phone wakes up
  /// on a new day. Nothing is saved.
  void refresh() {
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    flush();
    _appearance.dispose();
    super.dispose();
  }

  /// Unique within and across sessions, even for entries made in the same
  /// millisecond (the web clock only ticks in milliseconds).
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${(_idCounter++).toRadixString(36)}';

  /// Called on every keystroke while the price is typed, so it is cheap: it
  /// doesn't write anything ([flush], or the next saved change, does). With
  /// [notify] false the screens aren't told at all; they notice the new
  /// [revision] the next time they are shown. The Settings screen uses that,
  /// because nothing on it changes when the price does.
  void setRate(double value, {bool notify = true}) {
    if (value == ratePerKwh) return;
    ratePerKwh = value;
    revision++;
    _unsaved = true;
    if (notify) notifyListeners();
  }

  void setAppearance(Appearance value) {
    if (value == appearance) return;
    _appearance.value = value;
    _commit();
  }

  /// Picks a listed currency, or a custom [symbol] when [code] is omitted.
  void setCurrency(String symbol, {String code = customCurrencyCode}) {
    currency = symbol;
    currencyCode = code;
    _commit();
  }

  Appliance addAppliance(String name, double watts) {
    final appliance = Appliance(id: _newId(), name: name, watts: watts);
    appliances.add(appliance);
    _commit();
    return appliance;
  }

  void removeAppliance(String id) {
    appliances.removeWhere((a) => a.id == id);
    _commit();
  }

  void addUsage({
    required String label,
    required double watts,
    required double hours,
    required DateTime time,
  }) {
    entries.add(UsageEntry(
      id: _newId(),
      time: time,
      label: label,
      watts: watts,
      hours: hours,
      ratePerKwh: ratePerKwh,
    ));
    _commit();
  }

  void removeUsage(String id) {
    entries.removeWhere((e) => e.id == id);
    _commit();
  }

  void addReading(double kwh, DateTime time) {
    readings
      ..add(MeterReading(id: _newId(), time: time, kwh: kwh))
      ..sort(_byTime);
    _commit();
  }

  void removeReading(String id) {
    readings.removeWhere((r) => r.id == id);
    _commit();
  }

  /// Latest meter reading by time, if any.
  MeterReading? get latestReading => readings.isEmpty ? null : readings.last;

  List<Bucket> bucketsFor(Period period) =>
      usageBuckets(entries, period, DateTime.now());

  double estimatedKwhSince(DateTime from) => estimatedKwh(entries, from);
  double estimatedCostSince(DateTime from) => estimatedCost(entries, from);
  double? meteredKwhSince(DateTime from) => meteredKwh(readings, from);
}
