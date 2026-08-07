import '../../../challenges/domain/models/challenge_definition.dart';
import '../../../challenges/domain/models/challenge_metric.dart';
import '../../../challenges/domain/models/challenge_period_window.dart';
import '../../../challenges/domain/models/medal_tier.dart';

/// Immutable evidence that one challenge period has reached a medal tier.
class ChallengeMedalAwardCandidate {
  ChallengeMedalAwardCandidate({
    required this.definition,
    required this.window,
    required this.tier,
    required this.progressValue,
    required this.qualifyingEventId,
    required DateTime qualifiedAt,
  }) : qualifiedAtUtc = qualifiedAt.toUtc() {
    if (tier == MedalTier.none) {
      throw ArgumentError.value(
        tier,
        'tier',
        'A reward candidate must contain an earned medal tier.',
      );
    }
    if (!progressValue.isFinite || progressValue <= 0) {
      throw ArgumentError.value(
        progressValue,
        'progressValue',
        'Must be finite and positive.',
      );
    }
    final thresholds = definition.thresholdsFor(window.period);
    if (thresholds.tierFor(progressValue) != tier) {
      throw ArgumentError.value(
        progressValue,
        'progressValue',
        'Progress does not match the candidate tier.',
      );
    }
    if (definition.metric == ChallengeMetric.validRepetitions &&
        progressValue != progressValue.roundToDouble()) {
      throw ArgumentError.value(
        progressValue,
        'progressValue',
        'Repetition progress must be a whole number.',
      );
    }
    if (qualifyingEventId.isEmpty || qualifyingEventId.contains('/')) {
      throw ArgumentError.value(
        qualifyingEventId,
        'qualifyingEventId',
        'Must be a non-empty Firestore document id.',
      );
    }
    if (!window.contains(qualifiedAtUtc)) {
      throw ArgumentError.value(
        qualifiedAtUtc,
        'qualifiedAt',
        'The qualifying event must belong to the rewarded period.',
      );
    }
  }

  final ChallengeDefinition definition;
  final ChallengePeriodWindow window;
  final MedalTier tier;
  final double progressValue;
  final String qualifyingEventId;
  final DateTime qualifiedAtUtc;

  String get rewardId => challengeMedalRewardId(
    challengeId: definition.id,
    periodStorageValue: window.period.storageValue,
    periodKey: window.key,
  );
}

String challengeMedalRewardId({
  required String challengeId,
  required String periodStorageValue,
  required String periodKey,
}) {
  return 'medal:$challengeId:$periodStorageValue:$periodKey';
}
