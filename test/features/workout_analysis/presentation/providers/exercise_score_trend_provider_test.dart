import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_score_trend_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'trend provider keeps score samples within one exercise context',
    () async {
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
            averageScore: 95,
          ),
          buildWorkoutSession(
            id: 'squat-2',
            startedAt: DateTime(2024, 1, 3, 9),
            exerciseType: 'squat',
            averageScore: 80,
          ),
          buildWorkoutSession(
            id: 'plank-hold',
            startedAt: DateTime(2024, 1, 4, 9),
            exerciseType: 'plank',
            analysisKind: 'hold',
            totalReps: 0,
            averageScore: 0,
            bestScore: 0,
          ),
        ],
        source: UserSessionsSnapshotSource.real,
      );
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
      );
      addTearDown(container.dispose);

      final squat = await container.read(
        exerciseScoreTrendProvider(ExerciseType.squat).future,
      );
      final pushUp = await container.read(
        exerciseScoreTrendProvider(ExerciseType.pushUp).future,
      );
      final plank = await container.read(
        exerciseScoreTrendProvider(ExerciseType.plank).future,
      );

      expect(squat.exercise, ExerciseType.squat);
      expect(
        squat.samples.map((sample) => sample.score).toList(growable: false),
        <double>[70, 80],
      );
      expect(
        pushUp.samples.map((sample) => sample.score).toList(growable: false),
        <double>[95],
      );
      expect(plank.samples, isEmpty);
      expect(plank.hasRealData, isFalse);
    },
  );

  test(
    'non-real snapshots never expose demo score samples as user truth',
    () async {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => const UserSessionsSnapshot(
              sessions: [],
              source: UserSessionsSnapshotSource.error,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final trend = await container.read(
        exerciseScoreTrendProvider(ExerciseType.squat).future,
      );

      expect(trend.samples, isEmpty);
      expect(trend.hasRealData, isFalse);
    },
  );
}
