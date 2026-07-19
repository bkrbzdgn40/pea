class RangeRepCompletedRepDetectionData {
  const RangeRepCompletedRepDetectionData({
    required this.repIndex,
    required this.minAngle,
    required this.descentDuration,
    required this.ascentDuration,
    required this.completedPhaseSequence,
  });

  final int repIndex;
  final double minAngle;
  final Duration descentDuration;
  final Duration ascentDuration;
  final bool completedPhaseSequence;
}
