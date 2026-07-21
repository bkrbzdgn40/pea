import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/settings_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('switches Settings copy from Turkish to English', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final settingsState = ref.watch(settingsControllerProvider);
            final language =
                settingsState.valueOrNull?.language ?? AppLanguage.turkish;

            return MaterialApp(
              locale: Locale(language.languageCode),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const SettingsScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Uygulama dili'), findsOneWidget);
    expect(find.text('Türkçe'), findsWidgets);
    expect(find.text('Görüntü kalitesi'), findsOneWidget);
    expect(find.text('Ön kamera'), findsWidgets);

    await tester.tap(find.byType(DropdownButton<AppLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İngilizce').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Image quality'), findsOneWidget);
    expect(find.text('Front camera'), findsWidgets);
  });
}
