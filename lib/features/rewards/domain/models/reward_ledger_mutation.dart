import 'challenge_medal_reward.dart';

enum RewardLedgerWriteStatus { created, upgraded, unchanged }

class RewardLedgerWriteResult {
  const RewardLedgerWriteResult({required this.status, required this.reward});

  final RewardLedgerWriteStatus status;
  final ChallengeMedalReward reward;
}
