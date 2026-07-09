/// Rep-level scoring diagnostics captured when a full repetition completes.
class RepScoreBreakdown {
  const RepScoreBreakdown({
    required this.minAngle,
    required this.romScore,
    required this.descentSeconds,
    required this.descentScore,
    required this.ascentSeconds,
    required this.ascentScore,
    required this.worstBackAngle,
    required this.hadFormViolation,
    required this.runtimeBaseScore,
    required this.finalScore,
    this.depthScore,
    this.postureScore,
    this.stabilityScore,
    this.descentControlScore,
    this.ascentControlScore,
    this.consistencyScore,
    this.weightedBaseScore,
    this.phaseQualityPenalty,
    this.phaseAdjustedScore,
  });

  final double minAngle;
  final double romScore;
  final double descentSeconds;
  final double descentScore;
  final double ascentSeconds;
  final double ascentScore;
  final double worstBackAngle;
  final bool hadFormViolation;
  final double runtimeBaseScore;
  final double finalScore;
  final double? depthScore;
  final double? postureScore;
  final double? stabilityScore;
  final double? descentControlScore;
  final double? ascentControlScore;
  final double? consistencyScore;
  final double? weightedBaseScore;
  final double? phaseQualityPenalty;
  final double? phaseAdjustedScore;
}
