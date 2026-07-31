enum RangeRepRomRegion { insufficient, acceptable, targetReached }

class RangeRepRomScoreResult {
  const RangeRepRomScoreResult({
    required this.region,
    required this.score,
    required this.achievedRom,
    required this.minimumAcceptableRom,
    required this.targetRom,
  });

  final RangeRepRomRegion region;
  final double score;
  final double achievedRom;
  final double minimumAcceptableRom;
  final double targetRom;
}

class LegacyRangeRepScorer {
  const LegacyRangeRepScorer();

  /// Compatibility scoring for angle-based exercises. The score saturates at
  /// 100 once the target minimum angle is reached or exceeded.
  double calculateRomScore({
    required double minAngle,
    required double targetMinAngle,
  }) {
    return (100 - (minAngle - targetMinAngle)).clamp(0, 100).toDouble();
  }

  /// Explicit ROM-delta scoring used by Core v2 diagnostics.
  ///
  /// The legacy numeric score curve is preserved by expressing the same
  /// target-relative deficit in ROM space. Extra ROM beyond [targetRom] never
  /// awards more than 100 points.
  RangeRepRomScoreResult calculateSaturatingRomScore({
    required double achievedRom,
    required double minimumAcceptableRom,
    required double targetRom,
  }) {
    final normalizedAchievedRom = achievedRom.clamp(0.0, 180.0).toDouble();
    final normalizedMinimum = minimumAcceptableRom.clamp(0.0, 180.0).toDouble();
    final normalizedTarget = targetRom
        .clamp(normalizedMinimum, 180.0)
        .toDouble();

    final region = normalizedAchievedRom >= normalizedTarget
        ? RangeRepRomRegion.targetReached
        : normalizedAchievedRom >= normalizedMinimum
        ? RangeRepRomRegion.acceptable
        : RangeRepRomRegion.insufficient;

    final score = normalizedTarget <= 0
        ? 100.0
        : (100.0 - (normalizedTarget - normalizedAchievedRom))
              .clamp(0.0, 100.0)
              .toDouble();

    return RangeRepRomScoreResult(
      region: region,
      score: score,
      achievedRom: normalizedAchievedRom,
      minimumAcceptableRom: normalizedMinimum,
      targetRom: normalizedTarget,
    );
  }

  double calculateTempoScore({
    required double actualSeconds,
    required double idealSeconds,
    required double tempoPenaltyPerSecond,
  }) {
    return (100 - (idealSeconds - actualSeconds).abs() * tempoPenaltyPerSecond)
        .clamp(0, 100)
        .toDouble();
  }

  double? calculateWeightedBaseScore({
    required double depthScore,
    required double descentControlScore,
    required double ascentControlScore,
    required double depthWeight,
    required double descentControlWeight,
    required double ascentControlWeight,
  }) {
    var weightedScoreTotal = 0.0;
    var totalWeight = 0.0;

    void includeScore(double score, double weight) {
      if (weight <= 0) {
        return;
      }

      weightedScoreTotal += score * weight;
      totalWeight += weight;
    }

    includeScore(depthScore, depthWeight);
    includeScore(descentControlScore, descentControlWeight);
    includeScore(ascentControlScore, ascentControlWeight);

    if (totalWeight <= 0) {
      return null;
    }

    return weightedScoreTotal / totalWeight;
  }

  double calculateBaseScore({
    required double romScore,
    required double tempoScore,
    required double? weightedBaseScore,
    required bool hadFormViolation,
    bool includeTempo = true,
  }) {
    final legacyBaseScore = includeTempo
        ? (romScore + tempoScore) / 2
        : romScore;
    final selectedBaseScore = weightedBaseScore ?? legacyBaseScore;

    return hadFormViolation ? selectedBaseScore / 2 : selectedBaseScore;
  }

  double? calculatePhaseQualityPenalty({
    required bool descendingPhaseFlagged,
    required bool ascendingPhaseFlagged,
  }) {
    var penalty = 0.0;

    if (descendingPhaseFlagged) {
      penalty += 5.0;
    }
    if (ascendingPhaseFlagged) {
      penalty += 5.0;
    }

    return penalty > 0 ? penalty : null;
  }

  double? calculatePhaseAdjustedScore({
    required double baseScore,
    required double? phaseQualityPenalty,
  }) {
    return phaseQualityPenalty == null
        ? null
        : (baseScore - phaseQualityPenalty).clamp(0.0, 100.0).toDouble();
  }

  double calculateFinalScore({
    required double baseScore,
    required double? phaseAdjustedScore,
  }) {
    return phaseAdjustedScore ?? baseScore;
  }
}
