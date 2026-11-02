import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../cycle_history.dart';
import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class CycleHistoryPage extends StatefulWidget {
  const CycleHistoryPage({super.key, required this.store});
  final WattlyStore store;

  @override
  State<CycleHistoryPage> createState() => _CycleHistoryPageState();
}

class _CycleHistoryPageState extends State<CycleHistoryPage> {
  int _revision = -1;
  int _today = -1;
  List<CycleSummary> _cycles = [];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final now = DateTime.now();
        if (_revision != store.revision || _today != dayNumber(now)) {
          _cycles = cycleHistory(
            store.entries,
            store.readings,
            now,
            resetDay: store.monthlyResetDay,
          );
          _revision = store.revision;
          _today = dayNumber(now);
        }
        final p = Palette.of(context);
        return Scaffold(
          backgroundColor: p.bg,
          body: CustomScrollView(
            primary: false,
            slivers: [
              largeTitleBar(
                context,
                'Cycles',
                leading: CupertinoNavigationBarBackButton(
                  color: p.accentText,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Resets on the ${ordinalDay(store.monthlyResetDay)}. '
                    'Cycles use your current reset day; changing it regroups your history.',
                    style: TextStyle(fontSize: 14, color: p.secondary),
                  ),
                ),
              ),
              if (_cycles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 44,
                            color: p.secondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No cycles yet',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: p.label,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Log a device or meter reading to start your cycle history.',
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: _cycles.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CycleCard(
                        cycle: _cycles[i],
                        previous: i + 1 < _cycles.length
                            ? _cycles[i + 1]
                            : null,
                        store: store,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.cycle,
    required this.previous,
    required this.store,
  });
  final CycleSummary cycle;
  final CycleSummary? previous;
  final WattlyStore store;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final amount = cycle.cost(store.ratePerKwh);
    final difference = previous == null
        ? null
        : cycle.differenceFrom(previous!);
    final source = cycle.usesMeter
        ? (cycle.fullMeterCoverage
              ? 'Meter readings'
              : 'Partial meter coverage')
        : cycle.entries.isNotEmpty
        ? 'Device estimate'
        : 'Not enough data';
    return Container(
      key: ValueKey('cycle-${cycle.start.toIso8601String()}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cycle.isCurrent ? 'Current cycle · In progress' : 'Past cycle',
            style: TextStyle(
              fontSize: 13,
              color: cycle.isCurrent ? p.accentText : p.secondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            cycleDateRange(cycle.start, cycle.end, showYear: true),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.label,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            cycle.kwh == null ? '— kWh' : formatKwh(cycle.kwh!),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: p.label,
            ),
          ),
          Text(source, style: TextStyle(fontSize: 14, color: p.secondary)),
          const SizedBox(height: 8),
          Text(
            amount == null
                ? 'Cost unavailable'
                : '≈ ${formatMoney(store.currency, amount)}',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: p.accentText,
            ),
          ),
          if (cycle.usesMeter)
            Text(
              'Estimated at your current rate',
              style: TextStyle(fontSize: 12, color: p.secondary),
            ),
          if (difference != null) ...[
            const SizedBox(height: 10),
            Text(
              difference.abs() < 0.000001
                  ? 'Same usage as the previous cycle'
                  : '${formatKwh(difference.abs())} ${difference > 0 ? 'more' : 'less'} than the previous cycle',
              style: TextStyle(fontSize: 13, color: p.secondary),
            ),
          ],
          const SizedBox(height: 14),
          if (cycle.readings.isNotEmpty) ...[
            Text(
              '${cycle.readings.length} meter ${cycle.readings.length == 1 ? 'reading' : 'readings'}',
              style: TextStyle(fontSize: 13, color: p.secondary),
            ),
            if (cycle.usesMeter)
              Text(
                '${formatKwh(cycle.readings.first.kwh)} → ${formatKwh(cycle.readings.last.kwh)}',
                style: TextStyle(fontSize: 13, color: p.secondary),
              ),
            Text(
              '${formatDateTime(cycle.readings.first.time)} – ${formatDateTime(cycle.readings.last.time)}',
              style: TextStyle(fontSize: 12, color: p.secondary),
            ),
          ],
          if (cycle.meterDecreased)
            Text(
              'Meter decreased during this cycle. Check the readings.',
              style: TextStyle(fontSize: 13, color: p.accentText),
            ),
          if (cycle.entries.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${cycle.entries.length} device ${cycle.entries.length == 1 ? 'log' : 'logs'} · ${formatKwh(cycle.estimatedKwh)} estimated',
              style: TextStyle(fontSize: 13, color: p.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
