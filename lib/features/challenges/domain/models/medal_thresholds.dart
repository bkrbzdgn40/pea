import 'medal_tier.dart';

/// Strictly increasing bronze, silver, and gold thresholds.
class MedalThresholds {
  MedalThresholds({
    required this.bronze,
    required this.silver,
    required this.gold,
  }) {
    if (bronze <= 0 || silver <= bronze || gold <= silver) {
      throw ArgumentError(
        'Medal thresholds must be positive and strictly increasing.',
      );
    }
  }

  final int bronze;
  final int silver;
  final int gold;

  MedalTier tierFor(num value) {
    if (!value.isFinite || value < bronze) {
      return MedalTier.none;
    }
    if (value < silver) {
      return MedalTier.bronze;
    }
    if (value < gold) {
      return MedalTier.silver;
    }
    return MedalTier.gold;
  }

  MedalTier? nextTierFor(num value) {
    return switch (tierFor(value)) {
      MedalTier.none => MedalTier.bronze,
      MedalTier.bronze => MedalTier.silver,
      MedalTier.silver => MedalTier.gold,
      MedalTier.gold => null,
    };
  }

  int thresholdFor(MedalTier tier) {
    return switch (tier) {
      MedalTier.bronze => bronze,
      MedalTier.silver => silver,
      MedalTier.gold => gold,
      MedalTier.none => throw ArgumentError.value(
        tier,
        'tier',
        'The none tier has no threshold.',
      ),
    };
  }
}
