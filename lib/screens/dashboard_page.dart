import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../store.dart';

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
    final theme = Theme.of(context);
    final from = periodStart(_period, DateTime.now());

    final estimated = store.estimatedKwhSince(from);
    final estimatedCost = store.estimatedCostSince(from);
    final metered = store.meteredKwhSince(from);

    // Prefer the real meter when it has data; otherwise fall back to estimates.
    final headlineKwh = metered ?? estimated;
    final headlineCost = metered != null
        ? metered * store.ratePerKwh
        : estimatedCost;
    final headlineSource = metered != null ? 'From meter readings' : 'Estimated from your devices';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        SegmentedButton<Period>(
          segments: [
            for (final p in Period.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_period.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text(
                  formatKwh(headlineKwh),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  store.ratePerKwh > 0
                      ? '≈ ${formatMoney(store.currency, headlineCost)}'
                      : 'Set your rate in Settings to see cost',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 12),
                Text(headlineSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Estimated',
                value: formatKwh(estimated),
                subtitle: store.ratePerKwh > 0
                    ? formatMoney(store.currency, estimatedCost)
                    : 'devices × hours',
              ),
            ),
            Expanded(
              child: _StatCard(
                title: 'Metered',
                value: metered == null ? '—' : formatKwh(metered),
                subtitle: metered == null
                    ? 'needs 2 readings'
                    : store.ratePerKwh > 0
                        ? formatMoney(
                            store.currency, metered * store.ratePerKwh)
                        : 'from meter',
              ),
            ),
          ],
        ),
        if (store.latestReading != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: Text('Meter: ${formatKwh(store.latestReading!.kwh)}'),
              subtitle: Text(
                  'Last reading ${formatDateTime(store.latestReading!.time)}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title, required this.value, required this.subtitle});

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
