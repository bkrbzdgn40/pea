import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/theme/app_theme.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/settings_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('groups existing settings into the roadmap sections', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    expect(find.text('Analiz deneyimi'), findsOneWidget);
    expect(find.text('Sesli koç'), findsOneWidget);
    expect(find.text('Geri bildirim'), findsOneWidget);

    await _scrollTo(tester, find.text('Kamera'));
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Kamera tercihi'), findsOneWidget);

    await _scrollTo(tester, find.text('Dil ve görünüm'));
    expect(find.text('Dil ve görünüm'), findsOneWidget);
    expect(find.text('Uygulama dili'), findsOneWidget);

    await _scrollTo(tester, find.text('Gelişmiş analiz ayarları'));
    expect(find.text('Gelişmiş analiz ayarları'), findsOneWidget);
    expect(find.text('Görüntü kalitesi'), findsOneWidget);

    await _scrollTo(tester, find.text('Veri ve hesap'));
    expect(find.text('Veri ve hesap'), findsOneWidget);

    await _scrollTo(tester, find.text('Tehlikeli işlemler'));
    expect(find.text('Tehlikeli işlemler'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('switches Settings copy from Turkish to English', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    final languageRow = find.byKey(
      const ValueKey<String>('settings-language-dropdown'),
    );
    await _scrollTo(tester, languageRow);
    final dropdown = find.descendant(
      of: languageRow,
      matching: find.byType(DropdownButton<AppLanguage>),
    );

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İngilizce').last);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Language and appearance'));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language and appearance'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
  });

  testWidgets('updates and persists live feedback controls', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    final voiceRow = find.byKey(
      const ValueKey<String>('settings-voice-coach-switch'),
    );
    final voiceSwitch = find.descendant(
      of: voiceRow,
      matching: find.byType(Switch),
    );
    await tester.tap(voiceSwitch);
    await tester.pumpAndSettle();

    final frequencyRow = find.byKey(
      const ValueKey<String>('settings-feedback-frequency-dropdown'),
    );
    await _scrollTo(tester, frequencyRow);
    final frequencyDropdown = find.descendant(
      of: frequencyRow,
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

  testWidgets('deletes all history only after confirmation', (
    WidgetTester tester,
  ) async {
    final sessions = TestSessionRepository();
    await _pumpSettings(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(sessions),
      ],
    );

    final action = find.byKey(
      const ValueKey<String>('settings-delete-all-history'),
    );
    await _scrollTo(tester, action);
    final deleteButton = find.descendant(
      of: action,
      matching: find.text('Sil'),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-all-history')),
    );
    await tester.pumpAndSettle();

    expect(sessions.deletedAllOwnerIds, ['owner-1']);
    expect(find.text('Tüm antrenman geçmişi silindi.'), findsOneWidget);
  });

  testWidgets('supports 320 px width with 200 percent text scale', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpSettings(tester, textScaler: const TextScaler.linear(2));

    await _scrollTo(
      tester,
      find.byKey(const ValueKey<String>('settings-delete-account')),
    );

    expect(find.text('Hesabı ve Verileri Sil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
  TextScaler textScaler = const TextScaler.linear(1),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          final settingsState = ref.watch(settingsControllerProvider);
          final language =
              settingsState.valueOrNull?.language ?? AppLanguage.turkish;

          return MaterialApp(
            theme: AppTheme.dark,
            locale: Locale(language.languageCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
            home: const SettingsScreen(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
