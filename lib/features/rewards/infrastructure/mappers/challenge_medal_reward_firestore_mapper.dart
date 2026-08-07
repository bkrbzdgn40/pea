import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../challenges/domain/models/challenge_metric.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/medal_thresholds.dart';
import '../../../challenges/domain/models/medal_tier.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';
import '../../domain/models/challenge_medal_reward.dart';
import '../../domain/models/reward_kind.dart';

class ChallengeMedalRewardFirestoreMapper {
  const ChallengeMedalRewardFirestoreMapper();

  static const int schemaVersion = 1;

  Map<String, Object?> toDocument(ChallengeMedalReward reward) {
    final sortedTiers = <String, Timestamp>{};
    for (final tier in const <MedalTier>[
      MedalTier.bronze,
      MedalTier.silver,
      MedalTier.gold,
    ]) {
      final earnedAt = reward.tierEarnedAtUtc[tier];
      if (earnedAt != null) {
        sortedTiers[tier.storageValue] = Timestamp.fromDate(earnedAt);
      }
    }

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'id': reward.id,
      'ownerId': reward.ownerId,
      'kind': reward.kind.storageValue,
      'challengeId': reward.challengeId,
      'catalogVersion': reward.catalogVersion,
      'exerciseType': reward.exerciseType.id,
      'metric': reward.metric.storageValue,
      'period': reward.period.storageValue,
      'periodKey': reward.periodKey,
      'timezoneOffsetMinutes': reward.timezoneOffsetMinutes,
      'highestTier': reward.highestTier.storageValue,
      'progressValueAtHighestTier':
          reward.metric == ChallengeMetric.validRepetitions
          ? reward.progressValueAtHighestTier.toInt()
          : reward.progressValueAtHighestTier,
      'thresholdsAtAward': <String, int>{
        'bronze': reward.thresholdsAtAward.bronze,
        'silver': reward.thresholdsAtAward.silver,
        'gold': reward.thresholdsAtAward.gold,
      },
      'tierEarnedAt': sortedTiers,
      'firstEarnedAt': Timestamp.fromDate(reward.firstEarnedAtUtc),
      'highestTierEarnedAt': Timestamp.fromDate(reward.highestTierEarnedAtUtc),
      'historyAt': Timestamp.fromDate(reward.historyAtUtc),
      'qualifyingEventId': reward.qualifyingEventId,
      'isBackfilled': reward.isBackfilled,
      'createdAt': Timestamp.fromDate(reward.createdAtUtc),
      'updatedAt': Timestamp.fromDate(reward.updatedAtUtc),
    };
  }

  ChallengeMedalReward fromDocument({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final schemaVersionValue = data['schemaVersion'];
    final id = data['id'];
    final ownerId = data['ownerId'];
    final kindValue = data['kind'];
    final challengeId = data['challengeId'];
    final catalogVersion = data['catalogVersion'];
    final exerciseTypeValue = data['exerciseType'];
    final metricValue = data['metric'];
    final periodValue = data['period'];
    final periodKey = data['periodKey'];
    final timezoneOffsetMinutes = data['timezoneOffsetMinutes'];
    final highestTierValue = data['highestTier'];
    final progressValue = data['progressValueAtHighestTier'];
    final thresholdsData = data['thresholdsAtAward'];
    final tierEarnedAtData = data['tierEarnedAt'];
    final firstEarnedAt = data['firstEarnedAt'];
    final highestTierEarnedAt = data['highestTierEarnedAt'];
    final historyAt = data['historyAt'];
    final qualifyingEventId = data['qualifyingEventId'];
    final isBackfilled = data['isBackfilled'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    final kind = kindValue is String ? RewardKind.tryParse(kindValue) : null;
    final exerciseType = exerciseTypeValue is String
        ? ExerciseType.fromIdOrNull(exerciseTypeValue)
        : null;
    final metric = metricValue is String
        ? ChallengeMetric.tryParse(metricValue)
        : null;
    final period = periodValue is String
        ? ChallengePeriod.tryParse(periodValue)
        : null;
    final highestTier = highestTierValue is String
        ? MedalTier.tryParse(highestTierValue)
        : null;

    if (schemaVersionValue != schemaVersion ||
        id is! String ||
        id != documentId ||
        ownerId is! String ||
        ownerId.isEmpty ||
        kind != RewardKind.challengeMedal ||
        challengeId is! String ||
        challengeId.isEmpty ||
        catalogVersion is! int ||
        exerciseType == null ||
        metric == null ||
        period == null ||
        periodKey is! String ||
        timezoneOffsetMinutes is! int ||
        highestTier == null ||
        highestTier == MedalTier.none ||
        progressValue is! num ||
        thresholdsData is! Map ||
        tierEarnedAtData is! Map ||
        firstEarnedAt is! Timestamp ||
        highestTierEarnedAt is! Timestamp ||
        historyAt is! Timestamp ||
        qualifyingEventId is! String ||
        isBackfilled is! bool ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw const FormatException('Invalid challenge medal reward document.');
    }

    final bronzeThreshold = thresholdsData['bronze'];
    final silverThreshold = thresholdsData['silver'];
    final goldThreshold = thresholdsData['gold'];
    if (thresholdsData.length != 3 ||
        bronzeThreshold is! int ||
        silverThreshold is! int ||
        goldThreshold is! int) {
      throw const FormatException('Invalid reward threshold snapshot.');
    }

    final tierEarnedAt = <MedalTier, DateTime>{};
    for (final entry in tierEarnedAtData.entries) {
      final tier = entry.key is String
          ? MedalTier.tryParse(entry.key as String)
          : null;
      if (tier == null ||
          tier == MedalTier.none ||
          entry.value is! Timestamp ||
          tierEarnedAt.containsKey(tier)) {
        throw const FormatException('Invalid reward tier timestamps.');
      }
      tierEarnedAt[tier] = (entry.value as Timestamp).toDate();
    }

    try {
      final reward = ChallengeMedalReward(
        ownerId: ownerId,
        challengeId: challengeId,
        catalogVersion: catalogVersion,
        exerciseType: exerciseType,
        metric: metric,
        period: period,
        periodKey: periodKey,
        timezoneOffset: Duration(minutes: timezoneOffsetMinutes),
        highestTier: highestTier,
        progressValueAtHighestTier: progressValue.toDouble(),
        thresholdsAtAward: MedalThresholds(
          bronze: bronzeThreshold,
          silver: silverThreshold,
          gold: goldThreshold,
        ),
        tierEarnedAt: tierEarnedAt,
        qualifyingEventId: qualifyingEventId,
        isBackfilled: isBackfilled,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
      if (reward.id != documentId ||
          reward.firstEarnedAtUtc != firstEarnedAt.toDate().toUtc() ||
          reward.highestTierEarnedAtUtc !=
              highestTierEarnedAt.toDate().toUtc() ||
          reward.historyAtUtc != historyAt.toDate().toUtc()) {
        throw const FormatException('Reward summary timestamps disagree.');
      }
      return reward;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid challenge medal reward document: $error');
    }
  }
}
