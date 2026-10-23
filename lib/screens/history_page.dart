import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_usage_sheet.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});

  final WattlyStore store;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scroll = ScrollController();

  // Sorting and grouping every entry is the expensive part, so it is done once
  // per change to the data (or per new day), not on every rebuild.
  int _revision = -1;
  int _today = -1;
  List<_Day> _days = const [];
  _Item? _newest;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<_Day> _daysFor(DateTime now) {
    final today = dayNumber(now);
    if (_revision != widget.store.revision || _today != today) {
      final days = _group(widget.store, now);
      final newest = days.isEmpty ? null : days.first.items.first;
      // The list keeps its scroll position between visits, but a brand-new
      // entry lands at the top: bring it into view instead of hiding it.
      final previous = _newest;
      if (previous != null &&
          newest != null &&
          newest.id != previous.id &&
          newest.time.isAfter(previous.time)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
        });
      }
      _days = days;
      _newest = newest;
      _revision = widget.store.revision;
      _today = today;
    }
    return _days;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = Palette.of(context);
    final days = _daysFor(DateTime.now());

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        largeTitleBar(
          context,
          'History',
          trailing: AddButton(
              onPressed: () => showAddUsageSheet(context, store)),
        ),
        if (days.isEmpty)
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
            // Builds only the days on screen, however long the history is.
            sliver: SliverList.builder(
              itemCount: days.length + 1,
              itemBuilder: (context, i) {
                if (i == days.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Swipe left on an entry to delete it.',
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  );
                }
                final day = days[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Group(
                    header: day.label,
                    children: [
                      for (final item in day.items)
                        _Row(key: ValueKey(item.id), item: item, store: store),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// All entries and meter readings, newest first, grouped by calendar day.
List<_Day> _group(WattlyStore store, DateTime now) {
  final items = <_Item>[
    for (final e in store.entries) _Item.entry(e),
    for (final r in store.readings) _Item.reading(r),
  ]..sort((a, b) => b.time.compareTo(a.time));

  final days = <_Day>[];
  var current = -1;
  for (final item in items) {
    final day = dayNumber(item.time);
    if (day != current) {
      current = day;
      days.add(_Day(dayLabel(item.time, now), []));
    }
    days.last.items.add(item);
  }
  return days;
}

class _Day {
  _Day(this.label, this.items);

  final String label;
  final List<_Item> items;
}

class _Item {
  _Item.entry(UsageEntry e)
      : id = e.id,
        time = e.time,
        entry = e,
        reading = null;

  _Item.reading(MeterReading r)
      : id = r.id,
        time = r.time,
        entry = null,
        reading = r;

  final String id;
  final DateTime time;
  final UsageEntry? entry;
  final MeterReading? reading;
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.item, required this.store});

  final _Item item;
  final WattlyStore store;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final e = item.entry;
    final r = item.reading;
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
      ),
      onDismissed: (_) {
        if (e != null) {
          store.removeUsage(e.id);
        } else {
          store.removeReading(r!.id);
        }
      },
      child: ColoredBox(
        color: p.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconTile(
                icon: e != null
                    ? CupertinoIcons.bolt_fill
                    : CupertinoIcons.timer_fill,
                color: e != null ? p.accent : p.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e?.label ?? 'Meter reading',
                        style: TextStyle(fontSize: 17, color: p.label)),
                    Text(
                        e != null
                            ? '${trimNumber(e.watts)} W × ${trimNumber(e.hours)} h'
                            : formatTime(r!.time),
                        style: TextStyle(fontSize: 13, color: p.secondary)),
                  ],
                ),
              ),
              Text(formatKwh(e?.kwh ?? r!.kwh),
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
