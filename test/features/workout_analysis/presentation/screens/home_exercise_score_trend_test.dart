import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/score_trend_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets('Home mini trend uses the selected exercise context', (tester) async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'squat-1',
          startedAt: DateTime(2024, 1, 1, 9),
          exerciseType: 'squat',
          averageScore: 70,
        ),
        buildWorkoutSession(
          id: 'push-1',
          startedAt: DateTime(2024, 1, 2, 9),
          exerciseType: 'push_up',
          averageScore: 99,
        ),
        buildWorkoutSession(
          id: 'squat-2',
          startedAt: DateTime(2024, 1, 3, 9),
          exerciseType: 'squat',
          averageScore: 80,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
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
    await tester.pumpAndSettle();

    expect(find.text('Squat Form Skoru Trendi'), findsOneWidget);
    expect(find.text('Push-up Form Skoru Trendi'), findsNothing);

    await tester.tap(find.text('Detayı Gör'));
    await tester.pumpAndSettle();

    expect(find.byType(ScoreTrendDetailScreen), findsOneWidget);
    expect(find.text('Squat Form Skoru Trendi'), findsAtLeastNWidgets(1));
  });

  testWidgets('Home does not show a form-score trend for hold-only history', (
    tester,
  ) async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'plank-hold',
          startedAt: DateTime(2024, 1, 1, 9),
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
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
    await tester.pumpAndSettle();

    expect(find.textContaining('Form Skoru Trendi'), findsNothing);
  });
}
