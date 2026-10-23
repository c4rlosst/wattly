import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(WattlyApp(store: WattlyStore(prefs)));
}

/// Lets a mouse drag-scroll lists, like a finger does. The app is phone-shaped
/// even on a PC, so dragging should feel natural there too.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

class WattlyApp extends StatefulWidget {
  const WattlyApp({super.key, required this.store});

  final WattlyStore store;

  @override
  State<WattlyApp> createState() => _WattlyAppState();
}

class _WattlyAppState extends State<WattlyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Coming back (maybe on a new day): recompute "today" and friends.
      widget.store.refresh();
    } else {
      // Going to the background or closing: write anything still unsaved.
      widget.store.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    // Only rebuilds when Light/Dark/Auto changes, not on every logged entry.
    return ValueListenableBuilder<Appearance>(
      valueListenable: store.appearanceListenable,
      builder: (context, appearance, _) => MaterialApp(
        title: 'Wattly',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        // Light unless the student picks Dark or Auto in Settings.
        themeMode: switch (appearance) {
          Appearance.light => ThemeMode.light,
          Appearance.dark => ThemeMode.dark,
          Appearance.system => ThemeMode.system,
        },
        scrollBehavior: const _AppScrollBehavior(),
        builder: (context, child) =>
            PhoneColumn(child: child ?? const SizedBox.shrink()),
        home: HomeScreen(store: store),
      ),
    );
  }
}
