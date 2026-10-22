import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
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
    final p = Palette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: ListenableBuilder(
        listenable: store,
        // Pages are created inside the builder so they rebuild on every change.
        builder: (context, _) => switch (_index) {
          0 => DashboardPage(store: store),
          1 => HistoryPage(store: store),
          _ => SettingsPage(store: store),
        },
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: p.card.withValues(alpha: 0.94),
        activeColor: p.accentText,
        inactiveColor: p.secondary,
        border: Border(top: BorderSide(color: p.separator, width: 0.5)),
        // Filled glyphs for every tab; the selected one is tinted orange.
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bolt_fill),
            label: 'Usage',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock_fill),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear_alt_fill),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
