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
}
