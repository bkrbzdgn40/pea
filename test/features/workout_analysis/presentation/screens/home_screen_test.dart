import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets(
    'renders truthful universal metrics without global score surfaces',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const HomeScreen(),
        overrides: [
          homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
          goalsProvider.overrideWith(
            (ref) => GoalsState(
              source: GoalsDataSource.real,
              goals: const [
                WorkoutGoal(
                  id: 'weekly_analysis_count',
                  title: 'Haftalik 5 analiz',
                  targetValue: 5,
                  currentValue: 3,
                  unit: 'analiz',
                  description: 'Bu hafta en az 5 canli analiz tamamla.',
                  isCompleted: false,
                ),
              ],
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) => AchievementsState(
              source: AchievementsDataSource.real,
              achievements: const [
                Achievement(
                  id: 'first_analysis',
                  title: 'Ilk Analiz',
                  description: 'Ilk canli analiz oturumunu tamamladin.',
                  isUnlocked: true,
                  progress: 1,
                  requirementText: '1 analiz tamamla',
                ),
              ],
            ),
          ),
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        ],
      );
      await tester.pump();

      expect(find.text('Plank analizine başla'), findsOneWidget);
      expect(find.text('Seçili hareket: Plank'), findsOneWidget);
      expect(find.text('Toplam Analiz'), findsOneWidget);
      expect(find.text('Bu Hafta'), findsOneWidget);
      expect(find.text('Ortalama Skor'), findsNothing);
      expect(find.text('En İyi Skor'), findsNothing);
      expect(find.text('Skor Trendi'), findsNothing);
      expect(find.text('Haftalık Hedef'), findsOneWidget);
      expect(find.text('Başarılar'), findsOneWidget);
      expect(find.text('Planlı Antrenman'), findsOneWidget);
      expect(find.text('Değerlendirme'), findsOneWidget);
    },
  );

  testWidgets(
    'does not present zero score as poor performance for hold-only history',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const HomeScreen(),
        overrides: [
          homeDashboardProvider.overrideWith((ref) => _holdOnlyDashboardData()),
          goalsProvider.overrideWith(
            (ref) => const GoalsState(
              source: GoalsDataSource.real,
              goals: <WorkoutGoal>[],
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) => const AchievementsState(
              source: AchievementsDataSource.real,
              achievements: <Achievement>[],
            ),
          ),
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        ],
      );
      await tester.pump();

      expect(find.text('Toplam Analiz'), findsOneWidget);
      expect(find.text('Bu Hafta'), findsOneWidget);
      expect(find.text('4'), findsAtLeastNWidgets(1));
      expect(find.text('Ortalama Skor'), findsNothing);
      expect(find.text('En İyi Skor'), findsNothing);
      expect(find.text('Skor Trendi'), findsNothing);
    },
  );

  testWidgets('keeps truthful empty-state copy without promising scores', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) =>
              HomeDashboardData.fallback(source: HomeDashboardSource.empty),
        ),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.empty,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.empty,
            achievements: <Achievement>[],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.text(
        'İlk analizini tamamladığında oturumların ve haftalık özetin burada görünür.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'İlk analizini tamamladığında skorların, tekrarların ve haftalık özetin burada görünür.',
      ),
      findsNothing,
    );
    expect(find.text('Skor Trendi'), findsNothing);
  });

  testWidgets(
    'keeps drawer-owned destinations out of the Home action surface',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const HomeScreen(),
        overrides: [
          homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
          goalsProvider.overrideWith(
            (ref) => const GoalsState(
              source: GoalsDataSource.real,
              goals: <WorkoutGoal>[],
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) => const AchievementsState(
              source: AchievementsDataSource.real,
              achievements: <Achievement>[],
            ),
          ),
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        ],
      );
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));

      expect(appBar.actions, isNull);
      expect(find.text('Hareketi Değiştir'), findsNothing);
      expect(find.byKey(const ValueKey('home-primary-action')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-planned-workout-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-assessment-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets('preserves the 12px action icon surface radius on HomeScreen', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.real,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.real,
            achievements: <Achievement>[],
          ),
        ),
      ],
    );
    await tester.pump();

    final playIconSurface = find.ancestor(
      of: find.byIcon(Icons.play_arrow_rounded),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }

        final decoration = widget.decoration;
        final constraints = widget.constraints;
        return constraints?.minWidth == 44 &&
            constraints?.maxWidth == 44 &&
            constraints?.minHeight == 44 &&
            constraints?.maxHeight == 44 &&
            decoration is BoxDecoration &&
            decoration.borderRadius == BorderRadius.circular(AppRadii.small);
      }),
    );

    expect(playIconSurface, findsOneWidget);
  });

  testWidgets('uses a single-column task flow in portrait', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.real,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.real,
            achievements: <Achievement>[],
          ),
        ),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-portrait-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-wide-layout')), findsNothing);

    final taskTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-task-panel')),
    );
    final progressTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-progress-panel')),
    );
    expect(taskTop.dy, lessThan(progressTop.dy));
  });

  testWidgets('uses task and progress panels side by side in landscape', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.real,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.real,
            achievements: <Achievement>[],
          ),
        ),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-wide-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-portrait-layout')), findsNothing);

    final taskTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('home-task-panel')),
    );
    final progressTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('home-progress-panel')),
    );
    expect(taskTopLeft.dx, lessThan(progressTopLeft.dx));
    expect((taskTopLeft.dy - progressTopLeft.dy).abs(), lessThan(1));
  });

  testWidgets('keeps compact portrait usable with 200 percent text scaling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: const HomeScreen(),
      ),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) =>
              HomeDashboardData.fallback(source: HomeDashboardSource.empty),
        ),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.empty,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.empty,
            achievements: <Achievement>[],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-portrait-layout')), findsOneWidget);

    final plannedTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-planned-workout-action')),
    );
    final assessmentTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-assessment-action')),
    );
    expect(plannedTop.dy, lessThan(assessmentTop.dy));
  });

  testWidgets('translates the primary Home surface to English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
        goalsProvider.overrideWith(
          (ref) => GoalsState(
            source: GoalsDataSource.real,
            goals: const [
              WorkoutGoal(
                id: 'weekly_analysis_count',
                title: 'Haftalık 5 analiz',
                targetValue: 5,
                currentValue: 3,
                unit: 'analiz',
                description: 'Bu hafta en az 5 canlı analiz tamamla.',
                isCompleted: false,
              ),
            ],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
            source: AchievementsDataSource.real,
            achievements: const [
              Achievement(
                id: 'first_analysis',
                title: 'İlk Analiz',
                description: 'İlk canlı analiz oturumunu tamamladın.',
                isUnlocked: true,
                progress: 1,
                requirementText: '1 analiz tamamla',
              ),
            ],
          ),
        ),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.pushUp),
      ],
    );
    await tester.pump();

    expect(find.text('Workout Analysis'), findsOneWidget);
    expect(find.text('Start Push-up analysis'), findsOneWidget);
    expect(find.text('Selected exercise: Push-up'), findsOneWidget);
    expect(find.text('Exercise Guide'), findsNothing);
    expect(find.text('Session History'), findsNothing);
    expect(find.text('Planned Workout'), findsOneWidget);
    expect(find.text('Assessment'), findsOneWidget);
    expect(find.text('Weekly Goal'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('First Analysis'), findsOneWidget);
    expect(find.text('1 analiz tamamla'), findsNothing);
    expect(find.text('Complete 1 analysis'), findsOneWidget);
  });
}

HomeDashboardData _mixedDashboardData() {
  return const HomeDashboardData(
    totalAnalyses: 8,
    averageScore: 87,
    thisWeekCount: 3,
    bestScore: 93,
    scoreTrend: [
      ScoreTrendPoint(label: 'Pzt', score: 80),
      ScoreTrendPoint(label: 'Sal', score: 85),
      ScoreTrendPoint(label: 'Çar', score: 90),
    ],
    exerciseDistribution: [
      ExerciseDistributionItem(label: 'Plank', value: 25),
      ExerciseDistributionItem(label: 'Squat', value: 40),
      ExerciseDistributionItem(label: 'Push-up', value: 35),
    ],
    source: HomeDashboardSource.real,
  );
}

HomeDashboardData _holdOnlyDashboardData() {
  return const HomeDashboardData(
    totalAnalyses: 4,
    averageScore: 0,
    thisWeekCount: 2,
    bestScore: 0,
    scoreTrend: <ScoreTrendPoint>[],
    exerciseDistribution: [
      ExerciseDistributionItem(label: 'Plank', value: 50),
      ExerciseDistributionItem(label: 'Hollow Hold', value: 50),
    ],
    source: HomeDashboardSource.real,
  );
}
