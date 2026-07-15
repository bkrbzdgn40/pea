import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/guide_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets(
    'renders the real dashboard surface and selected exercise summary',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const HomeScreen(),
        overrides: [
          homeDashboardProvider.overrideWith((ref) => _realDashboardData()),
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
      expect(find.text('Haftalık Hedef'), findsOneWidget);
      expect(find.text('Başarılar'), findsOneWidget);
    },
  );

  testWidgets('keeps explicit guide navigation behavior on HomeScreen', (
    WidgetTester tester,
  ) async {
    final observer = RecordingNavigatorObserver();

    await pumpTestApp(
      tester,
      navigatorObservers: [observer],
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _realDashboardData()),
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
    await tester.pumpAndSettle();

    final pushCountBeforeTap = observer.pushCount;

    await tester.tap(find.text('Hareket Rehberi'));
    await tester.pumpAndSettle();

    expect(observer.pushCount, pushCountBeforeTap + 1);
    expect(find.byType(GuideScreen), findsOneWidget);
  });
}

HomeDashboardData _realDashboardData() {
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
      ExerciseDistributionItem(label: 'Plank', value: 60),
      ExerciseDistributionItem(label: 'Squat', value: 40),
    ],
    source: HomeDashboardSource.real,
  );
}
