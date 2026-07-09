/// Rep-level scoring diagnostics captured when a full repetition completes.
class RepScoreBreakdown {
  const RepScoreBreakdown({
    required this.minAngle,
    required this.romScore,
    required this.descentSeconds,
    required this.descentScore,
    required this.ascentSeconds,
    required this.ascentScoreCandidate,
    required this.worstBackAngle,
    required this.hadFormViolation,
    required this.finalScore,
    this.depthScore,
    this.postureScore,
    this.stabilityScore,
    this.descentControlScore,
    this.ascentControlScore,
    this.consistencyScore,
    this.weightedScoreCandidate,
    this.phaseQualityPenaltyCandidate,
    this.phaseInformedScoreCandidate,
  });

  final double minAngle;
  final double romScore;
  final double descentSeconds;
  final double descentScore;
  final double ascentSeconds;
  final double ascentScoreCandidate;
  final double worstBackAngle;
  final bool hadFormViolation;
  final double finalScore;
  final double? depthScore;
  final double? postureScore;
  final double? stabilityScore;
  final double? descentControlScore;
  final double? ascentControlScore;
  final double? consistencyScore;
  final double? weightedScoreCandidate;
  final double? phaseQualityPenaltyCandidate;
  final double? phaseInformedScoreCandidate;
}
