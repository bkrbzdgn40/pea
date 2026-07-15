import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_summary_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets('renders summary values from the completed workout session', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-1',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 12,
      averageScore: 89.6,
      bestScore: 95,
      durationSec: 65,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(find.text('Squat özeti'), findsOneWidget);
    expect(find.text('Toplam tekrar'), findsOneWidget);
    expect(find.text('Ortalama skor'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('1:05'), 200);

    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets(
    'renders the missing-session empty state when session is absent',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const WorkoutSummaryScreen(),
        overrides: [completedSessionProvider.overrideWith((ref) => null)],
      );
      await tester.pump();

      expect(find.text('Oturum verisi bulunamadı.'), findsOneWidget);
    },
  );

  testWidgets('keeps the explicit home navigation behavior', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-1',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 12,
      averageScore: 89.6,
      bestScore: 95,
      durationSec: 65,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [
        completedSessionProvider.overrideWith((ref) => session),
        homeDashboardProvider.overrideWith((ref) => _dashboardData()),
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

    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Workout Analysis'), findsOneWidget);
  });
}

HomeDashboardData _dashboardData() {
  return const HomeDashboardData(
    totalAnalyses: 4,
    averageScore: 86,
    thisWeekCount: 2,
    bestScore: 91,
    scoreTrend: [
      ScoreTrendPoint(label: 'Pzt', score: 82),
      ScoreTrendPoint(label: 'Sal', score: 86),
    ],
    exerciseDistribution: [
      ExerciseDistributionItem(label: 'Squat', value: 100),
    ],
    source: HomeDashboardSource.real,
  );
}
