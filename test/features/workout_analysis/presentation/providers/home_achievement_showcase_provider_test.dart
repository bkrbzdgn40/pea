import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/rewards/application/repositories/reward_ledger_repository.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward_mutation.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_reward.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_history_cursor.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_history_page.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_ledger_mutation.dart';
import 'package:pose_estimation_app/features/rewards/presentation/providers/reward_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_achievement_showcase_provider.dart';

void main() {
  test('loads only the latest three achievement rewards for Home', () async {
    final repository = _RecordingRewardLedgerRepository(
      rewards: [
        _reward('golden_week', DateTime.utc(2026, 8, 7, 12)),
        _reward('controlled_tempo', DateTime.utc(2026, 8, 6, 12)),
        _reward('exercise_explorer_3', DateTime.utc(2026, 8, 5, 12)),
        _reward('first_reliable_analysis', DateTime.utc(2026, 8, 4, 12)),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        homeAchievementShowcaseOwnerIdProvider.overrideWithValue('owner-1'),
        rewardLedgerRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(homeAchievementShowcaseProvider.future);

    expect(repository.lastOwnerId, 'owner-1');
    expect(repository.lastLimit, homeAchievementShowcaseLimit);
    expect(result, isNotNull);
    expect(result!.rewards.map((reward) => reward.achievementId), [
      'golden_week',
      'controlled_tempo',
      'exercise_explorer_3',
    ]);
  });

  test('does not query the reward ledger without a signed-in owner', () async {
    final repository = _RecordingRewardLedgerRepository(rewards: const []);
    final container = ProviderContainer(
      overrides: [
        homeAchievementShowcaseOwnerIdProvider.overrideWithValue(null),
        rewardLedgerRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(homeAchievementShowcaseProvider.future);

    expect(result, isNull);
    expect(repository.callCount, 0);
  });
}

AchievementReward _reward(String id, DateTime unlockedAt) {
  return AchievementReward(
    ownerId: 'owner-1',
    achievementId: id,
    definitionVersion: 1,
    unlockedAt: unlockedAt,
    qualifyingEventId: 'event-$id',
    isBackfilled: false,
    createdAt: unlockedAt,
    updatedAt: unlockedAt,
  );
}

class _RecordingRewardLedgerRepository implements RewardLedgerRepository {
  _RecordingRewardLedgerRepository({required this.rewards});

  final List<AchievementReward> rewards;
  int callCount = 0;
  int? lastLimit;
  String? lastOwnerId;

  @override
  Future<RewardHistoryPage<AchievementReward>> listAchievementRewards({
    required String ownerId,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    callCount += 1;
    lastLimit = limit;
    lastOwnerId = ownerId;
    return RewardHistoryPage<AchievementReward>(
      items: rewards.take(limit).toList(growable: false),
      nextCursor: null,
    );
  }

  @override
  Future<RewardHistoryPage<ChallengeMedalReward>> listChallengeMedals({
    required String ownerId,
    ChallengePeriod? period,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async => RewardHistoryPage<ChallengeMedalReward>(
    items: <ChallengeMedalReward>[],
    nextCursor: null,
  );

  @override
  Future<AchievementReward?> getAchievementReward({
    required String ownerId,
    required String rewardId,
  }) async => null;

  @override
  Future<ChallengeMedalReward?> getChallengeMedal({
    required String ownerId,
    required String rewardId,
  }) async => null;

  @override
  Future<AchievementRewardWriteResult> unlockAchievement({
    required String ownerId,
    required AchievementAwardCandidate candidate,
    required DateTime now,
  }) async => throw UnimplementedError();

  @override
  Future<RewardLedgerWriteResult> upsertChallengeMedal({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required DateTime now,
  }) async => throw UnimplementedError();
}
