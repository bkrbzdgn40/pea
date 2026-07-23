/// Quantized metric values rendered by the live analysis overlay.
///
/// Rich canonical metrics remain available through `WorkoutLiveMetricsSnapshot`
/// for session completion and persistence. This projection deliberately keeps
/// only values that are visible during analysis so equality checks can suppress
/// redundant UI updates.
class WorkoutLiveMetricDisplayState {
  const WorkoutLiveMetricDisplayState({
    this.angleDegrees,
    this.tempo,
    this.stabilityScore,
    this.asymmetryScore,
  });

  static const empty = WorkoutLiveMetricDisplayState();

  final int? angleDegrees;
  final Duration? tempo;
  final int? stabilityScore;
  final int? asymmetryScore;

  bool get isEmpty =>
      angleDegrees == null &&
      tempo == null &&
      stabilityScore == null &&
      asymmetryScore == null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkoutLiveMetricDisplayState &&
            other.angleDegrees == angleDegrees &&
            other.tempo == tempo &&
            other.stabilityScore == stabilityScore &&
            other.asymmetryScore == asymmetryScore;
  }

  @override
  int get hashCode =>
      Object.hash(angleDegrees, tempo, stabilityScore, asymmetryScore);
}
