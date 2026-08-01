import 'range_rep_validation_result.dart';
import 'rep_tempo_assessment.dart';

enum ValidatedRepSide { left, right }

/// Single source of truth emitted once after a completed range-rep attempt has
/// been validated and scored.
class ValidatedRepEvent {
  ValidatedRepEvent({
    required this.attemptIndex,
    required this.acceptedRepIndex,
    required this.exerciseType,
    required this.analysisKind,
    required this.validationStatus,
    required List<RangeRepValidationReason> validationReasons,
    required List<RangeRepValidationReason> tempoDiagnosticReasons,
    required this.countsTowardReps,
    required this.side,
    required this.minPrimaryMetric,
    required this.primaryRom,
    required this.worstFormMetric,
    required this.descentDuration,
    required this.ascentDuration,
    required this.hadFormViolation,
    required this.hadCoverageDrop,
    required this.switchedSideDuringRep,
    required this.completedPhaseSequence,
    required this.measurementConfidence,
    required this.coverageQuality,
    required this.finalScore,
    required this.tempoAssessment,
    required this.tempoIncludedInScore,
    required this.completedAt,
  }) : validationReasons = List<RangeRepValidationReason>.unmodifiable(
         validationReasons,
       ),
       tempoDiagnosticReasons = List<RangeRepValidationReason>.unmodifiable(
         tempoDiagnosticReasons,
       );

  final int attemptIndex;
  final int? acceptedRepIndex;
  final String exerciseType;
  final String analysisKind;
  final RangeRepValidationStatus validationStatus;
  final List<RangeRepValidationReason> validationReasons;
  final List<RangeRepValidationReason> tempoDiagnosticReasons;
  final bool countsTowardReps;
  final ValidatedRepSide? side;
  final double? minPrimaryMetric;
  final double? primaryRom;
  final double? worstFormMetric;
  final Duration? descentDuration;
  final Duration? ascentDuration;
  final bool hadFormViolation;
  final bool hadCoverageDrop;
  final bool switchedSideDuringRep;
  final bool completedPhaseSequence;
  final double? measurementConfidence;
  final double? coverageQuality;
  final double? finalScore;
  final RepTempoAssessment? tempoAssessment;
  final bool tempoIncludedInScore;
  final DateTime completedAt;

  ValidatedRepEvent copyWith({String? exerciseType}) {
    return ValidatedRepEvent(
      attemptIndex: attemptIndex,
      acceptedRepIndex: acceptedRepIndex,
      exerciseType: exerciseType ?? this.exerciseType,
      analysisKind: analysisKind,
      validationStatus: validationStatus,
      validationReasons: validationReasons,
      tempoDiagnosticReasons: tempoDiagnosticReasons,
      countsTowardReps: countsTowardReps,
      side: side,
      minPrimaryMetric: minPrimaryMetric,
      primaryRom: primaryRom,
      worstFormMetric: worstFormMetric,
      descentDuration: descentDuration,
      ascentDuration: ascentDuration,
      hadFormViolation: hadFormViolation,
      hadCoverageDrop: hadCoverageDrop,
      switchedSideDuringRep: switchedSideDuringRep,
      completedPhaseSequence: completedPhaseSequence,
      measurementConfidence: measurementConfidence,
      coverageQuality: coverageQuality,
      finalScore: finalScore,
      tempoAssessment: tempoAssessment,
      tempoIncludedInScore: tempoIncludedInScore,
      completedAt: completedAt,
    );
  }

  bool get isRomSymmetryEligible {
    final rom = primaryRom;
    return countsTowardReps &&
        side != null &&
        rom != null &&
        rom.isFinite &&
        rom >= 0 &&
        !validationReasons.any((reason) => reason.isMeasurementQualityReason);
  }

  bool get isTempoSymmetryEligible =>
      isRomSymmetryEligible && tempoAssessment?.isAvailable == true;
}
