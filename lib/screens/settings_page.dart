import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../currencies.dart';
import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'currency_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});

  final WattlyStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _rate;

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _rate = TextEditingController(
        text: s.ratePerKwh == 0 ? '' : s.ratePerKwh.toString());
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _addAppliance() async {
    final name = TextEditingController();
    final watts = TextEditingController();
    final result = await showCupertinoDialog<(String, double)>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New device'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: name,
                autofocus: true,
                placeholder: 'Name (e.g. Laptop)',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: watts,
                placeholder: 'Power (watts)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    final p = Palette.of(context);

    return CustomScrollView(
      slivers: [
        largeTitleBar(context, 'Settings'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.list(
            children: [
              Group(
                header: 'Electricity rate',
                footer:
                    'Check your dorm or utility bill. Past entries keep the rate they were logged with.',
                children: [
                  GestureDetector(
                    key: const Key('currency-row'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showCurrencyPicker(context, store),
                    child: FormRow(
                      label: 'Currency',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              currencyByCode(store.currencyCode)?.name ??
                                  'Custom (${store.currency})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 17, color: p.secondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(CupertinoIcons.chevron_right,
                              size: 14, color: p.secondary),
                        ],
                      ),
                    ),
                  ),
                  FormRow(
                    label: 'Price per kWh',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(store.currency,
                            style:
                                TextStyle(fontSize: 17, color: p.secondary)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 80,
                          child: NumberField(
                            key: const Key('rate'),
                            controller: _rate,
                            hint: '0.00',
                            onChanged: (v) =>
                                store.setRate(parseNumber(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Group(
                header: 'My devices',
                footer: store.appliances.isEmpty
                    ? 'Save a device’s wattage once, then just pick it when logging.'
                    : 'Swipe left on a device to remove it.',
                children: [
                  for (final a in store.appliances)
                    Dismissible(
                      key: ValueKey(a.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: CupertinoColors.systemRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(CupertinoIcons.delete,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => store.removeAppliance(a.id),
                      child: ColoredBox(
                        color: p.card,
                        child: FormRow(
                          label: a.name,
                          trailing: Text('${a.watts.toStringAsFixed(0)} W',
                              style: TextStyle(
                                  fontSize: 17, color: p.secondary)),
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _addAppliance,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.add_circled,
                                size: 22, color: p.accentText),
                            const SizedBox(width: 12),
                            Text('Add device',
                                style: TextStyle(
                                    fontSize: 17, color: p.accentText)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Group(children: [
                FormRow(
                  label: 'Data stays on this phone',
                  trailing:
                      Icon(CupertinoIcons.check_mark, size: 20, color: p.green),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
