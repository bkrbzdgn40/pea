import 'achievement_reward.dart';
import 'reward_ledger_mutation.dart';

class AchievementRewardWriteResult {
  const AchievementRewardWriteResult({
    required this.status,
    required this.reward,
  });

  final RewardLedgerWriteStatus status;
  final AchievementReward reward;
}
