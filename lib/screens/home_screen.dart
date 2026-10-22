import 'package:flutter/material.dart';

import '../store.dart';
import 'add_usage_sheet.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final WattlyStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Wattly')),
      body: ListenableBuilder(
        listenable: store,
        // Pages are created inside the builder so they rebuild on every change.
        builder: (context, _) => switch (_index) {
          0 => DashboardPage(store: store),
          1 => HistoryPage(store: store),
          _ => SettingsPage(store: store),
        },
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddUsageSheet(context, store),
              icon: const Icon(Icons.add),
              label: const Text('Log usage'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}
