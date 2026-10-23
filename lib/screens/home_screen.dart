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

  /// Tabs the student has opened so far. The others aren't built until needed.
  final Set<int> _opened = {0};

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = Palette.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      // When the keyboard opens (the Log usage sheet, the price field), don't
      // re-lay-out the whole page behind it on every frame of the animation;
      // the sheet makes room for the keyboard itself.
      resizeToAvoidBottomInset: false,
      // The tabs stay alive side by side (so each keeps its scroll position and
      // choices, e.g. Usage remembers "Week"); only the visible one is shown.
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < 3; i++)
            if (_opened.contains(i))
              _TabPage(
                key: ValueKey(i),
                store: store,
                active: i == _index,
                builder: (context) => switch (i) {
                  0 => DashboardPage(store: store),
                  1 => HistoryPage(store: store),
                  _ => SettingsPage(store: store),
                },
              ),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          _index = i;
          _opened.add(i);
        }),
        // Opaque, like the title bars: no per-frame blur behind it.
        backgroundColor: p.card,
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

/// One tab's page. It stays alive while hidden, but only rebuilds when it is
/// showing: a change made while it is hidden just marks it out of date, and it
/// catches up the moment the student comes back to it.
class _TabPage extends StatefulWidget {
  const _TabPage({
    super.key,
    required this.store,
    required this.active,
    required this.builder,
  });

  final WattlyStore store;
  final bool active;
  final WidgetBuilder builder;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  Widget? _content;
  int _builtRevision = -1;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (widget.active && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the page only when it is showing and the data has changed since
    // it was last built (the store's revision says so, even for changes that
    // didn't notify). While hidden, hand back the very same widget so Flutter
    // skips the whole subtree.
    if (_content == null ||
        (widget.active && _builtRevision != widget.store.revision)) {
      _content = widget.builder(context);
      _builtRevision = widget.store.revision;
    }
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        // A hidden page must not keep keyboard focus (e.g. a half-typed field).
        child: ExcludeFocus(
          excluding: !widget.active,
          child: _content!,
        ),
      ),
    );
  }
}
