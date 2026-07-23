import '../domain/models/calibration_snapshot.dart';
import '../domain/models/hold_signal_validity.dart';
import '../domain/models/hold_signal_values.dart';
import '../domain/models/range_rep_rep_summary.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/rep_score_breakdown.dart';
import '../domain/models/session_calibration_baseline.dart';
import '../domain/range_rep_diagnostics.dart';
import 'range_rep_frame_policy.dart';
import 'workout_state.dart';

/// Immutable completed-rep telemetry reused between ordinary camera frames.
///
/// Validation, summary, and score-breakdown values only change when a rep
/// outcome is produced. Keeping the flattened values here prevents the live
/// frame path from rebuilding the same lists and rep payload on every frame.
class RangeRepRepTelemetrySnapshot {
  const RangeRepRepTelemetrySnapshot({
    this.phaseQualityPenalty,
    this.phaseAdjustedScore,
    this.hasLastRangeRepValidation = false,
    this.lastRangeRepValidationStatus,
    this.lastRangeRepValidationReasons = const <String>[],
    this.lastRangeRepValidatedRepIndex,
    this.rangeRepValidatedCount = 0,
    this.rangeRepLowConfidenceCount = 0,
    this.rangeRepInvalidCount = 0,
    this.hasLastRangeRepSummary = false,
    this.lastRangeRepSummaryMinAngle,
    this.lastRangeRepSummaryPrimaryRom,
    this.lastRangeRepSummaryConfidence,
    this.lastRangeRepSummaryCoverageQuality,
    this.lastRangeRepSummaryWorstFormMetric,
    this.lastRangeRepSummaryDescentMillis,
    this.lastRangeRepSummaryAscentMillis,
    this.lastRangeRepSummaryHadFormViolation = false,
    this.lastRangeRepSummaryHadCoverageDrop = false,
    this.lastRangeRepSummarySwitchedSideDuringRep = false,
    this.lastRangeRepSummaryCompletedPhaseSequence = false,
    this.lastRangeRepSummarySelectedSideLabel,
    this.hasLastRepBreakdown = false,
    this.lastRepRomScore = 0.0,
    this.lastRepDescentScore = 0.0,
    this.lastRepAscentScore = 0.0,
    this.lastRepWorstBackAngle = 0.0,
    this.lastRepHadFormViolation = false,
  });

  final double? phaseQualityPenalty;
  final double? phaseAdjustedScore;
  final bool hasLastRangeRepValidation;
  final String? lastRangeRepValidationStatus;
  final List<String> lastRangeRepValidationReasons;
  final int? lastRangeRepValidatedRepIndex;
  final int rangeRepValidatedCount;
  final int rangeRepLowConfidenceCount;
  final int rangeRepInvalidCount;
  final bool hasLastRangeRepSummary;
  final double? lastRangeRepSummaryMinAngle;
  final double? lastRangeRepSummaryPrimaryRom;
  final double? lastRangeRepSummaryConfidence;
  final double? lastRangeRepSummaryCoverageQuality;
  final double? lastRangeRepSummaryWorstFormMetric;
  final int? lastRangeRepSummaryDescentMillis;
  final int? lastRangeRepSummaryAscentMillis;
  final bool lastRangeRepSummaryHadFormViolation;
  final bool lastRangeRepSummaryHadCoverageDrop;
  final bool lastRangeRepSummarySwitchedSideDuringRep;
  final bool lastRangeRepSummaryCompletedPhaseSequence;
  final String? lastRangeRepSummarySelectedSideLabel;
  final bool hasLastRepBreakdown;
  final double lastRepRomScore;
  final double lastRepDescentScore;
  final double lastRepAscentScore;
  final double lastRepWorstBackAngle;
  final bool lastRepHadFormViolation;
}

/// Builds the current workout calibration/telemetry payload.
class WorkoutCalibrationMetricsBuilder {
  const WorkoutCalibrationMetricsBuilder();

  /// Compatibility entry point that builds both runtime and completed-rep
  /// telemetry. Production frame processing uses [buildRangeRepRuntime] and
  /// refreshes [RangeRepRepTelemetrySnapshot] only when a rep outcome changes.
  WorkoutCalibrationMetrics buildRangeRep({
    required double currentFormMetric,
    required double thresholdValue,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required RepScoreBreakdown? lastBreakdown,
    required RangeRepValidationResult? lastValidationResult,
    required RangeRepRepSummary? lastSummaryCandidate,
    required String? rangeRepSideHysteresisStatus,
    required String? rangeRepSideConsistencyStatus,
    required CalibrationSnapshot? calibrationSnapshot,
    required int calibrationThresholdDecisionCount,
    required int calibrationThresholdAppliedCount,
    required int calibrationThresholdNoBaselineCount,
    required int calibrationThresholdInsufficientSamplesCount,
    required int calibrationThresholdMissingFormBaselineCount,
    required int calibrationThresholdSideMismatchCount,
    required int calibrationThresholdOffsetTooSmallCount,
    required SessionCalibrationBaseline? sessionCalibrationBaselineCandidate,
    required int? lastRangeRepValidatedRepIndex,
    required int rangeRepValidatedCount,
    required int rangeRepLowConfidenceCount,
    required int rangeRepInvalidCount,
    double? baseFormThreshold,
    double? effectiveFormThreshold,
    double? calibrationThresholdOffsetCandidate,
    bool calibrationThresholdOffsetApplied = false,
    String? calibrationThresholdOffsetFallbackReason,
    int? calibrationThresholdOffsetSampleCount,
    String? calibrationThresholdOffsetBaselineSideLabel,
    bool isRangeRepFrameValid = true,
    bool hasPrimaryAngle = false,
    bool hasFormMetric = false,
    RangeRepFrameInvalidReason? rangeRepInvalidReason,
    String? selectedRangeRepSide,
    String? rangeRepSideSelectionReason,
    int leftRangeRepCoverage = 0,
    int rightRangeRepCoverage = 0,
    double? leftRangeRepSideConfidence,
    double? rightRangeRepSideConfidence,
    int rangeRepInvalidFrameStreak = 0,
    int rangeRepInvalidDurationMs = 0,
    bool rangeRepResyncTriggered = false,
    String? rangeRepResyncReason,
    String rangeRepVisibilityStatus = 'stable',
    double? currentBodyLineAngle,
    double? currentArmSupportAngle,
    double? currentLegExtensionAngle,
    double? currentTorsoAngle,
    double? currentDepthMetric,
    double? currentAlignmentMetric,
    double? currentStabilityMetric,
    double? currentLockoutMetric,
    double? currentBottomControlMetric,
    bool hasBodyLineAngle = false,
    bool hasArmSupportAngle = false,
    bool hasLegExtensionAngle = false,
  }) {
    final repTelemetry = buildRangeRepRepTelemetry(
      lastBreakdown: lastBreakdown,
      lastValidationResult: lastValidationResult,
      lastSummaryCandidate: lastSummaryCandidate,
      lastRangeRepValidatedRepIndex: lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: rangeRepValidatedCount,
      rangeRepLowConfidenceCount: rangeRepLowConfidenceCount,
      rangeRepInvalidCount: rangeRepInvalidCount,
    );

    return buildRangeRepRuntime(
      currentFormMetric: currentFormMetric,
      thresholdValue: thresholdValue,
      diagnostics: diagnostics,
      repTelemetry: repTelemetry,
      rangeRepSideHysteresisStatus: rangeRepSideHysteresisStatus,
      rangeRepSideConsistencyStatus: rangeRepSideConsistencyStatus,
      calibrationSnapshot: calibrationSnapshot,
      calibrationThresholdDecisionCount: calibrationThresholdDecisionCount,
      calibrationThresholdAppliedCount: calibrationThresholdAppliedCount,
      calibrationThresholdNoBaselineCount: calibrationThresholdNoBaselineCount,
      calibrationThresholdInsufficientSamplesCount:
          calibrationThresholdInsufficientSamplesCount,
      calibrationThresholdMissingFormBaselineCount:
          calibrationThresholdMissingFormBaselineCount,
      calibrationThresholdSideMismatchCount:
          calibrationThresholdSideMismatchCount,
      calibrationThresholdOffsetTooSmallCount:
          calibrationThresholdOffsetTooSmallCount,
      sessionCalibrationBaselineCandidate: sessionCalibrationBaselineCandidate,
      baseFormThreshold: baseFormThreshold,
      effectiveFormThreshold: effectiveFormThreshold,
      calibrationThresholdOffsetCandidate: calibrationThresholdOffsetCandidate,
      calibrationThresholdOffsetApplied: calibrationThresholdOffsetApplied,
      calibrationThresholdOffsetFallbackReason:
          calibrationThresholdOffsetFallbackReason,
      calibrationThresholdOffsetSampleCount:
          calibrationThresholdOffsetSampleCount,
      calibrationThresholdOffsetBaselineSideLabel:
          calibrationThresholdOffsetBaselineSideLabel,
      isRangeRepFrameValid: isRangeRepFrameValid,
      hasPrimaryAngle: hasPrimaryAngle,
      hasFormMetric: hasFormMetric,
      rangeRepInvalidReason: rangeRepInvalidReason,
      selectedRangeRepSide: selectedRangeRepSide,
      rangeRepSideSelectionReason: rangeRepSideSelectionReason,
      leftRangeRepCoverage: leftRangeRepCoverage,
      rightRangeRepCoverage: rightRangeRepCoverage,
      leftRangeRepSideConfidence: leftRangeRepSideConfidence,
      rightRangeRepSideConfidence: rightRangeRepSideConfidence,
      rangeRepInvalidFrameStreak: rangeRepInvalidFrameStreak,
      rangeRepInvalidDurationMs: rangeRepInvalidDurationMs,
      rangeRepResyncTriggered: rangeRepResyncTriggered,
      rangeRepResyncReason: rangeRepResyncReason,
      rangeRepVisibilityStatus: rangeRepVisibilityStatus,
      currentBodyLineAngle: currentBodyLineAngle,
      currentArmSupportAngle: currentArmSupportAngle,
      currentLegExtensionAngle: currentLegExtensionAngle,
      currentTorsoAngle: currentTorsoAngle,
      currentDepthMetric: currentDepthMetric,
      currentAlignmentMetric: currentAlignmentMetric,
      currentStabilityMetric: currentStabilityMetric,
      currentLockoutMetric: currentLockoutMetric,
      currentBottomControlMetric: currentBottomControlMetric,
      hasBodyLineAngle: hasBodyLineAngle,
      hasArmSupportAngle: hasArmSupportAngle,
      hasLegExtensionAngle: hasLegExtensionAngle,
    );
  }

  RangeRepRepTelemetrySnapshot buildRangeRepRepTelemetry({
    required RepScoreBreakdown? lastBreakdown,
    required RangeRepValidationResult? lastValidationResult,
    required RangeRepRepSummary? lastSummaryCandidate,
    required int? lastRangeRepValidatedRepIndex,
    required int rangeRepValidatedCount,
    required int rangeRepLowConfidenceCount,
    required int rangeRepInvalidCount,
  }) {
    return RangeRepRepTelemetrySnapshot(
      phaseQualityPenalty: lastBreakdown?.phaseQualityPenalty,
      phaseAdjustedScore: lastBreakdown?.phaseAdjustedScore,
      hasLastRangeRepValidation: lastValidationResult != null,
      lastRangeRepValidationStatus: lastValidationResult?.status.debugLabel,
      lastRangeRepValidationReasons: lastValidationResult == null
          ? const <String>[]
          : List<String>.unmodifiable(
              lastValidationResult.reasons.map((reason) => reason.debugLabel),
            ),
      lastRangeRepValidatedRepIndex: lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: rangeRepValidatedCount,
      rangeRepLowConfidenceCount: rangeRepLowConfidenceCount,
      rangeRepInvalidCount: rangeRepInvalidCount,
      hasLastRangeRepSummary: lastSummaryCandidate != null,
      lastRangeRepSummaryMinAngle: lastSummaryCandidate?.minAngle,
      lastRangeRepSummaryPrimaryRom: lastSummaryCandidate?.primaryRom,
      lastRangeRepSummaryConfidence: lastSummaryCandidate?.confidence,
      lastRangeRepSummaryCoverageQuality: lastSummaryCandidate?.coverageQuality,
      lastRangeRepSummaryWorstFormMetric: lastSummaryCandidate?.worstFormMetric,
      lastRangeRepSummaryDescentMillis:
          lastSummaryCandidate?.descentDuration.inMilliseconds,
      lastRangeRepSummaryAscentMillis:
          lastSummaryCandidate?.ascentDuration.inMilliseconds,
      lastRangeRepSummaryHadFormViolation:
          lastSummaryCandidate?.hadFormViolation ?? false,
      lastRangeRepSummaryHadCoverageDrop:
          lastSummaryCandidate?.hadCoverageDrop ?? false,
      lastRangeRepSummarySwitchedSideDuringRep:
          lastSummaryCandidate?.switchedSideDuringRep ?? false,
      lastRangeRepSummaryCompletedPhaseSequence:
          lastSummaryCandidate?.completedPhaseSequence ?? false,
      lastRangeRepSummarySelectedSideLabel:
          lastSummaryCandidate?.selectedSideLabel,
      hasLastRepBreakdown: lastBreakdown != null,
      lastRepRomScore: lastBreakdown?.romScore ?? 0,
      lastRepDescentScore: lastBreakdown?.descentScore ?? 0,
      lastRepAscentScore: lastBreakdown?.ascentScore ?? 0,
      lastRepWorstBackAngle: lastBreakdown?.worstBackAngle ?? 0,
      lastRepHadFormViolation: lastBreakdown?.hadFormViolation ?? false,
    );
  }

  WorkoutCalibrationMetrics buildRangeRepRuntime({
    required double currentFormMetric,
    required double thresholdValue,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required RangeRepRepTelemetrySnapshot repTelemetry,
    required String? rangeRepSideHysteresisStatus,
    required String? rangeRepSideConsistencyStatus,
    required CalibrationSnapshot? calibrationSnapshot,
    required int calibrationThresholdDecisionCount,
    required int calibrationThresholdAppliedCount,
    required int calibrationThresholdNoBaselineCount,
    required int calibrationThresholdInsufficientSamplesCount,
    required int calibrationThresholdMissingFormBaselineCount,
    required int calibrationThresholdSideMismatchCount,
    required int calibrationThresholdOffsetTooSmallCount,
    required SessionCalibrationBaseline? sessionCalibrationBaselineCandidate,
    double? baseFormThreshold,
    double? effectiveFormThreshold,
    double? calibrationThresholdOffsetCandidate,
    bool calibrationThresholdOffsetApplied = false,
    String? calibrationThresholdOffsetFallbackReason,
    int? calibrationThresholdOffsetSampleCount,
    String? calibrationThresholdOffsetBaselineSideLabel,
    bool isRangeRepFrameValid = true,
    bool hasPrimaryAngle = false,
    bool hasFormMetric = false,
    RangeRepFrameInvalidReason? rangeRepInvalidReason,
    String? selectedRangeRepSide,
    String? rangeRepSideSelectionReason,
    int leftRangeRepCoverage = 0,
    int rightRangeRepCoverage = 0,
    double? leftRangeRepSideConfidence,
    double? rightRangeRepSideConfidence,
    int rangeRepInvalidFrameStreak = 0,
    int rangeRepInvalidDurationMs = 0,
    bool rangeRepResyncTriggered = false,
    String? rangeRepResyncReason,
    String rangeRepVisibilityStatus = 'stable',
    double? currentBodyLineAngle,
    double? currentArmSupportAngle,
    double? currentLegExtensionAngle,
    double? currentTorsoAngle,
    double? currentDepthMetric,
    double? currentAlignmentMetric,
    double? currentStabilityMetric,
    double? currentLockoutMetric,
    double? currentBottomControlMetric,
    bool hasBodyLineAngle = false,
    bool hasArmSupportAngle = false,
    bool hasLegExtensionAngle = false,
  }) {
    return WorkoutCalibrationMetrics.rangeRep(
      payload: RangeRepWorkoutCalibrationMetrics(
        currentBackAngle: currentFormMetric,
        formThreshold: thresholdValue,
        isRangeRepFrameValid: isRangeRepFrameValid,
        hasPrimaryAngle: hasPrimaryAngle,
        hasFormMetric: hasFormMetric,
        rangeRepInvalidReason: rangeRepInvalidReason?.debugLabel,
        selectedRangeRepSide: selectedRangeRepSide,
        rangeRepSideSelectionReason: rangeRepSideSelectionReason,
        rangeRepSideHysteresisStatus: rangeRepSideHysteresisStatus,
        rangeRepSideConsistencyStatus: rangeRepSideConsistencyStatus,
        leftRangeRepCoverage: leftRangeRepCoverage,
        rightRangeRepCoverage: rightRangeRepCoverage,
        leftRangeRepSideConfidence: leftRangeRepSideConfidence,
        rightRangeRepSideConfidence: rightRangeRepSideConfidence,
        currentBodyLineAngle: currentBodyLineAngle,
        currentArmSupportAngle: currentArmSupportAngle,
        currentLegExtensionAngle: currentLegExtensionAngle,
        currentTorsoAngle: currentTorsoAngle,
        currentDepthMetric: currentDepthMetric,
        currentAlignmentMetric: currentAlignmentMetric,
        currentStabilityMetric: currentStabilityMetric,
        currentLockoutMetric: currentLockoutMetric,
        currentBottomControlMetric: currentBottomControlMetric,
        hasBodyLineAngle: hasBodyLineAngle,
        hasArmSupportAngle: hasArmSupportAngle,
        hasLegExtensionAngle: hasLegExtensionAngle,
        currentRepWorstBackAngle: diagnostics.currentRepWorstBackAngle,
        currentRepHadFormViolation: diagnostics.currentRepHadFormViolation,
        rangeRepPhaseGateStatus: diagnostics.phaseGateStatus,
        rangeRepPendingTransition: diagnostics.pendingTransitionLabel,
        rangeRepLastConfirmedTransition:
            diagnostics.lastConfirmedTransitionLabel,
        rangeRepInvalidFrameStreak: rangeRepInvalidFrameStreak,
        rangeRepInvalidDurationMs: rangeRepInvalidDurationMs,
        rangeRepResyncTriggered: rangeRepResyncTriggered,
        rangeRepResyncReason: rangeRepResyncReason,
        rangeRepVisibilityStatus: rangeRepVisibilityStatus,
        descendingPhaseDurationMs: diagnostics.descendingPhaseQuality.hasData
            ? diagnostics.descendingPhaseQuality.durationMs
            : null,
        peakPhaseDurationMs: diagnostics.peakPhaseQuality.hasData
            ? diagnostics.peakPhaseQuality.durationMs
            : null,
        ascendingPhaseDurationMs: diagnostics.ascendingPhaseQuality.hasData
            ? diagnostics.ascendingPhaseQuality.durationMs
            : null,
        descendingPhaseWorstFormMetric:
            diagnostics.descendingPhaseQuality.hasData
            ? diagnostics.descendingPhaseQuality.worstFormMetric
            : null,
        peakPhaseWorstFormMetric: diagnostics.peakPhaseQuality.hasData
            ? diagnostics.peakPhaseQuality.worstFormMetric
            : null,
        ascendingPhaseWorstFormMetric: diagnostics.ascendingPhaseQuality.hasData
            ? diagnostics.ascendingPhaseQuality.worstFormMetric
            : null,
        descendingPhaseHadFormViolation:
            diagnostics.descendingPhaseQuality.hasData
            ? diagnostics.descendingPhaseQuality.hadFormViolation
            : false,
        peakPhaseHadFormViolation: diagnostics.peakPhaseQuality.hasData
            ? diagnostics.peakPhaseQuality.hadFormViolation
            : false,
        ascendingPhaseHadFormViolation:
            diagnostics.ascendingPhaseQuality.hasData
            ? diagnostics.ascendingPhaseQuality.hadFormViolation
            : false,
        descendingPhaseStatus:
            diagnostics.descendingPhaseAssessment.status.debugLabel,
        peakPhaseStatus: diagnostics.peakPhaseAssessment.status.debugLabel,
        ascendingPhaseStatus:
            diagnostics.ascendingPhaseAssessment.status.debugLabel,
        descendingPhaseIssues: diagnostics.descendingPhaseAssessment.issues
            .map((issue) => issue.debugLabel)
            .toList(growable: false),
        peakPhaseIssues: diagnostics.peakPhaseAssessment.issues
            .map((issue) => issue.debugLabel)
            .toList(growable: false),
        ascendingPhaseIssues: diagnostics.ascendingPhaseAssessment.issues
            .map((issue) => issue.debugLabel)
            .toList(growable: false),
        phaseQualityPenalty: repTelemetry.phaseQualityPenalty,
        phaseAdjustedScore: repTelemetry.phaseAdjustedScore,
        phaseFeedbackCandidate: diagnostics.phaseFeedbackCandidate,
        hasLastRangeRepValidation: repTelemetry.hasLastRangeRepValidation,
        lastRangeRepValidationStatus: repTelemetry.lastRangeRepValidationStatus,
        lastRangeRepValidationReasons:
            repTelemetry.lastRangeRepValidationReasons,
        lastRangeRepValidatedRepIndex:
            repTelemetry.lastRangeRepValidatedRepIndex,
        rangeRepValidatedCount: repTelemetry.rangeRepValidatedCount,
        rangeRepLowConfidenceCount: repTelemetry.rangeRepLowConfidenceCount,
        rangeRepInvalidCount: repTelemetry.rangeRepInvalidCount,
        hasLastRangeRepSummary: repTelemetry.hasLastRangeRepSummary,
        lastRangeRepSummaryMinAngle: repTelemetry.lastRangeRepSummaryMinAngle,
        lastRangeRepSummaryPrimaryRom:
            repTelemetry.lastRangeRepSummaryPrimaryRom,
        lastRangeRepSummaryConfidence:
            repTelemetry.lastRangeRepSummaryConfidence,
        lastRangeRepSummaryCoverageQuality:
            repTelemetry.lastRangeRepSummaryCoverageQuality,
        lastRangeRepSummaryWorstFormMetric:
            repTelemetry.lastRangeRepSummaryWorstFormMetric,
        lastRangeRepSummaryDescentMillis:
            repTelemetry.lastRangeRepSummaryDescentMillis,
        lastRangeRepSummaryAscentMillis:
            repTelemetry.lastRangeRepSummaryAscentMillis,
        lastRangeRepSummaryHadFormViolation:
            repTelemetry.lastRangeRepSummaryHadFormViolation,
        lastRangeRepSummaryHadCoverageDrop:
            repTelemetry.lastRangeRepSummaryHadCoverageDrop,
        lastRangeRepSummarySwitchedSideDuringRep:
            repTelemetry.lastRangeRepSummarySwitchedSideDuringRep,
        lastRangeRepSummaryCompletedPhaseSequence:
            repTelemetry.lastRangeRepSummaryCompletedPhaseSequence,
        lastRangeRepSummarySelectedSideLabel:
            repTelemetry.lastRangeRepSummarySelectedSideLabel,
        hasLastRepBreakdown: repTelemetry.hasLastRepBreakdown,
        lastRepRomScore: repTelemetry.lastRepRomScore,
        lastRepDescentScore: repTelemetry.lastRepDescentScore,
        lastRepAscentScore: repTelemetry.lastRepAscentScore,
        lastRepWorstBackAngle: repTelemetry.lastRepWorstBackAngle,
        lastRepHadFormViolation: repTelemetry.lastRepHadFormViolation,
        calibrationSnapshot: calibrationSnapshot,
        baseFormThreshold: baseFormThreshold,
        effectiveFormThreshold: effectiveFormThreshold ?? thresholdValue,
        calibrationThresholdOffsetCandidate:
            calibrationThresholdOffsetCandidate,
        calibrationThresholdOffsetApplied: calibrationThresholdOffsetApplied,
        calibrationThresholdOffsetFallbackReason:
            calibrationThresholdOffsetFallbackReason,
        calibrationThresholdOffsetSampleCount:
            calibrationThresholdOffsetSampleCount,
        calibrationThresholdOffsetBaselineSideLabel:
            calibrationThresholdOffsetBaselineSideLabel,
        calibrationThresholdDecisionCount: calibrationThresholdDecisionCount,
        calibrationThresholdAppliedCount: calibrationThresholdAppliedCount,
        calibrationThresholdNoBaselineCount:
            calibrationThresholdNoBaselineCount,
        calibrationThresholdInsufficientSamplesCount:
            calibrationThresholdInsufficientSamplesCount,
        calibrationThresholdMissingFormBaselineCount:
            calibrationThresholdMissingFormBaselineCount,
        calibrationThresholdSideMismatchCount:
            calibrationThresholdSideMismatchCount,
        calibrationThresholdOffsetTooSmallCount:
            calibrationThresholdOffsetTooSmallCount,
        sessionCalibrationBaselineCandidate:
            sessionCalibrationBaselineCandidate,
      ),
    );
  }

  WorkoutCalibrationMetrics buildHold({
    required double currentFormMetric,
    HoldSignalValues? currentSignalValues,
    HoldSignalValues? targetSignalValues,
    HoldSignalValidity? signalValidity,
  }) {
    return WorkoutCalibrationMetrics.hold(
      payload: HoldWorkoutCalibrationMetrics(
        currentBackAngle: currentFormMetric,
        currentSignalValues: currentSignalValues,
        targetSignalValues: targetSignalValues,
        signalValidity: signalValidity,
      ),
    );
  }
}
