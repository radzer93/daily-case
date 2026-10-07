import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/case_repository.dart';
import 'screens/case_screen.dart';
import 'state/game_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final controller = await GameController.create(
    repository: const AssetCaseRepository(),
    prefs: prefs,
  );
  runApp(DailyCaseApp(controller: controller));
}

class DailyCaseApp extends StatelessWidget {
  const DailyCaseApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprawa Dnia',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: CaseScreen(controller: controller),
    );
  }
}
