import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/case_repository.dart';
import 'data/game_backend.dart';
import 'data/local_backend.dart';
import 'data/supabase_backend.dart';
import 'l10n/app_localizations.dart';
import 'screens/case_screen.dart';
import 'state/game_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final GameBackend backend;
  if (AppConfig.hasBackend) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    backend = SupabaseGameBackend(Supabase.instance.client);
  } else {
    debugPrint('SUPABASE_URL / SUPABASE_ANON_KEY not set: running in local mode (assets/cases.json).');
    backend = LocalGameBackend(loadCases: const AssetCaseRepository().loadCases, prefs: prefs);
  }

  final controller = GameController(backend: backend, prefs: prefs)..load();
  runApp(DailyCaseApp(controller: controller));
}

const appLocale = Locale('pl');

class DailyCaseApp extends StatelessWidget {
  const DailyCaseApp({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: CaseScreen(controller: controller),
    );
  }
}
