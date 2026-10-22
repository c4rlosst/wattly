import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> showAddUsageSheet(BuildContext context, WattlyStore store) {
  final p = Palette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: p.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _AddUsageSheet(store: store),
    ),
  );
}

enum _Mode { device, meter }

class _AddUsageSheet extends StatefulWidget {
  const _AddUsageSheet({required this.store});

  final WattlyStore store;

  @override
  State<_AddUsageSheet> createState() => _AddUsageSheetState();
}

class _AddUsageSheetState extends State<_AddUsageSheet> {
  _Mode _mode = _Mode.device;
  Appliance? _appliance;
  final _name = TextEditingController();
  final _watts = TextEditingController();
  final _hours = TextEditingController();
  final _reading = TextEditingController();
  bool _saveDevice = false;
  DateTime _time = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _watts.dispose();
    _hours.dispose();
    _reading.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    var picked = _time;
    final latest = DateTime.now().add(const Duration(minutes: 1));
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return Container(
          height: 300,
          color: p.card,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Done',
                      style: TextStyle(color: p.accentText)),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _time.isAfter(latest) ? latest : _time,
                  maximumDate: latest,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() => _time = picked);
  }

  Future<void> _pickAppliance() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _selectAppliance(null);
            },
            child: const Text('Custom device'),
          ),
          for (final a in widget.store.appliances)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _selectAppliance(a);
              },
              child: Text('${a.name} (${a.watts.toStringAsFixed(0)} W)'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _selectAppliance(Appliance? a) {
    setState(() {
      _appliance = a;
      if (a != null) {
        _name.text = a.name;
        _watts.text = a.watts.toString();
      } else {
        _name.clear();
        _watts.clear();
      }
    });
  }

  void _save() {
    final store = widget.store;
    if (_mode == _Mode.meter) {
      final kwh = parseNumber(_reading.text);
      if (kwh == null || kwh < 0) {
        setState(() => _error = 'Enter the number shown on your meter.');
        return;
      }
      store.addReading(kwh, _time);
    } else {
      final name = _name.text.trim();
      final watts = parseNumber(_watts.text);
      final hours = parseNumber(_hours.text);
      if (name.isEmpty || watts == null || watts <= 0) {
        setState(() => _error = 'Enter a device name and its wattage.');
        return;
      }
      if (hours == null || hours <= 0) {
        setState(() => _error = 'Enter how many hours it ran.');
        return;
      }
      store.addUsage(label: name, watts: watts, hours: hours, time: _time);
      if (_saveDevice && _appliance == null) store.addAppliance(name, watts);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = Palette.of(context);
    final now = DateTime.now();
    final custom = _appliance == null;

    final watts = parseNumber(_watts.text);
    final hours = parseNumber(_hours.text);
    final reading = parseNumber(_reading.text);
    final last = store.latestReading;

    double? addKwh;
    String? caption;
    String label = 'This will add';
    if (_mode == _Mode.device) {
      if (watts != null && hours != null) {
        addKwh = wattHoursToKwh(watts, hours);
        caption = '${watts.toStringAsFixed(0)} W × $hours h ÷ 1000';
      }
    } else {
      label = 'Since last reading';
      if (reading != null && last != null && reading >= last.kwh) {
        addKwh = reading - last.kwh;
        caption = '$reading − ${last.kwh}';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(fontSize: 17, color: p.accentText)),
                ),
              ),
              Expanded(
                child: Text('Log usage',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.label)),
              ),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: 16),
          Segmented<_Mode>(
            value: _mode,
            options: const {
              _Mode.device: 'Device',
              _Mode.meter: 'Meter reading',
            },
            onChanged: (v) => setState(() {
              _mode = v;
              _error = null;
            }),
          ),
          const SizedBox(height: 20),
          if (_mode == _Mode.device)
            Group(children: [
              if (store.appliances.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickAppliance,
                  child: FormRow(
                    label: 'Device',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_appliance?.name ?? 'Custom',
                            style: TextStyle(
                                fontSize: 17, color: p.secondary)),
                        const SizedBox(width: 6),
                        ChevronIcon(
                            size: 14,
                            color: p.secondary.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
              FormRow(
                label: 'Name',
                trailing: NumberField(
                  key: const Key('name'),
                  controller: _name,
                  enabled: custom,
                  hint: 'Laptop',
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              FormRow(
                label: 'Power (W)',
                trailing: NumberField(
                  key: const Key('watts'),
                  controller: _watts,
                  enabled: custom,
                  hint: '65',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              FormRow(
                label: 'Hours used',
                trailing: NumberField(
                  key: const Key('hours'),
                  controller: _hours,
                  hint: '8',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ])
          else
            Group(
              footer: 'Enter the total shown on your dorm meter right now.',
              children: [
                FormRow(
                  label: 'Meter (kWh)',
                  trailing: NumberField(
                    key: const Key('reading'),
                    controller: _reading,
                    hint: '4821.6',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Group(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickTime,
              child: FormRow(
                label: 'When',
                trailing: Text(whenLabel(_time, now),
                    style: TextStyle(fontSize: 17, color: p.secondary)),
              ),
            ),
            if (_mode == _Mode.device && custom)
              FormRow(
                label: 'Save for next time',
                trailing: CupertinoSwitch(
                  value: _saveDevice,
                  activeTrackColor: p.green,
                  onChanged: (v) => setState(() => _saveDevice = v),
                ),
              ),
          ]),
          if (addKwh != null) ...[
            const SizedBox(height: 20),
            Text(label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: p.secondary)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(formatKwhValue(addKwh),
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        color: p.label)),
                const SizedBox(width: 6),
                Text('kWh',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: p.secondary)),
              ],
            ),
            if (store.ratePerKwh > 0)
              Text('≈ ${formatMoney(store.currency, addKwh * store.ratePerKwh)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: p.accentText)),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(caption,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.secondary)),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: CupertinoColors.systemRed)),
            ),
          const SizedBox(height: 20),
          GestureDetector(
            key: const Key('save'),
            onTap: _save,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Save',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: p.onAccent)),
            ),
          ),
        ],
      ),
    );
  }
}
