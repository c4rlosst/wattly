import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'store.dart';

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
    return MaterialApp(
      title: 'Wattly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF5A623),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFF5A623),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeScreen(store: store),
    );
  }
}
