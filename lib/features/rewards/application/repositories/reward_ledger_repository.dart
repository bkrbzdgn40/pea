import '../../../challenges/domain/models/challenge_period.dart';
import '../../domain/models/achievement_award_candidate.dart';
import '../../domain/models/achievement_reward.dart';
import '../../domain/models/achievement_reward_mutation.dart';
import '../../domain/models/challenge_medal_award_candidate.dart';
import '../../domain/models/challenge_medal_reward.dart';
import '../../domain/models/reward_history_cursor.dart';
import '../../domain/models/reward_history_page.dart';
import '../../domain/models/reward_ledger_mutation.dart';

abstract interface class RewardLedgerRepository {
  Future<AchievementRewardWriteResult> unlockAchievement({
    required String ownerId,
    required AchievementAwardCandidate candidate,
    required DateTime now,
  });

  Future<AchievementReward?> getAchievementReward({
    required String ownerId,
    required String rewardId,
  });

  Future<RewardHistoryPage<AchievementReward>> listAchievementRewards({
    required String ownerId,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  });

  Future<RewardLedgerWriteResult> upsertChallengeMedal({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required DateTime now,
  });

  Future<ChallengeMedalReward?> getChallengeMedal({
    required String ownerId,
    required String rewardId,
  });

  Future<RewardHistoryPage<ChallengeMedalReward>> listChallengeMedals({
    required String ownerId,
    ChallengePeriod? period,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  });
}
