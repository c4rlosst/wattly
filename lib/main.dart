import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(WattlyApp(store: WattlyStore(prefs)));
}

class WattlyApp extends StatelessWidget {
  const WattlyApp({super.key, required this.store});

  final WattlyStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'Wattly',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // Light unless the student picks Dark or Auto in Settings.
        themeMode: switch (store.appearance) {
          Appearance.light => ThemeMode.light,
          Appearance.dark => ThemeMode.dark,
          Appearance.system => ThemeMode.system,
        },
        home: HomeScreen(store: store),
      ),
    );
  }
}
