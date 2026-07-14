import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../domain/models/calibration_snapshot.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/session_calibration_baseline.dart';
import 'engine_kind.dart';

class WorkoutCalibrationMetrics {
  const WorkoutCalibrationMetrics({
    this.currentBackAngle = 0.0,
    this.formThreshold = 0.0,
    this.isRangeRepFrameValid = true,
    this.hasPrimaryAngle = false,
    this.hasFormMetric = false,
    this.rangeRepInvalidReason,
    this.selectedRangeRepSide,
    this.rangeRepSideSelectionReason,
    this.rangeRepSideHysteresisStatus,
    this.rangeRepSideConsistencyStatus,
    this.leftRangeRepCoverage = 0,
    this.rightRangeRepCoverage = 0,
    this.leftRangeRepSideConfidence,
    this.rightRangeRepSideConfidence,
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
    this.currentRepWorstBackAngle = 0.0,
    this.currentRepHadFormViolation = false,
    this.rangeRepPhaseGateStatus = 'stable',
    this.rangeRepPendingTransition,
    this.rangeRepLastConfirmedTransition,
    this.rangeRepInvalidFrameStreak = 0,
    this.rangeRepInvalidDurationMs = 0,
    this.rangeRepResyncTriggered = false,
    this.rangeRepResyncReason,
    this.rangeRepVisibilityStatus = 'stable',
    this.descendingPhaseDurationMs,
    this.peakPhaseDurationMs,
    this.ascendingPhaseDurationMs,
    this.descendingPhaseWorstFormMetric,
    this.peakPhaseWorstFormMetric,
    this.ascendingPhaseWorstFormMetric,
    this.descendingPhaseHadFormViolation = false,
    this.peakPhaseHadFormViolation = false,
    this.ascendingPhaseHadFormViolation = false,
    this.descendingPhaseStatus = 'unavailable',
    this.peakPhaseStatus = 'unavailable',
    this.ascendingPhaseStatus = 'unavailable',
    this.descendingPhaseIssues = const <String>[],
    this.peakPhaseIssues = const <String>[],
    this.ascendingPhaseIssues = const <String>[],
    this.phaseQualityPenalty,
    this.phaseAdjustedScore,
    this.phaseFeedbackCandidate,
    this.hasLastRangeRepValidation = false,
    this.lastRangeRepValidationStatus,
    this.lastRangeRepValidationReasons = const <String>[],
    this.lastRangeRepValidatedRepIndex,
    this.rangeRepValidatedCount = 0,
    this.rangeRepLowConfidenceCount = 0,
    this.rangeRepInvalidCount = 0,
    this.hasLastRangeRepSummary = false,
    this.lastRangeRepSummaryMinAngle,
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
    this.calibrationSnapshot,
    this.baseFormThreshold,
    this.effectiveFormThreshold,
    this.calibrationThresholdOffsetCandidate,
    this.calibrationThresholdOffsetApplied = false,
    this.calibrationThresholdOffsetFallbackReason,
    this.calibrationThresholdOffsetSampleCount,
    this.calibrationThresholdOffsetBaselineSideLabel,
    this.calibrationThresholdDecisionCount = 0,
    this.calibrationThresholdAppliedCount = 0,
    this.calibrationThresholdNoBaselineCount = 0,
    this.calibrationThresholdInsufficientSamplesCount = 0,
    this.calibrationThresholdMissingFormBaselineCount = 0,
    this.calibrationThresholdSideMismatchCount = 0,
    this.calibrationThresholdOffsetTooSmallCount = 0,
    this.sessionCalibrationBaselineCandidate,
  });

  final double currentBackAngle;
  final double formThreshold;
  final bool isRangeRepFrameValid;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final String? rangeRepInvalidReason;
  final String? selectedRangeRepSide;
  final String? rangeRepSideSelectionReason;
  final String? rangeRepSideHysteresisStatus;
  final String? rangeRepSideConsistencyStatus;
  final int leftRangeRepCoverage;
  final int rightRangeRepCoverage;
  final double? leftRangeRepSideConfidence;
  final double? rightRangeRepSideConfidence;
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
  final double currentRepWorstBackAngle;
  final bool currentRepHadFormViolation;
  final String rangeRepPhaseGateStatus;
  final String? rangeRepPendingTransition;
  final String? rangeRepLastConfirmedTransition;
  final int rangeRepInvalidFrameStreak;
  final int rangeRepInvalidDurationMs;
  final bool rangeRepResyncTriggered;
  final String? rangeRepResyncReason;
  final String rangeRepVisibilityStatus;
  final int? descendingPhaseDurationMs;
  final int? peakPhaseDurationMs;
  final int? ascendingPhaseDurationMs;
  final double? descendingPhaseWorstFormMetric;
  final double? peakPhaseWorstFormMetric;
  final double? ascendingPhaseWorstFormMetric;
  final bool descendingPhaseHadFormViolation;
  final bool peakPhaseHadFormViolation;
  final bool ascendingPhaseHadFormViolation;
  final String descendingPhaseStatus;
  final String peakPhaseStatus;
  final String ascendingPhaseStatus;
  final List<String> descendingPhaseIssues;
  final List<String> peakPhaseIssues;
  final List<String> ascendingPhaseIssues;
  final double? phaseQualityPenalty;
  final double? phaseAdjustedScore;
  final String? phaseFeedbackCandidate;
  final bool hasLastRangeRepValidation;
  final String? lastRangeRepValidationStatus;
  final List<String> lastRangeRepValidationReasons;
  final int? lastRangeRepValidatedRepIndex;
  final int rangeRepValidatedCount;
  final int rangeRepLowConfidenceCount;
  final int rangeRepInvalidCount;
  final bool hasLastRangeRepSummary;
  final double? lastRangeRepSummaryMinAngle;
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
  final CalibrationSnapshot? calibrationSnapshot;
  final double? baseFormThreshold;
  final double? effectiveFormThreshold;
  final double? calibrationThresholdOffsetCandidate;
  final bool calibrationThresholdOffsetApplied;
  final String? calibrationThresholdOffsetFallbackReason;
  final int? calibrationThresholdOffsetSampleCount;
  final String? calibrationThresholdOffsetBaselineSideLabel;
  final int calibrationThresholdDecisionCount;
  final int calibrationThresholdAppliedCount;
  final int calibrationThresholdNoBaselineCount;
  final int calibrationThresholdInsufficientSamplesCount;
  final int calibrationThresholdMissingFormBaselineCount;
  final int calibrationThresholdSideMismatchCount;
  final int calibrationThresholdOffsetTooSmallCount;
  final SessionCalibrationBaseline? sessionCalibrationBaselineCandidate;
}

class WorkoutState {
  static const Object _selectedHoldSideUnset = Object();

  final List<PoseLandmark>? landmarks;
  final EngineKind analysisKind;
  final int repCount;
  final bool isFormBad;
  final double currentAngle;
  final double lastRepScore;
  final double lastRepROM;
  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final HoldSide? selectedHoldSide;
  final bool isHolding;
  final bool isHoldVisibilitySuspended;
  final bool hadHoldFormBreak;
  final String feedbackMessage;
  final String currentPhase;
  final double cameraFps;
  final double analysisFps;
  final WorkoutCalibrationMetrics calibrationMetrics;

  WorkoutState({
    this.landmarks,
    this.analysisKind = EngineKind.rangeRep,
    this.repCount = 0,
    this.isFormBad = false,
    this.currentAngle = 0.0,
    this.lastRepScore = 0.0,
    this.lastRepROM = 0.0,
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.selectedHoldSide,
    this.isHolding = false,
    this.isHoldVisibilitySuspended = false,
    this.hadHoldFormBreak = false,
    this.feedbackMessage = 'Hazir misin?',
    this.currentPhase = 'NEUTRAL',
    this.cameraFps = 0.0,
    this.analysisFps = 0.0,
    this.calibrationMetrics = const WorkoutCalibrationMetrics(),
  });

  // Mevcut durumu secili alanlarla kopyalar.
  WorkoutState copyWith({
    List<PoseLandmark>? landmarks,
    EngineKind? analysisKind,
    int? repCount,
    bool? isFormBad,
    double? currentAngle,
    double? lastRepScore,
    double? lastRepROM,
    double? currentHoldSeconds,
    double? bestHoldSeconds,
    Object? selectedHoldSide = _selectedHoldSideUnset,
    bool? isHolding,
    bool? isHoldVisibilitySuspended,
    bool? hadHoldFormBreak,
    String? feedbackMessage,
    String? currentPhase,
    double? cameraFps,
    double? analysisFps,
    WorkoutCalibrationMetrics? calibrationMetrics,
  }) {
    return WorkoutState(
      landmarks: landmarks ?? this.landmarks,
      analysisKind: analysisKind ?? this.analysisKind,
      repCount: repCount ?? this.repCount,
      isFormBad: isFormBad ?? this.isFormBad,
      currentAngle: currentAngle ?? this.currentAngle,
      lastRepScore: lastRepScore ?? this.lastRepScore,
      lastRepROM: lastRepROM ?? this.lastRepROM,
      currentHoldSeconds: currentHoldSeconds ?? this.currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds ?? this.bestHoldSeconds,
      selectedHoldSide: selectedHoldSide == _selectedHoldSideUnset
          ? this.selectedHoldSide
          : selectedHoldSide as HoldSide?,
      isHolding: isHolding ?? this.isHolding,
      isHoldVisibilitySuspended:
          isHoldVisibilitySuspended ?? this.isHoldVisibilitySuspended,
      hadHoldFormBreak: hadHoldFormBreak ?? this.hadHoldFormBreak,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      currentPhase: currentPhase ?? this.currentPhase,
      cameraFps: cameraFps ?? this.cameraFps,
      analysisFps: analysisFps ?? this.analysisFps,
      calibrationMetrics: calibrationMetrics ?? this.calibrationMetrics,
    );
  }
}
