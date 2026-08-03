import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_ui_primitives.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/guide_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('renders guide discovery and exercise copy in English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GuideScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Exercise Guide'), findsOneWidget);
    expect(find.text('See the technique first'), findsOneWidget);
    expect(
      find.text(
        'A foundational movement for lower-body strength and knee-hip control.',
      ),
      findsOneWidget,
    );
    expect(find.text('Analysis active'), findsNothing);

    final squatDifficulty = tester.widget<AppStatusChip>(
      find.byKey(const ValueKey<String>('exercise-guide-difficulty-squat')),
    );
    expect(squatDifficulty.tone, AppStatusTone.caution);
  });

  testWidgets('colors difficulty badges by level', (tester) async {
    await pumpTestApp(
      tester,
      home: const GuideScreen(initialExercise: ExerciseType.plank),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final beginnerChip = tester.widget<AppStatusChip>(
      find.byKey(const ValueKey<String>('exercise-guide-difficulty-plank')),
    );
    expect(beginnerChip.tone, AppStatusTone.success);

    await pumpTestApp(
      tester,
      home: const GuideScreen(initialExercise: ExerciseType.hollowHold),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    final advancedChip = tester.widget<AppStatusChip>(
      find.byKey(
        const ValueKey<String>('exercise-guide-difficulty-hollow_hold'),
      ),
    );
    expect(advancedChip.tone, AppStatusTone.danger);
  });

  testWidgets('searches localized guide content', (tester) async {
    await pumpTestApp(
      tester,
      home: const GuideScreen(),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('guide-search-field')),
      'shoulder press',
    );
    await tester.pumpAndSettle();

    expect(find.text('Shoulder Press'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('opens a requested guide expanded', (tester) async {
    await pumpTestApp(
      tester,
      home: const GuideScreen(initialExercise: ExerciseType.shoulderPress),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('exercise-guide-card-shoulder_press')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Uses both elbows extending together as the primary repetition signal and counts a controlled press-and-return cycle.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('guide discovery survives compact large-text layouts', (
    tester,
  ) async {
    const configuration = PresentationTestConfiguration(
      viewport: PresentationTestViewport.compactPortrait,
      textScaleFactor: 2,
      name: 'guide-compact-large-text',
    );

    await pumpTestApp(
      tester,
      home: const GuideScreen(),
      locale: const Locale('en'),
      configuration: configuration,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('guide-search-field')),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });
}
