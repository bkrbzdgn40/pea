import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_thresholds.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_reward.dart';
import 'package:pose_estimation_app/features/rewards/infrastructure/mappers/challenge_medal_reward_firestore_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const mapper = ChallengeMedalRewardFirestoreMapper();

  test('round-trips a challenge medal reward', () {
    final reward = _reward();
    final document = mapper.toDocument(reward);
    final decoded = mapper.fromDocument(documentId: reward.id, data: document);

    expect(decoded.id, reward.id);
    expect(decoded.highestTier, MedalTier.silver);
    expect(decoded.progressValueAtHighestTier, 20);
    expect(
      decoded.tierEarnedAtUtc[MedalTier.bronze],
      DateTime.utc(2026, 8, 7, 8),
    );
    expect(
      decoded.tierEarnedAtUtc[MedalTier.silver],
      DateTime.utc(2026, 8, 7, 10),
    );
  });

  test('rejects inconsistent summary timestamps and document ids', () {
    final reward = _reward();
    final wrongTimestamp = mapper.toDocument(reward)
      ..['highestTierEarnedAt'] = Timestamp.fromDate(
        DateTime.utc(2026, 8, 7, 11),
      );
    final wrongThresholds = mapper.toDocument(reward)
      ..['thresholdsAtAward'] = <String, int>{
        'bronze': 10,
        'silver': 25,
        'gold': 30,
      };

    expect(
      () => mapper.fromDocument(documentId: reward.id, data: wrongTimestamp),
      throwsFormatException,
    );
    expect(
      () => mapper.fromDocument(
        documentId: 'wrong-id',
        data: mapper.toDocument(reward),
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.fromDocument(documentId: reward.id, data: wrongThresholds),
      throwsFormatException,
    );
  });
}

ChallengeMedalReward _reward() {
  final bronzeAt = DateTime.utc(2026, 8, 7, 8);
  final silverAt = DateTime.utc(2026, 8, 7, 10);
  return ChallengeMedalReward(
    ownerId: 'user-1',
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    period: ChallengePeriod.daily,
    periodKey: '2026-08-07',
    timezoneOffset: Duration.zero,
    highestTier: MedalTier.silver,
    progressValueAtHighestTier: 20,
    thresholdsAtAward: MedalThresholds(bronze: 10, silver: 20, gold: 30),
    tierEarnedAt: <MedalTier, DateTime>{
      MedalTier.bronze: bronzeAt,
      MedalTier.silver: silverAt,
    },
    qualifyingEventId: 'session-2',
    isBackfilled: false,
    createdAt: bronzeAt,
    updatedAt: silverAt,
  );
}
