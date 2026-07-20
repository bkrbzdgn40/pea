import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/session_calibration_baseline.dart';

/// Resolves range-rep calibration semantics without allowing an observed
/// starting posture to redefine the exercise's technique acceptance threshold.
///
/// A compatible calibration baseline may expose a bounded measurement-
/// correction candidate for diagnostics/future sensor correction. The
/// technique threshold itself remains owned by the exercise contract/config.
class RangeRepThresholdResolver {
  const RangeRepThresholdResolver({
    this.minCalibrationBaselineSamplesForThresholdOffset = 3,
    this.maxCalibrationThresholdOffsetMagnitude = 5.0,
    this.minCalibrationThresholdOffsetMagnitude = 0.5,
  });

  final int minCalibrationBaselineSamplesForThresholdOffset;
  final double maxCalibrationThresholdOffsetMagnitude;
  final double minCalibrationThresholdOffsetMagnitude;

  RangeRepThresholdResolution resolve({
    required String analysisKind,
    required ExerciseConfig config,
    required double baseThreshold,
    required RangeRepFormThresholdCalibrationPolicy
    formThresholdCalibrationPolicy,
    required SessionCalibrationBaseline? sessionCalibrationBaseline,
    required String? selectedRangeRepSide,
  }) {
    final baseline = sessionCalibrationBaseline;
    final sampleCount = baseline?.sampleCount;
    final baselineSideLabel = baseline?.selectedSideLabel;
    if (formThresholdCalibrationPolicy ==
        RangeRepFormThresholdCalibrationPolicy.disabled) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'disabled_by_contract',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    if (baseline == null || baseline.analysisKind != analysisKind) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'no_baseline',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    if (baseline.sampleCount <
        minCalibrationBaselineSamplesForThresholdOffset) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'insufficient_samples',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    if (baseline.formMetricBaseline == null) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'missing_form_baseline',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    if (selectedRangeRepSide == null ||
        baseline.selectedSideLabel != selectedRangeRepSide) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'side_mismatch',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    final correctionCandidate = (baseline.formMetricBaseline! - baseThreshold)
        .clamp(
          -maxCalibrationThresholdOffsetMagnitude,
          maxCalibrationThresholdOffsetMagnitude,
        )
        .toDouble();
    if (correctionCandidate.abs() < minCalibrationThresholdOffsetMagnitude) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'offset_too_small',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    return RangeRepThresholdResolution.measurementCorrectionCandidate(
      baseThreshold: baseThreshold,
      measurementCorrectionOffset: correctionCandidate,
      sampleCount: sampleCount,
      baselineSideLabel: baselineSideLabel,
    );
  }
}

class RangeRepThresholdResolution {
  const RangeRepThresholdResolution({
    required this.baseThreshold,
    required this.techniqueAcceptanceThreshold,
    required this.isTechniqueThresholdCalibrationApplied,
    this.measurementCorrectionOffset,
    required this.decisionReason,
    this.sampleCount,
    this.baselineSideLabel,
  });

  const RangeRepThresholdResolution.fallback({
    required this.baseThreshold,
    required this.decisionReason,
    this.sampleCount,
    this.baselineSideLabel,
  }) : techniqueAcceptanceThreshold = baseThreshold,
       isTechniqueThresholdCalibrationApplied = false,
       measurementCorrectionOffset = null;

  const RangeRepThresholdResolution.measurementCorrectionCandidate({
    required this.baseThreshold,
    required double measurementCorrectionOffset,
    this.sampleCount,
    this.baselineSideLabel,
  }) : techniqueAcceptanceThreshold = baseThreshold,
       isTechniqueThresholdCalibrationApplied = false,
       measurementCorrectionOffset = measurementCorrectionOffset,
       decisionReason = 'measurement_correction_only';

  final double baseThreshold;

  /// Exercise-owned technique threshold. Calibration never rewrites this value.
  final double techniqueAcceptanceThreshold;

  /// Candidate correction for measurement-space calibration. It is not treated
  /// as proof that the user's calibration posture was correct technique.
  final double? measurementCorrectionOffset;
  final bool isTechniqueThresholdCalibrationApplied;
  final String decisionReason;
  final int? sampleCount;
  final String? baselineSideLabel;

  bool get hasMeasurementCorrectionCandidate =>
      measurementCorrectionOffset != null;

  // Compatibility aliases retained while diagnostics migrate terminology.
  double get effectiveThreshold => techniqueAcceptanceThreshold;
  bool get isApplied => isTechniqueThresholdCalibrationApplied;
  double? get offsetCandidate => measurementCorrectionOffset;
}
