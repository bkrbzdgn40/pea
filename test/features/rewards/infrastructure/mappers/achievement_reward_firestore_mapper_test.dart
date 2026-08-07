import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_catalog.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward.dart';
import 'package:pose_estimation_app/features/rewards/infrastructure/mappers/achievement_reward_firestore_mapper.dart';

void main() {
  const mapper = AchievementRewardFirestoreMapper();

  test('round trips a deterministic achievement reward', () {
    final unlockedAt = DateTime.utc(2026, 8, 7, 8);
    final reward = AchievementReward(
      ownerId: 'user-1',
      achievementId: AchievementCatalog.firstReliableAnalysis.id,
      definitionVersion: 1,
      unlockedAt: unlockedAt,
      qualifyingEventId: 'session-1',
      isBackfilled: false,
      createdAt: unlockedAt,
      updatedAt: unlockedAt,
    );

    final decoded = mapper.fromDocument(
      documentId: reward.id,
      data: mapper.toDocument(reward),
    );

    expect(decoded.id, 'achievement:first_reliable_analysis');
    expect(decoded.achievementId, reward.achievementId);
    expect(decoded.unlockedAtUtc, unlockedAt);
  });

  test('rejects backfill for a non-backfillable achievement', () {
    final unlockedAt = DateTime.utc(2026, 8, 7, 8);
    final data = mapper.toDocument(
      AchievementReward(
        ownerId: 'user-1',
        achievementId: AchievementCatalog.guideCompleted.id,
        definitionVersion: 1,
        unlockedAt: unlockedAt,
        qualifyingEventId: 'guide-1',
        isBackfilled: false,
        createdAt: unlockedAt,
        updatedAt: unlockedAt,
      ),
    )..['isBackfilled'] = true;

    expect(
      () => mapper.fromDocument(
        documentId: 'achievement:guide_completed',
        data: data,
      ),
      throwsFormatException,
    );
  });
}
