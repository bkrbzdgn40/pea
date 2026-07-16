import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/session_calibration_baseline.dart';

/// Resolves the effective range-rep form threshold from session calibration.
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

    if (baseline == null) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'no_baseline',
      );
    }

    if (baseline.analysisKind != analysisKind) {
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

    final offset = (baseline.formMetricBaseline! - baseThreshold)
        .clamp(
          -maxCalibrationThresholdOffsetMagnitude,
          maxCalibrationThresholdOffsetMagnitude,
        )
        .toDouble();
    if (offset.abs() < minCalibrationThresholdOffsetMagnitude) {
      return RangeRepThresholdResolution.fallback(
        baseThreshold: baseThreshold,
        decisionReason: 'offset_too_small',
        sampleCount: sampleCount,
        baselineSideLabel: baselineSideLabel,
      );
    }

    return RangeRepThresholdResolution(
      baseThreshold: baseThreshold,
      effectiveThreshold: config.resolveFormThreshold(offset: offset),
      isApplied: true,
      offsetCandidate: offset,
      decisionReason: 'applied',
      sampleCount: sampleCount,
      baselineSideLabel: baselineSideLabel,
    );
  }
}

class RangeRepThresholdResolution {
  const RangeRepThresholdResolution({
    required this.baseThreshold,
    required this.effectiveThreshold,
    required this.isApplied,
    this.offsetCandidate,
    required this.decisionReason,
    this.sampleCount,
    this.baselineSideLabel,
  });

  const RangeRepThresholdResolution.fallback({
    required this.baseThreshold,
    required this.decisionReason,
    this.sampleCount,
    this.baselineSideLabel,
  }) : effectiveThreshold = baseThreshold,
       isApplied = false,
       offsetCandidate = null;

  final double baseThreshold;
  final double effectiveThreshold;
  final bool isApplied;
  final double? offsetCandidate;
  final String decisionReason;
  final int? sampleCount;
  final String? baselineSideLabel;
}
