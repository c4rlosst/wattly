import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});

  final WattlyStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _rate;
  late final TextEditingController _currency;

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _rate = TextEditingController(
        text: s.ratePerKwh == 0 ? '' : s.ratePerKwh.toString());
    _currency = TextEditingController(text: s.currency);
  }

  @override
  void dispose() {
    _rate.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _addAppliance() async {
    final name = TextEditingController();
    final watts = TextEditingController();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name (e.g. Laptop)'),
            ),
            TextField(
              controller: watts,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Power (watts)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final w = parseNumber(watts.text);
              if (name.text.trim().isEmpty || w == null || w <= 0) return;
              Navigator.pop(context, (name.text.trim(), w));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    watts.dispose();
    if (result != null) widget.store.addAppliance(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('Electricity rate', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                onChanged: (v) => store.setCurrency(v.isEmpty ? '\$' : v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _rate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price per kWh',
                  helperText: 'Check your dorm or utility bill',
                ),
                onChanged: (v) => store.setRate(parseNumber(v) ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                child: Text('My devices', style: theme.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: _addAppliance,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (store.appliances.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
                'Save the wattage of your laptop, fan, mini-fridge, etc. once, then just pick them when logging.'),
          ),
        for (final a in store.appliances)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.name),
            subtitle: Text('${a.watts.toStringAsFixed(0)} W'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => store.removeAppliance(a.id),
            ),
          ),
      ],
    );
  }
}
