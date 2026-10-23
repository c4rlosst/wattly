import 'package:flutter/cupertino.dart';

import '../calc.dart';
import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_usage_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.store});

  final WattlyStore store;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Period _period = Period.month;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = Palette.of(context);
    final from = periodStart(_period, DateTime.now());
    final hasRate = store.ratePerKwh > 0;

    final estimated = store.estimatedKwhSince(from);
    final estimatedCost = store.estimatedCostSince(from);
    final metered = store.meteredKwhSince(from);

    // Prefer the real meter when it has data; otherwise fall back to estimates.
    final headlineKwh = metered ?? estimated;
    final headlineCost =
        metered != null ? metered * store.ratePerKwh : estimatedCost;
    final latest = store.latestReading;

    return CustomScrollView(
      // Each tab scrolls on its own; they must not share the route's controller.
      primary: false,
      slivers: [
        largeTitleBar(
          context,
          'Usage',
          leading: const BrandMark(),
          trailing: AddButton(
              onPressed: () => showAddUsageSheet(context, store)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.list(
            children: [
              Segmented<Period>(
                value: _period,
                options: const {
                  Period.today: 'Today',
                  Period.week: 'Week',
                  Period.month: 'Month',
                },
                onChanged: (v) => setState(() => _period = v),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_period.label.toUpperCase(),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: p.secondary)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(formatKwhValue(headlineKwh),
                            style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                                color: p.label,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                        const SizedBox(width: 6),
                        Text('kWh',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: p.secondary)),
                      ],
                    ),
                    Text(
                      hasRate
                          ? '≈ ${formatMoney(store.currency, headlineCost)}'
                          : 'Set your rate in Settings to see cost',
                      style: TextStyle(
                          fontSize: hasRate ? 20 : 15,
                          fontWeight: FontWeight.w600,
                          color: p.accentText),
                    ),
                    const SizedBox(height: 16),
                    UsageBars(buckets: store.bucketsFor(_period)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: metered != null ? p.green : p.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            metered != null
                                ? 'From meter readings'
                                : 'Estimated from your devices',
                            style:
                                TextStyle(fontSize: 13, color: p.secondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatTile(
                      title: 'Estimated',
                      value: formatKwhValue(estimated),
                      subtitle: hasRate
                          ? formatMoney(store.currency, estimatedCost)
                          : 'devices × hours',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      title: 'Metered',
                      value: metered == null ? '—' : formatKwhValue(metered),
                      subtitle: metered == null
                          ? 'needs 2 readings'
                          : hasRate
                              ? formatMoney(
                                  store.currency, metered * store.ratePerKwh)
                              : 'from meter',
                    ),
                  ),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 12),
                Group(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconTile(
                            icon: CupertinoIcons.timer_fill, color: p.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Meter',
                                  style: TextStyle(
                                      fontSize: 17, color: p.label)),
                              Text(
                                  'Last reading: ${whenLabel(latest.time, DateTime.now())}',
                                  style: TextStyle(
                                      fontSize: 13, color: p.secondary)),
                            ],
                          ),
                        ),
                        Text(formatKwh(latest.kwh),
                            style:
                                TextStyle(fontSize: 17, color: p.secondary)),
                      ],
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.title, required this.value, required this.subtitle});

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: p.secondary)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: p.label,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              if (value != '—') ...[
                const SizedBox(width: 4),
                Text('kWh',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: p.secondary)),
              ],
            ],
          ),
          Text(subtitle, style: TextStyle(fontSize: 13, color: p.secondary)),
        ],
      ),
    );
  }
}
