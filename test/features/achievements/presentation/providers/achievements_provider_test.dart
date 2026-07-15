import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/achievements/presentation/data/demo_achievements.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'real snapshot omits demo streak achievement and uses canonical score best',
    () async {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => UserSessionsSnapshot(
              sessions: [
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
                  id: 'range-1',
                  startedAt: DateTime(2024, 1, 3, 9),
                  totalReps: 12,
                  averageScore: 91,
                  bestScore: 91,
                ),
              ],
              source: UserSessionsSnapshotSource.real,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);
      final scoreAchievement = _achievementById(
        state.achievements,
        'score_90_plus',
      );

      expect(state.source, AchievementsDataSource.real);
      expect(
        state.achievements.any(
          (achievement) => achievement.id == 'seven_day_streak',
        ),
        isFalse,
      );
      expect(scoreAchievement.isUnlocked, isTrue);
    },
  );

  test('hold-only real snapshot keeps score achievement locked', () async {
    final container = ProviderContainer(
      overrides: [
        userSessionsSnapshotProvider.overrideWith(
          (ref) async => UserSessionsSnapshot(
            sessions: [
              buildWorkoutSession(
                id: 'hold-1',
                startedAt: DateTime(2024, 1, 2, 9),
                exerciseType: 'plank',
                analysisKind: 'hold',
                totalReps: 0,
                averageScore: 0,
                bestScore: 0,
              ),
            ],
            source: UserSessionsSnapshotSource.real,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(achievementsProvider.future);
    final scoreAchievement = _achievementById(
      state.achievements,
      'score_90_plus',
    );

    expect(scoreAchievement.isUnlocked, isFalse);
    expect(scoreAchievement.progress, 0);
  });

  test('fallback snapshots preserve demo achievements', () async {
    for (final source in [
      UserSessionsSnapshotSource.noUser,
      UserSessionsSnapshotSource.empty,
      UserSessionsSnapshotSource.error,
    ]) {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async =>
                UserSessionsSnapshot(sessions: const [], source: source),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);

      expect(state.isFallback, isTrue);
      expect(
        state.achievements
            .map((achievement) => achievement.id)
            .toList(growable: false),
        demoAchievements
            .map((achievement) => achievement.id)
            .toList(growable: false),
      );
    }
  });
}

Achievement _achievementById(List<Achievement> achievements, String id) {
  return achievements.singleWhere((achievement) => achievement.id == id);
}
