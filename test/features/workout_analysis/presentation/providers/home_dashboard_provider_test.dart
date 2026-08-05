import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'real snapshot uses canonical score eligibility and the last seven scores',
    () async {
      final sessions = [
        for (var index = 0; index < 9; index++)
          buildWorkoutSession(
            id: 'range-$index',
            startedAt: DateTime(2024, 1, index + 1, 9),
            totalReps: 10,
            averageScore: (index + 1) * 10,
          ),
        buildWorkoutSession(
          id: 'hold-1',
          startedAt: DateTime(2024, 1, 5, 18),
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: sessions,
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(homeDashboardProvider.future);

      expect(data.source, HomeDashboardSource.real);
      expect(data.totalAnalyses, 10);
      expect(data.averageScore, 50);
      expect(data.bestScore, 90);
      expect(data.latestSession?.id, 'range-8');
      expect(
        data.scoreTrend.map((point) => point.score).toList(growable: false),
        <double>[30, 40, 50, 60, 70, 80, 90],
      );
    },
  );

  test(
    'groups exercises after the top four into a truthful remainder',
    () async {
      final sessions = <WorkoutSession>[
        for (var index = 0; index < 5; index++)
          buildWorkoutSession(
            id: 'squat-$index',
            startedAt: DateTime(2024, 2, index + 1),
            exerciseType: 'squat',
          ),
        for (var index = 0; index < 4; index++)
          buildWorkoutSession(
            id: 'plank-$index',
            startedAt: DateTime(2024, 3, index + 1),
            exerciseType: 'plank',
            analysisKind: 'hold',
          ),
        for (var index = 0; index < 3; index++)
          buildWorkoutSession(
            id: 'push-up-$index',
            startedAt: DateTime(2024, 4, index + 1),
            exerciseType: 'push_up',
          ),
        for (var index = 0; index < 2; index++)
          buildWorkoutSession(
            id: 'lunge-$index',
            startedAt: DateTime(2024, 5, index + 1),
            exerciseType: 'lunge',
          ),
        buildWorkoutSession(
          id: 'sit-up',
          startedAt: DateTime(2024, 6, 1),
          exerciseType: 'sit_up',
        ),
        buildWorkoutSession(
          id: 'crunch',
          startedAt: DateTime(2024, 6, 2),
          exerciseType: 'crunch',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: sessions,
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final distribution = (await container.read(
        homeDashboardProvider.future,
      )).exerciseDistribution;

      expect(distribution, hasLength(5));
      expect(distribution.take(4).map((item) => item.exerciseId), <String?>[
        'squat',
        'plank',
        'push_up',
        'lunge',
      ]);
      expect(distribution.last.isRemainder, isTrue);
      expect(distribution.last.groupedExerciseCount, 2);
      expect(distribution.last.exerciseId, isNull);
      expect(
        distribution.fold<double>(0, (sum, item) => sum + item.value),
        100,
      );
      expect(
        distribution.every((item) => item.value == item.value.roundToDouble()),
        isTrue,
      );
    },
  );

  test(
    'does not create a remainder when four or fewer exercises exist',
    () async {
      final sessions = <WorkoutSession>[
        buildWorkoutSession(
          id: 'squat',
          startedAt: DateTime(2024, 1, 1),
          exerciseType: 'squat',
        ),
        buildWorkoutSession(
          id: 'plank',
          startedAt: DateTime(2024, 1, 2),
          exerciseType: 'plank',
          analysisKind: 'hold',
        ),
        buildWorkoutSession(
          id: 'push-up',
          startedAt: DateTime(2024, 1, 3),
          exerciseType: 'push_up',
        ),
        buildWorkoutSession(
          id: 'lunge',
          startedAt: DateTime(2024, 1, 4),
          exerciseType: 'lunge',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: sessions,
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final distribution = (await container.read(
        homeDashboardProvider.future,
      )).exerciseDistribution;

      expect(distribution, hasLength(4));
      expect(distribution.where((item) => item.isRemainder), isEmpty);
      expect(
        distribution.fold<double>(0, (sum, item) => sum + item.value),
        100,
      );
    },
  );

  test('non-real snapshots never produce demo dashboard values', () async {
    final cases = <UserSessionsSnapshotSource, HomeDashboardSource>{
      UserSessionsSnapshotSource.noUser: HomeDashboardSource.noUser,
      UserSessionsSnapshotSource.empty: HomeDashboardSource.empty,
      UserSessionsSnapshotSource.error: HomeDashboardSource.error,
    };

    for (final entry in cases.entries) {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async =>
                UserSessionsSnapshot(sessions: const [], source: entry.key),
          ),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(homeDashboardProvider.future);

      expect(data.source, entry.value);
      expect(data.hasRealData, isFalse);
      expect(data.totalAnalyses, 0);
      expect(data.averageScore, 0);
      expect(data.thisWeekCount, 0);
      expect(data.bestScore, 0);
      expect(data.scoreTrend, isEmpty);
      expect(data.exerciseDistribution, isEmpty);
      expect(data.latestSession, isNull);
    }
  });
}
