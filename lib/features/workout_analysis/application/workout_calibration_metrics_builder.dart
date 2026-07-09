import '../domain/models/calibration_snapshot.dart';
import '../domain/models/range_rep_rep_summary.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/rep_score_breakdown.dart';
import '../domain/models/session_calibration_baseline.dart';
import '../domain/range_rep_diagnostics.dart';
import 'range_rep_frame_policy.dart';
import 'workout_state.dart';

/// Builds the current workout calibration/telemetry payload.
class WorkoutCalibrationMetricsBuilder {
  const WorkoutCalibrationMetricsBuilder();

  WorkoutCalibrationMetrics build({
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
    return WorkoutCalibrationMetrics(
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
      rangeRepLastConfirmedTransition: diagnostics.lastConfirmedTransitionLabel,
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
      descendingPhaseWorstFormMetric: diagnostics.descendingPhaseQuality.hasData
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
      ascendingPhaseHadFormViolation: diagnostics.ascendingPhaseQuality.hasData
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
      phaseQualityPenalty: lastBreakdown?.phaseQualityPenalty,
      phaseAdjustedScore: lastBreakdown?.phaseAdjustedScore,
      phaseFeedbackCandidate: diagnostics.phaseFeedbackCandidate,
      hasLastRangeRepValidation: lastValidationResult != null,
      lastRangeRepValidationStatus: lastValidationResult?.status.debugLabel,
      lastRangeRepValidationReasons: lastValidationResult == null
          ? const <String>[]
          : lastValidationResult.reasons
                .map((reason) => reason.debugLabel)
                .toList(growable: false),
      lastRangeRepValidatedRepIndex: lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: rangeRepValidatedCount,
      rangeRepLowConfidenceCount: rangeRepLowConfidenceCount,
      rangeRepInvalidCount: rangeRepInvalidCount,
      hasLastRangeRepSummary: lastSummaryCandidate != null,
      lastRangeRepSummaryMinAngle: lastSummaryCandidate?.minAngle,
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
      calibrationSnapshot: calibrationSnapshot,
      baseFormThreshold: baseFormThreshold,
      effectiveFormThreshold: effectiveFormThreshold ?? thresholdValue,
      calibrationThresholdOffsetCandidate: calibrationThresholdOffsetCandidate,
      calibrationThresholdOffsetApplied: calibrationThresholdOffsetApplied,
      calibrationThresholdOffsetFallbackReason:
          calibrationThresholdOffsetFallbackReason,
      calibrationThresholdOffsetSampleCount:
          calibrationThresholdOffsetSampleCount,
      calibrationThresholdOffsetBaselineSideLabel:
          calibrationThresholdOffsetBaselineSideLabel,
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
    );
  }
}
