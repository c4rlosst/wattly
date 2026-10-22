/// A saved device the student owns, so its wattage only has to be typed once.
class Appliance {
  const Appliance({required this.id, required this.name, required this.watts});

  final String id;
  final String name;
  final double watts;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'watts': watts};

  factory Appliance.fromJson(Map<String, dynamic> json) => Appliance(
        id: json['id'] as String,
        name: json['name'] as String,
        watts: (json['watts'] as num).toDouble(),
      );
}

/// An estimated usage log: a device drawing [watts] for [hours].
class UsageEntry {
  const UsageEntry({
    required this.id,
    required this.time,
    required this.label,
    required this.watts,
    required this.hours,
    required this.ratePerKwh,
  });

  final String id;
  final DateTime time;
  final String label;
  final double watts;
  final double hours;

  /// Rate in effect when the entry was logged, so old costs don't shift when
  /// the student later changes their rate.
  final double ratePerKwh;

  double get kwh => watts * hours / 1000;
  double get cost => kwh * ratePerKwh;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'label': label,
        'watts': watts,
        'hours': hours,
        'rate': ratePerKwh,
      };

  factory UsageEntry.fromJson(Map<String, dynamic> json) => UsageEntry(
        id: json['id'] as String,
        time: DateTime.parse(json['time'] as String),
        label: json['label'] as String,
        watts: (json['watts'] as num).toDouble(),
        hours: (json['hours'] as num).toDouble(),
        ratePerKwh: (json['rate'] as num).toDouble(),
      );
}

/// A cumulative reading copied off the dorm's electricity meter.
class MeterReading {
  const MeterReading({required this.id, required this.time, required this.kwh});

  final String id;
  final DateTime time;
  final double kwh;

  Map<String, dynamic> toJson() =>
      {'id': id, 'time': time.toIso8601String(), 'kwh': kwh};

  factory MeterReading.fromJson(Map<String, dynamic> json) => MeterReading(
        id: json['id'] as String,
        time: DateTime.parse(json['time'] as String),
        kwh: (json['kwh'] as num).toDouble(),
      );
}
