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
    return MaterialApp(
      title: 'Wattly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(store: store),
    );
  }
}
