import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';

Future<void> showAddUsageSheet(BuildContext context, WattlyStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
    final date = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_time));
    if (time == null) return;
    setState(() => _time = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  void _selectAppliance(Appliance? a) {
    setState(() {
      _appliance = a;
      if (a != null) {
        _name.text = a.name;
        _watts.text = a.watts.toString();
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
    final watts = parseNumber(_watts.text);
    final hours = parseNumber(_hours.text);
    final preview = (_mode == _Mode.device && watts != null && hours != null)
        ? wattHoursToKwh(watts, hours)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                  value: _Mode.device,
                  icon: Icon(Icons.devices_other),
                  label: Text('Device')),
              ButtonSegment(
                  value: _Mode.meter,
                  icon: Icon(Icons.speed),
                  label: Text('Meter reading')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.device) ...[
            if (store.appliances.isNotEmpty) ...[
              DropdownButtonFormField<Appliance?>(
                initialValue: _appliance,
                decoration: const InputDecoration(labelText: 'Saved device'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Custom device')),
                  for (final a in store.appliances)
                    DropdownMenuItem(
                        value: a,
                        child: Text('${a.name} (${a.watts.toStringAsFixed(0)} W)')),
                ],
                onChanged: _selectAppliance,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              enabled: _appliance == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Device name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _watts,
                    enabled: _appliance == null,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Watts'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hours,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Hours used'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_appliance == null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveDevice,
                onChanged: (v) => setState(() => _saveDevice = v ?? false),
                title: const Text('Save this device for next time'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '= ${formatKwh(preview)}'
                  '${store.ratePerKwh > 0 ? ' · ${formatMoney(store.currency, preview * store.ratePerKwh)}' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
          ] else
            TextField(
              controller: _reading,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Meter reading (kWh)',
                helperText: 'The total shown on the meter right now',
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(formatDateTime(_time)),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
