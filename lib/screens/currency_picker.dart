import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../currencies.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> showCurrencyPicker(BuildContext context, WattlyStore store) {
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
    builder: (context) => _CurrencyList(store: store),
  );
}

class _CurrencyList extends StatelessWidget {
  const _CurrencyList({required this.store});

  final WattlyStore store;

  Future<void> _custom(BuildContext context) async {
    final controller = TextEditingController(
        text: store.currencyCode == customCurrencyCode ? store.currency : '');
    final symbol = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Custom symbol'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            maxLength: 5,
            placeholder: 'e.g. ₱ or PHP',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final s = controller.text.trim();
              if (s.isEmpty) return;
              Navigator.pop(ctx, s);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (symbol != null) {
      store.setCurrency(symbol);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isCustom = store.currencyCode == customCurrencyCode;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Currency',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: p.label)),
          const SizedBox(height: 16),
          Group(
            footer:
                'Changing the currency doesn’t convert your price per kWh. Update it in Settings.',
            children: [
              for (final c in currencies)
                _Row(
                  key: Key('currency-${c.code}'),
                  symbol: c.symbol,
                  title: c.name,
                  subtitle: c.code,
                  selected: store.currencyCode == c.code,
                  onTap: () {
                    store.setCurrency(c.symbol, code: c.code);
                    Navigator.pop(context);
                  },
                ),
              _Row(
                key: const Key('currency-custom'),
                symbol: isCustom ? store.currency : '…',
                title: 'Custom symbol',
                subtitle: 'Type your own',
                selected: isCustom,
                onTap: () => _custom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String symbol;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(symbol,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.label)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 17, color: p.label)),
                    Text(subtitle,
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  ],
                ),
              ),
              if (selected)
                Icon(CupertinoIcons.checkmark_alt,
                    size: 24, color: p.accentText),
            ],
          ),
        ),
      ),
    );
  }
}
