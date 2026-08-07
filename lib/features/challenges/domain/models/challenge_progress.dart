import 'challenge_definition.dart';
import 'challenge_period.dart';
import 'medal_thresholds.dart';
import 'medal_tier.dart';

/// Evaluated progress for one exercise and one active calendar period.
class ChallengeProgress {
  ChallengeProgress({
    required this.definition,
    required this.period,
    required this.value,
  }) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Progress value must be finite and non-negative.',
      );
    }
  }

  final ChallengeDefinition definition;
  final ChallengePeriod period;
  final double value;

  MedalTier get tier => thresholds.tierFor(value);
  MedalTier? get nextTier => thresholds.nextTierFor(value);
  bool get hasReachedGold => tier == MedalTier.gold;

  int? get nextThreshold {
    final targetTier = nextTier;
    return targetTier == null ? null : thresholds.thresholdFor(targetTier);
  }

  double? get remainingToNextTier {
    final target = nextThreshold;
    if (target == null) {
      return null;
    }
    final remaining = target - value;
    return remaining > 0 ? remaining : 0;
  }

  MedalThresholds get thresholds => definition.thresholdsFor(period);
}
