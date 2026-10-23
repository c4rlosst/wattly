import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../meter_scan.dart';
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
      // Only the sheet repaints while it slides and the keyboard animates.
      child: RepaintBoundary(child: _AddUsageSheet(store: store)),
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
  final _nameFocus = FocusNode();
  final _wattsFocus = FocusNode();
  final _hoursFocus = FocusNode();
  final _readingFocus = FocusNode();
  bool _saveDevice = false;
  bool _saving = false;
  DateTime _time = DateTime.now();
  String? _error;
  bool _scanning = false;
  String? _scanNote;

  @override
  void dispose() {
    _name.dispose();
    _watts.dispose();
    _hours.dispose();
    _reading.dispose();
    _nameFocus.dispose();
    _wattsFocus.dispose();
    _hoursFocus.dispose();
    _readingFocus.dispose();
    super.dispose();
  }

  /// Takes a photo of the meter and reads the number off it, on this phone.
  /// The number only fills the field; the student still checks it.
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanNote = null);
    try {
      final text = await scanMeter(() {
        if (mounted) setState(() => _scanning = true);
      }, last: widget.store.latestReading?.kwh);
      if (!mounted) return;
      if (text == null) return; // cancelled
      final v = readingFromScan(text, last: widget.store.latestReading?.kwh);
      setState(() {
        _scanning = false;
        if (v == null) {
          _scanNote =
              'Couldn’t read a number. Try again closer and straight on, or type it.';
        } else {
          _reading.text = trimNumber(v);
          _scanNote =
              'Read ${trimNumber(v)} from the meter. Check it matches your meter.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanNote =
            'Couldn’t load the photo reader. Connect to the internet once and try again, or type it.';
      });
    }
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
    // The sheet takes a moment to slide away; a quick second tap on Save must
    // not log the same entry twice.
    if (_saving) return;
    final store = widget.store;
    if (_mode == _Mode.meter) {
      final kwh = parseNumber(_reading.text);
      if (kwh == null || kwh < 0) {
        setState(() => _error = 'Enter the number shown on your meter.');
        return;
      }
      _saving = true;
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
      _saving = true;
      store.addUsage(label: name, watts: watts, hours: hours, time: _time);
      // "Save for next time" must not pile up copies of the same device.
      final alreadySaved = store.appliances.any(
          (a) => a.name.toLowerCase() == name.toLowerCase() && a.watts == watts);
      if (_saveDevice && _appliance == null && !alreadySaved) {
        store.addAppliance(name, watts);
      }
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
    String? warning;
    String label = 'This will add';
    if (_mode == _Mode.device) {
      if (watts != null && hours != null) {
        addKwh = wattHoursToKwh(watts, hours);
        caption = '${trimNumber(watts)} W × ${trimNumber(hours)} h ÷ 1000';
      }
    } else {
      label = 'Since last reading';
      if (reading != null && last != null) {
        if (reading >= last.kwh) {
          addKwh = reading - last.kwh;
          caption = '${trimNumber(reading)} − ${trimNumber(last.kwh)}';
        } else {
          // Usually a typo; a meter only counts up. Still allowed (a meter can
          // be replaced), but say so.
          warning =
              'That is lower than your last reading (${formatKwh(last.kwh)}). Check the number.';
        }
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
                height: 44,
                child: Tappable(
                  onTap: () => Navigator.pop(context),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cancel',
                        style: TextStyle(fontSize: 17, color: p.accentText)),
                  ),
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
                FormRow(
                  label: 'Device',
                  onTap: _pickAppliance,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_appliance?.name ?? 'Custom',
                          style:
                              TextStyle(fontSize: 17, color: p.secondary)),
                      const SizedBox(width: 6),
                      ChevronIcon(
                          size: 14,
                          color: p.secondary.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              // Tapping anywhere on a row (label included) focuses its field,
              // and Enter moves on to the next one.
              FormRow(
                label: 'Name',
                onTap: _nameFocus.requestFocus,
                trailing: NumberField(
                  key: const Key('name'),
                  focusNode: _nameFocus,
                  controller: _name,
                  enabled: custom,
                  hint: 'Laptop',
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _wattsFocus.requestFocus(),
                ),
              ),
              FormRow(
                label: 'Power (W)',
                onTap: _wattsFocus.requestFocus,
                trailing: NumberField(
                  key: const Key('watts'),
                  focusNode: _wattsFocus,
                  controller: _watts,
                  enabled: custom,
                  hint: '65',
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _hoursFocus.requestFocus(),
                ),
              ),
              FormRow(
                label: 'Hours used',
                onTap: _hoursFocus.requestFocus,
                trailing: NumberField(
                  key: const Key('hours'),
                  focusNode: _hoursFocus,
                  controller: _hours,
                  hint: '8',
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ])
          else
            Group(
              footer: _scanNote ??
                  'Enter the total shown on your dorm meter right now.',
              children: [
                if (meterScanSupported)
                  Tappable(
                    key: const Key('scan'),
                    onTap: _scan,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _scanning
                                ? const CupertinoActivityIndicator()
                                : Icon(CupertinoIcons.camera_fill,
                                    size: 24, color: p.accentText),
                            const SizedBox(width: 12),
                            Text(_scanning ? 'Reading…' : 'Scan meter',
                                style: TextStyle(
                                    fontSize: 17, color: p.accentText)),
                          ],
                        ),
                      ),
                    ),
                  ),
                FormRow(
                  label: 'Meter (kWh)',
                  onTap: _readingFocus.requestFocus,
                  trailing: NumberField(
                    key: const Key('reading'),
                    focusNode: _readingFocus,
                    controller: _reading,
                    hint: '4821.6',
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Group(children: [
            FormRow(
              label: 'When',
              onTap: _pickTime,
              trailing: Text(whenLabel(_time, now),
                  style: TextStyle(fontSize: 17, color: p.secondary)),
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
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(warning,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.accentText)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: CupertinoColors.systemRed)),
            ),
          const SizedBox(height: 20),
          Tappable(
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
