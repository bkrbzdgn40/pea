import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

      expect(data.totalAnalyses, 10);
      expect(data.averageScore, 50);
      expect(data.bestScore, 90);
      expect(
        data.scoreTrend.map((point) => point.score).toList(growable: false),
        <double>[30, 40, 50, 60, 70, 80, 90],
      );
    },
  );
}
