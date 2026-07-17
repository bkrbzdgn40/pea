import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'real snapshot keeps weekly reps current-week scoped and excludes demo goal mixing',
    () async {
      final now = DateTime.now();
      final weekStart = startOfCurrentWeek(now);
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: [
                buildWorkoutSession(
                  id: 'current-squat',
                  startedAt: weekStart,
                  totalReps: 40,
                  averageScore: 80,
                ),
                buildWorkoutSession(
                  id: 'current-push-up',
                  startedAt: weekStart.add(const Duration(days: 1)),
                  exerciseType: 'push_up',
                  totalReps: 30,
                  averageScore: 100,
                ),
                buildWorkoutSession(
                  id: 'current-plank',
                  startedAt: weekStart.add(const Duration(days: 2)),
                  exerciseType: 'plank',
                  analysisKind: 'hold',
                  totalReps: 0,
                  averageScore: 0,
                  bestScore: 0,
                ),
                buildWorkoutSession(
                  id: 'previous-week',
                  startedAt: weekStart.subtract(const Duration(days: 1)),
                  totalReps: 150,
                  averageScore: 70,
                ),
              ],
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(goalsProvider.future);
      final weeklyRepGoal = _goalById(state.goals, 'total_reps_200');

      expect(state.source, GoalsDataSource.real);
      expect(weeklyRepGoal.currentValue, 70);
      expect(weeklyRepGoal.title, 'Haftalık 200 tekrar');
      expect(state.goals.any((goal) => goal.id == 'three_day_streak'), isFalse);
    },
  );

  test(
    'real snapshot uses canonical score average and excludes hold sessions',
    () async {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: [
                buildWorkoutSession(
                  id: 'range-1',
                  startedAt: DateTime(2024, 1, 1, 9),
                  totalReps: 10,
                  averageScore: 80,
                ),
                buildWorkoutSession(
                  id: 'hold-1',
                  startedAt: DateTime(2024, 1, 2, 9),
                  exerciseType: 'plank',
                  analysisKind: 'hold',
                  totalReps: 0,
                  averageScore: 0,
                  bestScore: 0,
                ),
                buildWorkoutSession(
                  id: 'range-2',
                  startedAt: DateTime(2024, 1, 3, 9),
                  totalReps: 12,
                  averageScore: 100,
                ),
              ],
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(goalsProvider.future);
      final averageGoal = _goalById(state.goals, 'average_score_85');

      expect(averageGoal.currentValue, closeTo(90, 0.001));
    },
  );

  test('non-real snapshots expose empty production goal states', () async {
    final cases = <UserSessionsSnapshotSource, GoalsDataSource>{
      UserSessionsSnapshotSource.noUser: GoalsDataSource.noUser,
      UserSessionsSnapshotSource.empty: GoalsDataSource.empty,
      UserSessionsSnapshotSource.error: GoalsDataSource.error,
    };

    for (final entry in cases.entries) {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: const [],
              source: entry.key,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(goalsProvider.future);

      expect(state.source, entry.value);
      expect(state.isFallback, isTrue);
      expect(state.goals, isEmpty);
    }
  });
}

WorkoutGoal _goalById(List<WorkoutGoal> goals, String id) {
  return goals.singleWhere((goal) => goal.id == id);
}
