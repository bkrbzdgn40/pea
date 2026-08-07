import '../../../challenges/domain/models/challenge_metric.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/medal_thresholds.dart';
import '../../../challenges/domain/models/medal_tier.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';
import 'challenge_medal_award_candidate.dart';
import 'reward_kind.dart';
import 'user_reward.dart';

/// Persistent, non-revocable medal for one exercise and calendar period.
class ChallengeMedalReward implements UserReward {
  ChallengeMedalReward({
    required this.ownerId,
    required this.challengeId,
    required this.catalogVersion,
    required this.exerciseType,
    required this.metric,
    required this.period,
    required this.periodKey,
    required this.timezoneOffset,
    required this.highestTier,
    required this.progressValueAtHighestTier,
    required this.thresholdsAtAward,
    required Map<MedalTier, DateTime> tierEarnedAt,
    required this.qualifyingEventId,
    required this.isBackfilled,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : tierEarnedAtUtc = Map.unmodifiable(
         tierEarnedAt.map(
           (tier, timestamp) => MapEntry(tier, timestamp.toUtc()),
         ),
       ),
       createdAtUtc = createdAt.toUtc(),
       updatedAtUtc = updatedAt.toUtc() {
    _validate();
  }

  @override
  final String ownerId;
  final String challengeId;
  final int catalogVersion;
  final ExerciseType exerciseType;
  final ChallengeMetric metric;
  final ChallengePeriod period;
  final String periodKey;
  final Duration timezoneOffset;
  final MedalTier highestTier;
  final double progressValueAtHighestTier;
  final MedalThresholds thresholdsAtAward;
  final Map<MedalTier, DateTime> tierEarnedAtUtc;
  final String qualifyingEventId;
  final bool isBackfilled;
  @override
  final DateTime createdAtUtc;
  @override
  final DateTime updatedAtUtc;

  @override
  RewardKind get kind => RewardKind.challengeMedal;

  @override
  String get id => challengeMedalRewardId(
    challengeId: challengeId,
    periodStorageValue: period.storageValue,
    periodKey: periodKey,
  );

  DateTime get firstEarnedAtUtc => tierEarnedAtUtc[MedalTier.bronze]!;
  DateTime get highestTierEarnedAtUtc => tierEarnedAtUtc[highestTier]!;
  @override
  DateTime get historyAtUtc => highestTierEarnedAtUtc;
  int get timezoneOffsetMinutes => timezoneOffset.inMinutes;

  bool hasSameIdentityAs(ChallengeMedalAwardCandidate candidate) {
    return id == candidate.rewardId &&
        challengeId == candidate.definition.id &&
        catalogVersion == candidate.definition.catalogVersion &&
        exerciseType == candidate.definition.exerciseType &&
        metric == candidate.definition.metric &&
        period == candidate.window.period &&
        periodKey == candidate.window.key &&
        timezoneOffset == candidate.window.timezoneOffset &&
        _sameThresholds(
          thresholdsAtAward,
          candidate.definition.thresholdsFor(candidate.window.period),
        );
  }

  void _validate() {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw ArgumentError.value(
        ownerId,
        'ownerId',
        'Must be a non-empty Firestore document id.',
      );
    }
    if (challengeId != '${exerciseType.id}_volume' ||
        metric != _expectedMetricFor(exerciseType)) {
      throw ArgumentError('Reward challenge metadata is inconsistent.');
    }
    if (catalogVersion <= 0) {
      throw ArgumentError.value(
        catalogVersion,
        'catalogVersion',
        'Must be positive.',
      );
    }
    if (highestTier == MedalTier.none) {
      throw ArgumentError.value(
        highestTier,
        'highestTier',
        'A persisted reward must contain an earned tier.',
      );
    }
    if (!progressValueAtHighestTier.isFinite ||
        progressValueAtHighestTier <= 0) {
      throw ArgumentError.value(
        progressValueAtHighestTier,
        'progressValueAtHighestTier',
        'Must be finite and positive.',
      );
    }
    if (thresholdsAtAward.tierFor(progressValueAtHighestTier) != highestTier) {
      throw ArgumentError(
        'Progress and the threshold snapshot must match the highest tier.',
      );
    }
    if (metric == ChallengeMetric.validRepetitions &&
        progressValueAtHighestTier !=
            progressValueAtHighestTier.roundToDouble()) {
      throw ArgumentError.value(
        progressValueAtHighestTier,
        'progressValueAtHighestTier',
        'Repetition progress must be a whole number.',
      );
    }
    if (!_isValidPeriodKey(period, periodKey)) {
      throw ArgumentError.value(
        periodKey,
        'periodKey',
        'Period key does not match its period.',
      );
    }
    if (timezoneOffset.abs() > const Duration(hours: 14) ||
        timezoneOffset.inSeconds % 60 != 0) {
      throw ArgumentError.value(
        timezoneOffset,
        'timezoneOffset',
        'Must be a whole minute between -14:00 and +14:00.',
      );
    }
    final expectedTiers = switch (highestTier) {
      MedalTier.bronze => const <MedalTier>{MedalTier.bronze},
      MedalTier.silver => const <MedalTier>{MedalTier.bronze, MedalTier.silver},
      MedalTier.gold => const <MedalTier>{
        MedalTier.bronze,
        MedalTier.silver,
        MedalTier.gold,
      },
      MedalTier.none => const <MedalTier>{},
    };
    if (tierEarnedAtUtc.length != expectedTiers.length ||
        !tierEarnedAtUtc.keys.toSet().containsAll(expectedTiers)) {
      throw ArgumentError(
        'Tier timestamps must exactly match the highest earned tier.',
      );
    }
    DateTime? previous;
    for (final tier in const <MedalTier>[
      MedalTier.bronze,
      MedalTier.silver,
      MedalTier.gold,
    ]) {
      final timestamp = tierEarnedAtUtc[tier];
      if (timestamp == null) {
        continue;
      }
      if (previous != null && timestamp.isBefore(previous)) {
        throw ArgumentError('Tier timestamps must be chronological.');
      }
      previous = timestamp;
    }
    if (isBackfilled) {
      throw ArgumentError('Historical challenge medal backfill is disabled.');
    }
    if (qualifyingEventId.isEmpty || qualifyingEventId.contains('/')) {
      throw ArgumentError.value(
        qualifyingEventId,
        'qualifyingEventId',
        'Must be a non-empty Firestore document id.',
      );
    }
    if (createdAtUtc.isBefore(firstEarnedAtUtc)) {
      throw ArgumentError('createdAt must not precede the first earned tier.');
    }
    if (updatedAtUtc.isBefore(createdAtUtc) ||
        updatedAtUtc.isBefore(highestTierEarnedAtUtc)) {
      throw ArgumentError(
        'updatedAt must not precede creation or the highest earned tier.',
      );
    }
  }
}

bool _isValidPeriodKey(ChallengePeriod period, String key) {
  switch (period) {
    case ChallengePeriod.daily:
      return _isRealDateKey(key);
    case ChallengePeriod.weekly:
      return _isRealDateKey(key) &&
          _parseDateKey(key).weekday == DateTime.monday;
    case ChallengePeriod.monthly:
      final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
      if (match == null) {
        return false;
      }
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final parsed = DateTime.utc(year, month);
      return parsed.year == year && parsed.month == month;
  }
}

bool _isRealDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

DateTime _parseDateKey(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

ChallengeMetric _expectedMetricFor(ExerciseType exerciseType) {
  return switch (exerciseType) {
    ExerciseType.plank ||
    ExerciseType.hollowHold ||
    ExerciseType.wallSit ||
    ExerciseType.sidePlank => ChallengeMetric.trustedHoldSeconds,
    _ => ChallengeMetric.validRepetitions,
  };
}

bool _sameThresholds(MedalThresholds left, MedalThresholds right) {
  return left.bronze == right.bronze &&
      left.silver == right.silver &&
      left.gold == right.gold;
}
