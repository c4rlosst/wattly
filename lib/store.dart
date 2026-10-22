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

  final SharedPreferences _prefs;

  double ratePerKwh = 0;
  String currency = '\$';
  String currencyCode = 'USD';
  Appearance appearance = Appearance.light;
  final List<Appliance> appliances = [];
  final List<UsageEntry> entries = [];
  final List<MeterReading> readings = [];

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
      appearance =
          Appearance.values.asNameMap()[data['appearance']] ?? Appearance.light;
      appliances.addAll((data['appliances'] as List? ?? [])
          .map((e) => Appliance.fromJson(e as Map<String, dynamic>)));
      entries.addAll((data['entries'] as List? ?? [])
          .map((e) => UsageEntry.fromJson(e as Map<String, dynamic>)));
      readings.addAll((data['readings'] as List? ?? [])
          .map((e) => MeterReading.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // Corrupt data: start fresh rather than crash on launch.
      appliances.clear();
      entries.clear();
      readings.clear();
    }
  }

  void _save() {
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
    notifyListeners();
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void setRate(double value) {
    ratePerKwh = value;
    _save();
  }

  void setAppearance(Appearance value) {
    appearance = value;
    _save();
  }

  /// Picks a listed currency, or a custom [symbol] when [code] is omitted.
  void setCurrency(String symbol, {String code = customCurrencyCode}) {
    currency = symbol;
    currencyCode = code;
    _save();
  }

  Appliance addAppliance(String name, double watts) {
    final appliance = Appliance(id: _newId(), name: name, watts: watts);
    appliances.add(appliance);
    _save();
    return appliance;
  }

  void removeAppliance(String id) {
    appliances.removeWhere((a) => a.id == id);
    _save();
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
    _save();
  }

  void removeUsage(String id) {
    entries.removeWhere((e) => e.id == id);
    _save();
  }

  void addReading(double kwh, DateTime time) {
    readings.add(MeterReading(id: _newId(), time: time, kwh: kwh));
    _save();
  }

  void removeReading(String id) {
    readings.removeWhere((r) => r.id == id);
    _save();
  }

  /// Latest meter reading by time, if any.
  MeterReading? get latestReading => readings.isEmpty
      ? null
      : (readings.toList()..sort((a, b) => a.time.compareTo(b.time))).last;

  List<Bucket> bucketsFor(Period period) =>
      usageBuckets(entries, period, DateTime.now());

  double estimatedKwhSince(DateTime from) => estimatedKwh(entries, from);
  double estimatedCostSince(DateTime from) => estimatedCost(entries, from);
  double? meteredKwhSince(DateTime from) => meteredKwh(readings, from);
}
