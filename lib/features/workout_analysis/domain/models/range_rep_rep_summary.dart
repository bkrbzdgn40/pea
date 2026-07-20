/// Lean rep-level input for future range-rep validation policies.
class RangeRepRepSummary {
  const RangeRepRepSummary({
    required this.repIndex,
    required this.minAngle,
    required this.worstFormMetric,
    required this.descentDuration,
    required this.ascentDuration,
    required this.hadFormViolation,
    required this.hadCoverageDrop,
    required this.switchedSideDuringRep,
    required this.completedPhaseSequence,
    this.selectedSideLabel,
    this.analysisKindLabel,
    this.startAngle,
    this.primaryRom,
    this.confidence,
    this.coverageQuality,
  });

  final int repIndex;
  final double minAngle;
  final double worstFormMetric;
  final Duration descentDuration;
  final Duration ascentDuration;
  final bool hadFormViolation;
  final bool hadCoverageDrop;
  final bool switchedSideDuringRep;
  final bool completedPhaseSequence;
  final String? selectedSideLabel;
  final String? analysisKindLabel;
  final double? startAngle;
  final double? primaryRom;
  final double? confidence;
  final double? coverageQuality;
}
