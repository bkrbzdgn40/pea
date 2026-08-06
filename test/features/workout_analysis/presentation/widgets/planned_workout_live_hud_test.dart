import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/planned_workout_live_hud.dart';

void main() {
  testWidgets('uses a minimal planned HUD and reveals every metric on demand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var pauseCount = 0;
    var finishCount = 0;
    var showDetails = false;

    await tester.pumpWidget(
      _HudTestApp(
        child: StatefulBuilder(
          builder: (context, setState) => PlannedWorkoutLiveHudView(
            data: _repHudData(),
            topInset: 24,
            compact: false,
            isFinishing: false,
            showDetails: showDetails,
            showFinishAction: showDetails,
            onToggleDetails: () {
              setState(() => showDetails = !showDetails);
            },
            technicalDetails: const SizedBox(
              key: ValueKey<String>('test-planned-technical-details'),
            ),
            onPause: () => pauseCount += 1,
            onFinish: () => finishCount += 1,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('planned-workout-live-hud')),
      findsOneWidget,
    );
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('İyi tekrar'), findsOneWidget);
    expect(find.text('Hareket aralığı yeterli.'), findsOneWidget);
    expect(find.text('90'), findsNothing);
    expect(find.text('Tur 1/1 • Set 1/3'), findsNothing);
    expect(find.text('Ölçüm güveni: %96 · Güvenilir'), findsNothing);
    expect(find.text('Sağ bacak takip ediliyor'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('planned-workout-finish-button')),
      findsNothing,
    );
    expect(
      tester.widget<Text>(find.text('Hareket aralığı yeterli.')).overflow,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('live-hud-mode-toggle')),
    );
    await tester.pump();

    expect(find.text('90'), findsOneWidget);
    expect(find.text('Tur 1/1 • Set 1/3'), findsOneWidget);
    expect(find.text('1 / 5 tekrar'), findsOneWidget);
    expect(find.text('Ölçüm güveni: %96 · Güvenilir'), findsOneWidget);
    expect(find.text('Sağ bacak takip ediliyor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('test-planned-technical-details')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('live-pause-button')));
    await tester.tap(
      find.byKey(const ValueKey<String>('planned-workout-finish-button')),
    );

    expect(pauseCount, 1);
    expect(finishCount, 1);
  });

  testWidgets(
    'keeps the detailed planned side panel usable at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(280, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _HudTestApp(
          textScaler: const TextScaler.linear(2),
          child: PlannedWorkoutLiveHudView(
            data: _holdHudData(),
            topInset: 0,
            compact: true,
            isFinishing: false,
            sidePanel: true,
            showDetails: true,
            showFinishAction: true,
            onToggleDetails: () {},
            technicalDetails: const SizedBox(
              key: ValueKey<String>('test-planned-technical-details'),
              height: 40,
            ),
            onPause: () {},
            onFinish: () {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('planned-workout-side-panel-scroll')),
        findsOneWidget,
      );
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('0:18 / 0:30'), findsNWidgets(2));
      expect(find.text('0:22'), findsOneWidget);
      final primaryMetric = find.byKey(
        const ValueKey<String>('planned-workout-primary-metric'),
      );
      final timerIcon = tester.widget<Icon>(
        find.descendant(
          of: primaryMetric,
          matching: find.byIcon(Icons.timer_outlined),
        ),
      );
      final primaryCard = tester.widget<AnimatedContainer>(
        find.descendant(
          of: primaryMetric,
          matching: find.byType(AnimatedContainer),
        ),
      );
      final primaryDecoration = primaryCard.decoration! as BoxDecoration;
      expect(timerIcon.size, 16);
      expect(primaryDecoration.color, const Color(0xA6171D23));
      expect(primaryDecoration.boxShadow, isNotEmpty);
      expect(primaryDecoration.boxShadow!.length, greaterThan(2));
      expect(
        find.byKey(const ValueKey<String>('planned-workout-progress-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('planned-workout-feedback-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('test-planned-technical-details')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disables the detailed finish action while finishing', (
    tester,
  ) async {
    var finishCount = 0;

    await tester.pumpWidget(
      _HudTestApp(
        child: PlannedWorkoutLiveHudView(
          data: _repHudData(),
          topInset: 0,
          compact: false,
          isFinishing: true,
          showDetails: true,
          showFinishAction: true,
          onToggleDetails: () {},
          onPause: () {},
          onFinish: () => finishCount += 1,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('planned-workout-finish-button')),
      warnIfMissed: false,
    );

    expect(finishCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _HudTestApp extends StatelessWidget {
  const _HudTestApp({required this.child, this.textScaler});

  final Widget child;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, appChild) {
        final content = appChild!;
        if (textScaler == null) {
          return content;
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: content,
        );
      },
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: <Widget>[child]),
      ),
    );
  }
}

PlannedWorkoutLiveHudData _repHudData() {
  return const PlannedWorkoutLiveHudData(
    exerciseTitle: 'Squat',
    primaryLabel: 'Tekrar',
    primaryValue: '1 / 5',
    primaryIcon: Icons.repeat_rounded,
    secondaryLabel: 'Skor',
    secondaryValue: '90',
    secondaryTone: PlannedWorkoutHudTone.positive,
    progressLabel: 'Tur 1/1 • Set 1/3',
    progressValue: '1 / 5 tekrar',
    progress: 0.2,
    sideLabel: 'Sağ bacak takip ediliyor',
    feedbackTitle: 'İyi tekrar',
    feedbackMessage: 'Hareket aralığı yeterli.',
    feedbackMeasurementConfidenceLabel: 'Ölçüm güveni: %96 · Güvenilir',
    feedbackTone: PlannedWorkoutHudTone.positive,
    feedbackIcon: Icons.check_rounded,
  );
}

PlannedWorkoutLiveHudData _holdHudData() {
  return const PlannedWorkoutLiveHudData(
    exerciseTitle: 'Plank',
    primaryLabel: 'Tutuş',
    primaryValue: '0:18 / 0:30',
    primaryIcon: Icons.timer_outlined,
    secondaryLabel: 'En iyi',
    secondaryValue: '0:22',
    secondaryTone: PlannedWorkoutHudTone.positive,
    progressLabel: 'Tur 1/2 • Set 2/3',
    progressValue: '0:18 / 0:30',
    progress: 0.6,
    feedbackTitle: 'Tutuş',
    feedbackMessage: 'Pozisyonunu koru.',
    feedbackTone: PlannedWorkoutHudTone.positive,
    feedbackIcon: Icons.check_rounded,
  );
}
