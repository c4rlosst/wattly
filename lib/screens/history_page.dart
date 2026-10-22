import 'package:flutter/material.dart';

import '../format.dart';
import '../store.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.store});

  final WattlyStore store;

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      for (final e in store.entries)
        _Item(
          id: e.id,
          time: e.time,
          icon: Icons.devices_other,
          title: e.label,
          subtitle:
              '${e.watts.toStringAsFixed(0)} W × ${e.hours} h · ${formatDateTime(e.time)}',
          trailing: formatKwh(e.kwh),
          onDelete: () => store.removeUsage(e.id),
        ),
      for (final r in store.readings)
        _Item(
          id: r.id,
          time: r.time,
          icon: Icons.speed,
          title: 'Meter reading',
          subtitle: formatDateTime(r.time),
          trailing: formatKwh(r.kwh),
          onDelete: () => store.removeReading(r.id),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nothing logged yet.\nTap “Log usage” to add a device or a meter reading.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete),
          ),
          onDismissed: (_) => item.onDelete(),
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            trailing: Text(item.trailing,
                style: Theme.of(context).textTheme.titleSmall),
          ),
        );
      },
    );
  }
}

class _Item {
  const _Item({
    required this.id,
    required this.time,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onDelete,
  });

  final String id;
  final DateTime time;
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onDelete;
}
