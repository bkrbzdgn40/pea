import '../legacy_range_rep_scorer.dart';

enum RepScoreComponentKind { rom, tempo, technique, consistency, confidence }

class RepScoreComponents {
  const RepScoreComponents({
    required this.rom,
    required this.tempo,
    required this.technique,
    required this.consistency,
    required this.confidence,
  });

  final double rom;
  final double tempo;
  final double technique;
  final double consistency;
  final double? confidence;
}

class RepScorePenaltyTrace {
  const RepScorePenaltyTrace({
    required this.component,
    required this.code,
    required this.evidenceCode,
    required this.penaltyPoints,
    this.observedValue,
    this.referenceValue,
    this.observationUnit,
  });

  final RepScoreComponentKind component;
  final String code;
  final String evidenceCode;
  final double penaltyPoints;
  final double? observedValue;
  final double? referenceValue;
  final String? observationUnit;
}

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
    this.primaryRom,
    this.romRegion,
    this.scoreComponents,
    this.penaltyTraces = const <RepScorePenaltyTrace>[],
    this.depthScore,
    this.postureScore,
    this.stabilityScore,
    this.descentControlScore,
    this.ascentControlScore,
    this.consistencyScore,
    this.weightedBaseScore,
    this.phaseQualityPenalty,
    this.phaseAdjustedScore,
    this.totalRepSeconds,
    this.totalRepTempoScore,
    this.tempoIncludedInFinalScore = true,
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

  /// Core v2 ROM-delta measurement where available.
  final double? primaryRom;

  /// Explicit R29 saturation region. Null only for legacy callers that do not
  /// yet provide enough information to derive ROM delta.
  final RangeRepRomRegion? romRegion;

  /// Explainable R30 component view. Tempo can remain visible here while being
  /// excluded from the final score when measurement confidence is limited.
  final RepScoreComponents? scoreComponents;

  /// R31 traceability: each applied penalty points at concrete evidence.
  final List<RepScorePenaltyTrace> penaltyTraces;

  final double? depthScore;
  final double? postureScore;
  final double? stabilityScore;
  final double? descentControlScore;
  final double? ascentControlScore;
  final double? consistencyScore;
  final double? weightedBaseScore;
  final double? phaseQualityPenalty;
  final double? phaseAdjustedScore;

  /// Complete start-to-neutral duration used by exercises whose phase
  /// thresholds are too close for reliable segment timing.
  final double? totalRepSeconds;

  /// Tempo score derived from [totalRepSeconds] when total-duration scoring is
  /// enabled for the exercise.
  final double? totalRepTempoScore;

  /// False when tempo remains diagnostic-only because the completed rep had a
  /// timing or coverage confidence warning.
  final bool tempoIncludedInFinalScore;
}
