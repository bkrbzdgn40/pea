import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
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
    await _pumpSettings(tester);

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('Uygulama dili'), findsOneWidget);
    expect(find.text('Türkçe'), findsWidgets);
    expect(find.text('Canlı geri bildirim'), findsOneWidget);
    expect(find.text('Sesli koç'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<AppLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İngilizce').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Live feedback'), findsOneWidget);
    expect(find.text('Voice coach'), findsOneWidget);
  });

  testWidgets('updates and persists live feedback controls', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    final voiceSwitch = find.byKey(
      const ValueKey<String>('settings-voice-coach-switch'),
    );
    await tester.ensureVisible(voiceSwitch);
    await tester.tap(voiceSwitch);
    await tester.pumpAndSettle();

    final frequencyTile = find.byKey(
      const ValueKey<String>('settings-feedback-frequency-dropdown'),
    );
    await tester.ensureVisible(frequencyTile);
    final frequencyDropdown = find.descendant(
      of: frequencyTile,
      matching: find.byType(DropdownButton<FeedbackFrequency>),
    );
    await tester.tap(frequencyDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sık').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('settings.voiceCoachEnabled'), isFalse);
    expect(
      preferences.getString('settings.feedbackFrequency'),
      FeedbackFrequency.frequent.name,
    );
  });
}

Future<void> _pumpSettings(WidgetTester tester) async {
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
}
