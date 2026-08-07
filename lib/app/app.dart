import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/screens/auth_bootstrap_gate.dart';
import '../features/workout_analysis/presentation/providers/settings_provider.dart';
import 'localization/app_localizations.dart';
import 'navigation/app_routes.dart';
import 'theme/app_theme.dart';

class PoseAnalysisApp extends ConsumerWidget {
  const PoseAnalysisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final language = settingsState.valueOrNull?.language ?? AppLanguage.turkish;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PEA',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: Locale(language.languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: AppRoutes.builders,
      home: const AuthBootstrapGate(),
    );
  }
}
