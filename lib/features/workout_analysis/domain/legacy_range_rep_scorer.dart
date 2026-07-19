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
}
