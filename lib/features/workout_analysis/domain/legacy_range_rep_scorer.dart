class LegacyRangeRepScorer {
  const LegacyRangeRepScorer();

  double calculateRomScore({
    required double minAngle,
    required double targetMinAngle,
  }) {
    return (100 - (minAngle - targetMinAngle)).clamp(0, 100).toDouble();
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
  }) {
    final legacyBaseScore = hadFormViolation
        ? (romScore + tempoScore) / 4
        : (romScore + tempoScore) / 2;

    return weightedBaseScore == null
        ? legacyBaseScore
        : (hadFormViolation ? weightedBaseScore / 2 : weightedBaseScore);
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
}
