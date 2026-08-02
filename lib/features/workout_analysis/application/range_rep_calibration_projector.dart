import '../domain/models/calibration_snapshot.dart';
import '../domain/models/session_calibration_baseline.dart';
import '../domain/range_rep_diagnostics.dart';
import 'calibration_snapshot_builder.dart';
import 'engine_kind.dart';
import 'range_rep_frame_policy.dart';
import 'session_calibration_baseline_accumulator.dart';
import 'workout_calibration_metrics_builder.dart';
import 'workout_state.dart';

class RangeRepCalibrationProjectionRequest {
  const RangeRepCalibrationProjectionRequest({
    required this.diagnostics,
    required this.repTelemetry,
    required this.currentFormMetric,
    required this.thresholdValue,
    required this.rangeRepSideHysteresisStatus,
    required this.rangeRepSideConsistencyStatus,
    required this.calibrationThresholdDecisionCount,
    required this.calibrationThresholdAppliedCount,
    required this.calibrationThresholdNoBaselineCount,
    required this.calibrationThresholdInsufficientSamplesCount,
    required this.calibrationThresholdMissingFormBaselineCount,
    required this.calibrationThresholdSideMismatchCount,
    required this.calibrationThresholdOffsetTooSmallCount,
    required this.rangeRepAutomaticSideSelectionEnabled,
    this.currentPrimaryMetric,
    this.baseFormThreshold,
    this.effectiveFormThreshold,
    this.calibrationThresholdOffsetCandidate,
    this.calibrationThresholdOffsetApplied = false,
    this.calibrationThresholdOffsetFallbackReason,
    this.calibrationThresholdOffsetSampleCount,
    this.calibrationThresholdOffsetBaselineSideLabel,
    this.isRangeRepFrameValid = true,
    this.hasPrimaryAngle = false,
    this.hasFormMetric = false,
    this.rangeRepInvalidReason,
    this.selectedRangeRepSide,
    this.rangeRepSideSelectionReason,
    this.rangeRepMovementSelectedSide,
    this.leftRangeRepCoverage = 0,
    this.rightRangeRepCoverage = 0,
    this.leftRangeRepSideConfidence,
    this.rightRangeRepSideConfidence,
    this.rangeRepInvalidFrameStreak = 0,
    this.rangeRepInvalidDurationMs = 0,
    this.rangeRepResyncTriggered = false,
    this.rangeRepResyncReason,
    this.rangeRepVisibilityStatus = 'stable',
    this.currentBodyLineAngle,
    this.currentArmSupportAngle,
    this.currentLegExtensionAngle,
    this.currentTorsoAngle,
    this.currentDepthMetric,
    this.currentAlignmentMetric,
    this.currentStabilityMetric,
    this.currentLockoutMetric,
    this.currentBottomControlMetric,
    this.hasBodyLineAngle = false,
    this.hasArmSupportAngle = false,
    this.hasLegExtensionAngle = false,
  });

  final RangeRepDiagnosticsSnapshot diagnostics;
  final RangeRepRepTelemetrySnapshot repTelemetry;
  final double currentFormMetric;
  final double thresholdValue;
  final double? currentPrimaryMetric;
  final String? rangeRepSideHysteresisStatus;
  final String? rangeRepSideConsistencyStatus;
  final int calibrationThresholdDecisionCount;
  final int calibrationThresholdAppliedCount;
  final int calibrationThresholdNoBaselineCount;
  final int calibrationThresholdInsufficientSamplesCount;
  final int calibrationThresholdMissingFormBaselineCount;
  final int calibrationThresholdSideMismatchCount;
  final int calibrationThresholdOffsetTooSmallCount;
  final double? baseFormThreshold;
  final double? effectiveFormThreshold;
  final double? calibrationThresholdOffsetCandidate;
  final bool calibrationThresholdOffsetApplied;
  final String? calibrationThresholdOffsetFallbackReason;
  final int? calibrationThresholdOffsetSampleCount;
  final String? calibrationThresholdOffsetBaselineSideLabel;
  final bool isRangeRepFrameValid;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final RangeRepFrameInvalidReason? rangeRepInvalidReason;
  final String? selectedRangeRepSide;
  final String? rangeRepSideSelectionReason;
  final bool rangeRepAutomaticSideSelectionEnabled;
  final String? rangeRepMovementSelectedSide;
  final int leftRangeRepCoverage;
  final int rightRangeRepCoverage;
  final double? leftRangeRepSideConfidence;
  final double? rightRangeRepSideConfidence;
  final int rangeRepInvalidFrameStreak;
  final int rangeRepInvalidDurationMs;
  final bool rangeRepResyncTriggered;
  final String? rangeRepResyncReason;
  final String rangeRepVisibilityStatus;
  final double? currentBodyLineAngle;
  final double? currentArmSupportAngle;
  final double? currentLegExtensionAngle;
  final double? currentTorsoAngle;
  final double? currentDepthMetric;
  final double? currentAlignmentMetric;
  final double? currentStabilityMetric;
  final double? currentLockoutMetric;
  final double? currentBottomControlMetric;
  final bool hasBodyLineAngle;
  final bool hasArmSupportAngle;
  final bool hasLegExtensionAngle;
}

/// Owns range-rep calibration snapshot accumulation and projects the immutable
/// runtime metrics payload consumed by the live state.
class RangeRepCalibrationProjector {
  RangeRepCalibrationProjector({
    CalibrationSnapshotBuilder snapshotBuilder =
        const CalibrationSnapshotBuilder(),
    WorkoutCalibrationMetricsBuilder metricsBuilder =
        const WorkoutCalibrationMetricsBuilder(),
    SessionCalibrationBaselineAccumulator? baselineAccumulator,
  }) : _snapshotBuilder = snapshotBuilder,
       _metricsBuilder = metricsBuilder,
       _baselineAccumulator =
           baselineAccumulator ?? SessionCalibrationBaselineAccumulator();

  final CalibrationSnapshotBuilder _snapshotBuilder;
  final WorkoutCalibrationMetricsBuilder _metricsBuilder;
  final SessionCalibrationBaselineAccumulator _baselineAccumulator;

  CalibrationSnapshot? _lastCalibrationSnapshot;
  SessionCalibrationBaseline? _sessionCalibrationBaseline;

  CalibrationSnapshot? get lastCalibrationSnapshot => _lastCalibrationSnapshot;
  SessionCalibrationBaseline? get sessionCalibrationBaseline =>
      _sessionCalibrationBaseline;

  WorkoutCalibrationMetrics project(
    RangeRepCalibrationProjectionRequest request,
  ) {
    final calibrationSnapshotCandidate = _snapshotBuilder.buildCandidate(
      engineKind: EngineKind.rangeRep,
      diagnostics: request.diagnostics,
      currentPrimaryMetric: request.currentPrimaryMetric,
      currentFormMetric: request.currentFormMetric,
      hasPrimaryAngle: request.hasPrimaryAngle,
      hasFormMetric: request.hasFormMetric,
      isRangeRepFrameValid: request.isRangeRepFrameValid,
      selectedRangeRepSide: request.selectedRangeRepSide,
      currentTorsoAngle: request.currentTorsoAngle,
      currentDepthMetric: request.currentDepthMetric,
      currentAlignmentMetric: request.currentAlignmentMetric,
      currentStabilityMetric: request.currentStabilityMetric,
      currentLockoutMetric: request.currentLockoutMetric,
      currentBottomControlMetric: request.currentBottomControlMetric,
    );

    if (calibrationSnapshotCandidate != null) {
      _lastCalibrationSnapshot = calibrationSnapshotCandidate;
      if (_baselineAccumulator.addIfAccepted(calibrationSnapshotCandidate)) {
        _sessionCalibrationBaseline = _baselineAccumulator.baseline;
      }
    }

    return _metricsBuilder.buildRangeRepRuntime(
      currentFormMetric: request.currentFormMetric,
      thresholdValue: request.thresholdValue,
      diagnostics: request.diagnostics,
      repTelemetry: request.repTelemetry,
      rangeRepSideHysteresisStatus: request.rangeRepSideHysteresisStatus,
      rangeRepSideConsistencyStatus: request.rangeRepSideConsistencyStatus,
      calibrationSnapshot: _lastCalibrationSnapshot,
      calibrationThresholdDecisionCount:
          request.calibrationThresholdDecisionCount,
      calibrationThresholdAppliedCount:
          request.calibrationThresholdAppliedCount,
      calibrationThresholdNoBaselineCount:
          request.calibrationThresholdNoBaselineCount,
      calibrationThresholdInsufficientSamplesCount:
          request.calibrationThresholdInsufficientSamplesCount,
      calibrationThresholdMissingFormBaselineCount:
          request.calibrationThresholdMissingFormBaselineCount,
      calibrationThresholdSideMismatchCount:
          request.calibrationThresholdSideMismatchCount,
      calibrationThresholdOffsetTooSmallCount:
          request.calibrationThresholdOffsetTooSmallCount,
      sessionCalibrationBaselineCandidate: _sessionCalibrationBaseline,
      baseFormThreshold: request.baseFormThreshold,
      effectiveFormThreshold: request.effectiveFormThreshold,
      calibrationThresholdOffsetCandidate:
          request.calibrationThresholdOffsetCandidate,
      calibrationThresholdOffsetApplied:
          request.calibrationThresholdOffsetApplied,
      calibrationThresholdOffsetFallbackReason:
          request.calibrationThresholdOffsetFallbackReason,
      calibrationThresholdOffsetSampleCount:
          request.calibrationThresholdOffsetSampleCount,
      calibrationThresholdOffsetBaselineSideLabel:
          request.calibrationThresholdOffsetBaselineSideLabel,
      isRangeRepFrameValid: request.isRangeRepFrameValid,
      hasPrimaryAngle: request.hasPrimaryAngle,
      hasFormMetric: request.hasFormMetric,
      rangeRepInvalidReason: request.rangeRepInvalidReason,
      selectedRangeRepSide: request.selectedRangeRepSide,
      rangeRepSideSelectionReason: request.rangeRepSideSelectionReason,
      rangeRepAutomaticSideSelectionEnabled:
          request.rangeRepAutomaticSideSelectionEnabled,
      rangeRepMovementSelectedSide: request.rangeRepMovementSelectedSide,
      leftRangeRepCoverage: request.leftRangeRepCoverage,
      rightRangeRepCoverage: request.rightRangeRepCoverage,
      leftRangeRepSideConfidence: request.leftRangeRepSideConfidence,
      rightRangeRepSideConfidence: request.rightRangeRepSideConfidence,
      rangeRepInvalidFrameStreak: request.rangeRepInvalidFrameStreak,
      rangeRepInvalidDurationMs: request.rangeRepInvalidDurationMs,
      rangeRepResyncTriggered: request.rangeRepResyncTriggered,
      rangeRepResyncReason: request.rangeRepResyncReason,
      rangeRepVisibilityStatus: request.rangeRepVisibilityStatus,
      currentBodyLineAngle: request.currentBodyLineAngle,
      currentArmSupportAngle: request.currentArmSupportAngle,
      currentLegExtensionAngle: request.currentLegExtensionAngle,
      currentTorsoAngle: request.currentTorsoAngle,
      currentDepthMetric: request.currentDepthMetric,
      currentAlignmentMetric: request.currentAlignmentMetric,
      currentStabilityMetric: request.currentStabilityMetric,
      currentLockoutMetric: request.currentLockoutMetric,
      currentBottomControlMetric: request.currentBottomControlMetric,
      hasBodyLineAngle: request.hasBodyLineAngle,
      hasArmSupportAngle: request.hasArmSupportAngle,
      hasLegExtensionAngle: request.hasLegExtensionAngle,
    );
  }
}
