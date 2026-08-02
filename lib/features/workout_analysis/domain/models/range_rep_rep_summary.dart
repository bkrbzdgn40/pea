import 'measurement_confidence_breakdown.dart';

/// Lean rep-level input for future range-rep validation policies.
class RangeRepRepSummary {
  RangeRepRepSummary({
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
    MeasurementConfidenceBreakdown? measurementConfidence,
    double? confidence,
    this.coverageQuality,
    this.totalRepDuration,
  }) : assert(
         confidence == null ||
             measurementConfidence == null ||
             confidence == measurementConfidence.combined,
       ),
       measurementConfidence =
           measurementConfidence ??
           (confidence == null
               ? null
               : MeasurementConfidenceBreakdown.legacyScalar(confidence));

  final int repIndex;
  final double minAngle;
  final double worstFormMetric;
  final Duration descentDuration;
  final Duration ascentDuration;
  final Duration? totalRepDuration;
  final bool hadFormViolation;
  final bool hadCoverageDrop;
  final bool switchedSideDuringRep;
  final bool completedPhaseSequence;
  final String? selectedSideLabel;
  final String? analysisKindLabel;
  final double? startAngle;
  final double? primaryRom;
  final MeasurementConfidenceBreakdown? measurementConfidence;
  final double? coverageQuality;

  /// Temporary compatibility view. The breakdown remains the only source.
  double? get confidence => measurementConfidence?.combined;
}
