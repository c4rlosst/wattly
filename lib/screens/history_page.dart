import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_usage_sheet.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.store});

  final WattlyStore store;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();

    final items = <_Item>[
      for (final e in store.entries)
        _Item(
          id: e.id,
          time: e.time,
          icon: CupertinoIcons.bolt_fill,
          color: p.accent,
          title: e.label,
          subtitle: '${e.watts.toStringAsFixed(0)} W × ${e.hours} h',
          trailing: formatKwh(e.kwh),
          onDelete: () => store.removeUsage(e.id),
        ),
      for (final r in store.readings)
        _Item(
          id: r.id,
          time: r.time,
          icon: CupertinoIcons.timer_fill,
          color: p.green,
          title: 'Meter reading',
          subtitle: formatTime(r.time),
          trailing: formatKwh(r.kwh),
          onDelete: () => store.removeReading(r.id),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    // Group by calendar day, newest first (items are already sorted).
    final days = <String, List<_Item>>{};
    for (final item in items) {
      days.putIfAbsent(dayLabel(item.time, now), () => []).add(item);
    }

    return CustomScrollView(
      slivers: [
        largeTitleBar(
          context,
          'History',
          trailing: AddButton(
              onPressed: () => showAddUsageSheet(context, store)),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.clock_fill, size: 48, color: p.secondary),
                    const SizedBox(height: 12),
                    Text('Nothing logged yet',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: p.label)),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to add a device or a meter reading.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: p.secondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: [
                for (final entry in days.entries) ...[
                  Group(
                    header: entry.key,
                    children: [
                      for (final item in entry.value) _Row(item: item),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Swipe left on an entry to delete it.',
                      style: TextStyle(fontSize: 13, color: p.secondary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
      ),
      onDismissed: (_) => item.onDelete(),
      child: ColoredBox(
        color: p.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconTile(icon: item.icon, color: item.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: TextStyle(fontSize: 17, color: p.label)),
                    Text(item.subtitle,
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  ],
                ),
              ),
              Text(item.trailing,
                  style: TextStyle(
                      fontSize: 17,
                      color: p.secondary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.id,
    required this.time,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onDelete,
  });

  final String id;
  final DateTime time;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onDelete;
}
