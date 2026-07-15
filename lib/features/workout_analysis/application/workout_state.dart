import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/calibration_snapshot.dart';
import '../domain/models/hold_feedback_code.dart';
import '../domain/models/hold_phase.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/session_calibration_baseline.dart';
import 'engine_kind.dart';

class RangeRepWorkoutCalibrationMetrics {
  const RangeRepWorkoutCalibrationMetrics({
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

class HoldWorkoutCalibrationMetrics {
  const HoldWorkoutCalibrationMetrics({
    this.currentBackAngle = 0.0,
    this.formThreshold = 0.0,
    this.currentBodyLineAngle,
    this.currentArmSupportAngle,
    this.currentLegExtensionAngle,
    this.hasBodyLineAngle = false,
    this.hasArmSupportAngle = false,
    this.hasLegExtensionAngle = false,
  });

  final double currentBackAngle;
  final double formThreshold;
  final double? currentBodyLineAngle;
  final double? currentArmSupportAngle;
  final double? currentLegExtensionAngle;
  final bool hasBodyLineAngle;
  final bool hasArmSupportAngle;
  final bool hasLegExtensionAngle;
}

class WorkoutCalibrationMetrics {
  const WorkoutCalibrationMetrics.rangeRep({
    RangeRepWorkoutCalibrationMetrics payload =
        const RangeRepWorkoutCalibrationMetrics(),
  }) : _rangeRep = payload,
       _hold = null;

  const WorkoutCalibrationMetrics.hold({
    HoldWorkoutCalibrationMetrics payload =
        const HoldWorkoutCalibrationMetrics(),
  }) : _rangeRep = null,
       _hold = payload;

  final RangeRepWorkoutCalibrationMetrics? _rangeRep;
  final HoldWorkoutCalibrationMetrics? _hold;

  RangeRepWorkoutCalibrationMetrics? get rangeRep => _rangeRep;
  HoldWorkoutCalibrationMetrics? get hold => _hold;

  EngineKind get analysisKind =>
      _rangeRep != null ? EngineKind.rangeRep : EngineKind.hold;

  double get currentBackAngle =>
      _rangeRep?.currentBackAngle ?? _hold?.currentBackAngle ?? 0.0;

  double get formThreshold =>
      _rangeRep?.formThreshold ?? _hold?.formThreshold ?? 0.0;

  bool get isRangeRepFrameValid => _rangeRep?.isRangeRepFrameValid ?? true;
  bool get hasPrimaryAngle => _rangeRep?.hasPrimaryAngle ?? false;
  bool get hasFormMetric => _rangeRep?.hasFormMetric ?? false;
  String? get rangeRepInvalidReason => _rangeRep?.rangeRepInvalidReason;
  String? get selectedRangeRepSide => _rangeRep?.selectedRangeRepSide;
  String? get rangeRepSideSelectionReason =>
      _rangeRep?.rangeRepSideSelectionReason;
  String? get rangeRepSideHysteresisStatus =>
      _rangeRep?.rangeRepSideHysteresisStatus;
  String? get rangeRepSideConsistencyStatus =>
      _rangeRep?.rangeRepSideConsistencyStatus;
  int get leftRangeRepCoverage => _rangeRep?.leftRangeRepCoverage ?? 0;
  int get rightRangeRepCoverage => _rangeRep?.rightRangeRepCoverage ?? 0;
  double? get leftRangeRepSideConfidence =>
      _rangeRep?.leftRangeRepSideConfidence;
  double? get rightRangeRepSideConfidence =>
      _rangeRep?.rightRangeRepSideConfidence;

  double? get currentBodyLineAngle =>
      _rangeRep?.currentBodyLineAngle ?? _hold?.currentBodyLineAngle;

  double? get currentArmSupportAngle =>
      _rangeRep?.currentArmSupportAngle ?? _hold?.currentArmSupportAngle;

  double? get currentLegExtensionAngle =>
      _rangeRep?.currentLegExtensionAngle ?? _hold?.currentLegExtensionAngle;

  double? get currentTorsoAngle => _rangeRep?.currentTorsoAngle;
  double? get currentDepthMetric => _rangeRep?.currentDepthMetric;
  double? get currentAlignmentMetric => _rangeRep?.currentAlignmentMetric;
  double? get currentStabilityMetric => _rangeRep?.currentStabilityMetric;
  double? get currentLockoutMetric => _rangeRep?.currentLockoutMetric;
  double? get currentBottomControlMetric =>
      _rangeRep?.currentBottomControlMetric;

  bool get hasBodyLineAngle =>
      _rangeRep?.hasBodyLineAngle ?? _hold?.hasBodyLineAngle ?? false;

  bool get hasArmSupportAngle =>
      _rangeRep?.hasArmSupportAngle ?? _hold?.hasArmSupportAngle ?? false;

  bool get hasLegExtensionAngle =>
      _rangeRep?.hasLegExtensionAngle ?? _hold?.hasLegExtensionAngle ?? false;

  double get currentRepWorstBackAngle =>
      _rangeRep?.currentRepWorstBackAngle ?? 0.0;

  bool get currentRepHadFormViolation =>
      _rangeRep?.currentRepHadFormViolation ?? false;

  String get rangeRepPhaseGateStatus =>
      _rangeRep?.rangeRepPhaseGateStatus ?? 'stable';

  String? get rangeRepPendingTransition => _rangeRep?.rangeRepPendingTransition;
  String? get rangeRepLastConfirmedTransition =>
      _rangeRep?.rangeRepLastConfirmedTransition;

  int get rangeRepInvalidFrameStreak =>
      _rangeRep?.rangeRepInvalidFrameStreak ?? 0;
  int get rangeRepInvalidDurationMs =>
      _rangeRep?.rangeRepInvalidDurationMs ?? 0;
  bool get rangeRepResyncTriggered =>
      _rangeRep?.rangeRepResyncTriggered ?? false;
  String? get rangeRepResyncReason => _rangeRep?.rangeRepResyncReason;
  String get rangeRepVisibilityStatus =>
      _rangeRep?.rangeRepVisibilityStatus ?? 'stable';

  int? get descendingPhaseDurationMs => _rangeRep?.descendingPhaseDurationMs;
  int? get peakPhaseDurationMs => _rangeRep?.peakPhaseDurationMs;
  int? get ascendingPhaseDurationMs => _rangeRep?.ascendingPhaseDurationMs;
  double? get descendingPhaseWorstFormMetric =>
      _rangeRep?.descendingPhaseWorstFormMetric;
  double? get peakPhaseWorstFormMetric => _rangeRep?.peakPhaseWorstFormMetric;
  double? get ascendingPhaseWorstFormMetric =>
      _rangeRep?.ascendingPhaseWorstFormMetric;
  bool get descendingPhaseHadFormViolation =>
      _rangeRep?.descendingPhaseHadFormViolation ?? false;
  bool get peakPhaseHadFormViolation =>
      _rangeRep?.peakPhaseHadFormViolation ?? false;
  bool get ascendingPhaseHadFormViolation =>
      _rangeRep?.ascendingPhaseHadFormViolation ?? false;
  String get descendingPhaseStatus =>
      _rangeRep?.descendingPhaseStatus ?? 'unavailable';
  String get peakPhaseStatus => _rangeRep?.peakPhaseStatus ?? 'unavailable';
  String get ascendingPhaseStatus =>
      _rangeRep?.ascendingPhaseStatus ?? 'unavailable';
  List<String> get descendingPhaseIssues =>
      _rangeRep?.descendingPhaseIssues ?? const <String>[];
  List<String> get peakPhaseIssues =>
      _rangeRep?.peakPhaseIssues ?? const <String>[];
  List<String> get ascendingPhaseIssues =>
      _rangeRep?.ascendingPhaseIssues ?? const <String>[];
  double? get phaseQualityPenalty => _rangeRep?.phaseQualityPenalty;
  double? get phaseAdjustedScore => _rangeRep?.phaseAdjustedScore;
  String? get phaseFeedbackCandidate => _rangeRep?.phaseFeedbackCandidate;
  bool get hasLastRangeRepValidation =>
      _rangeRep?.hasLastRangeRepValidation ?? false;
  String? get lastRangeRepValidationStatus =>
      _rangeRep?.lastRangeRepValidationStatus;
  List<String> get lastRangeRepValidationReasons =>
      _rangeRep?.lastRangeRepValidationReasons ?? const <String>[];
  int? get lastRangeRepValidatedRepIndex =>
      _rangeRep?.lastRangeRepValidatedRepIndex;
  int get rangeRepValidatedCount => _rangeRep?.rangeRepValidatedCount ?? 0;
  int get rangeRepLowConfidenceCount =>
      _rangeRep?.rangeRepLowConfidenceCount ?? 0;
  int get rangeRepInvalidCount => _rangeRep?.rangeRepInvalidCount ?? 0;
  bool get hasLastRangeRepSummary => _rangeRep?.hasLastRangeRepSummary ?? false;
  double? get lastRangeRepSummaryMinAngle =>
      _rangeRep?.lastRangeRepSummaryMinAngle;
  double? get lastRangeRepSummaryWorstFormMetric =>
      _rangeRep?.lastRangeRepSummaryWorstFormMetric;
  int? get lastRangeRepSummaryDescentMillis =>
      _rangeRep?.lastRangeRepSummaryDescentMillis;
  int? get lastRangeRepSummaryAscentMillis =>
      _rangeRep?.lastRangeRepSummaryAscentMillis;
  bool get lastRangeRepSummaryHadFormViolation =>
      _rangeRep?.lastRangeRepSummaryHadFormViolation ?? false;
  bool get lastRangeRepSummaryHadCoverageDrop =>
      _rangeRep?.lastRangeRepSummaryHadCoverageDrop ?? false;
  bool get lastRangeRepSummarySwitchedSideDuringRep =>
      _rangeRep?.lastRangeRepSummarySwitchedSideDuringRep ?? false;
  bool get lastRangeRepSummaryCompletedPhaseSequence =>
      _rangeRep?.lastRangeRepSummaryCompletedPhaseSequence ?? false;
  String? get lastRangeRepSummarySelectedSideLabel =>
      _rangeRep?.lastRangeRepSummarySelectedSideLabel;
  bool get hasLastRepBreakdown => _rangeRep?.hasLastRepBreakdown ?? false;
  double get lastRepRomScore => _rangeRep?.lastRepRomScore ?? 0.0;
  double get lastRepDescentScore => _rangeRep?.lastRepDescentScore ?? 0.0;
  double get lastRepAscentScore => _rangeRep?.lastRepAscentScore ?? 0.0;
  double get lastRepWorstBackAngle => _rangeRep?.lastRepWorstBackAngle ?? 0.0;
  bool get lastRepHadFormViolation =>
      _rangeRep?.lastRepHadFormViolation ?? false;
  CalibrationSnapshot? get calibrationSnapshot =>
      _rangeRep?.calibrationSnapshot;
  double? get baseFormThreshold => _rangeRep?.baseFormThreshold;
  double? get effectiveFormThreshold => _rangeRep?.effectiveFormThreshold;
  double? get calibrationThresholdOffsetCandidate =>
      _rangeRep?.calibrationThresholdOffsetCandidate;
  bool get calibrationThresholdOffsetApplied =>
      _rangeRep?.calibrationThresholdOffsetApplied ?? false;
  String? get calibrationThresholdOffsetFallbackReason =>
      _rangeRep?.calibrationThresholdOffsetFallbackReason;
  int? get calibrationThresholdOffsetSampleCount =>
      _rangeRep?.calibrationThresholdOffsetSampleCount;
  String? get calibrationThresholdOffsetBaselineSideLabel =>
      _rangeRep?.calibrationThresholdOffsetBaselineSideLabel;
  int get calibrationThresholdDecisionCount =>
      _rangeRep?.calibrationThresholdDecisionCount ?? 0;
  int get calibrationThresholdAppliedCount =>
      _rangeRep?.calibrationThresholdAppliedCount ?? 0;
  int get calibrationThresholdNoBaselineCount =>
      _rangeRep?.calibrationThresholdNoBaselineCount ?? 0;
  int get calibrationThresholdInsufficientSamplesCount =>
      _rangeRep?.calibrationThresholdInsufficientSamplesCount ?? 0;
  int get calibrationThresholdMissingFormBaselineCount =>
      _rangeRep?.calibrationThresholdMissingFormBaselineCount ?? 0;
  int get calibrationThresholdSideMismatchCount =>
      _rangeRep?.calibrationThresholdSideMismatchCount ?? 0;
  int get calibrationThresholdOffsetTooSmallCount =>
      _rangeRep?.calibrationThresholdOffsetTooSmallCount ?? 0;
  SessionCalibrationBaseline? get sessionCalibrationBaselineCandidate =>
      _rangeRep?.sessionCalibrationBaselineCandidate;
}

abstract class WorkoutAnalysisStatePayload {
  const WorkoutAnalysisStatePayload();

  EngineKind get analysisKind;
  bool get isFormBad;
  double get currentAngle;
  String get currentPhase;
  WorkoutCalibrationMetrics get calibrationMetrics;
}

class RangeRepWorkoutAnalysisState implements WorkoutAnalysisStatePayload {
  const RangeRepWorkoutAnalysisState({
    this.repCount = 0,
    this.isFormBad = false,
    this.currentAngle = 0.0,
    this.lastRepScore = 0.0,
    this.lastRepRom = 0.0,
    this.currentPhase = 'NEUTRAL',
    this.calibrationMetrics = const WorkoutCalibrationMetrics.rangeRep(),
  });

  final int repCount;
  @override
  final bool isFormBad;
  @override
  final double currentAngle;
  final double lastRepScore;
  final double lastRepRom;
  @override
  final String currentPhase;
  @override
  final WorkoutCalibrationMetrics calibrationMetrics;

  @override
  EngineKind get analysisKind => EngineKind.rangeRep;

  RangeRepWorkoutAnalysisState copyWith({
    int? repCount,
    bool? isFormBad,
    double? currentAngle,
    double? lastRepScore,
    double? lastRepRom,
    String? currentPhase,
    WorkoutCalibrationMetrics? calibrationMetrics,
  }) {
    return RangeRepWorkoutAnalysisState(
      repCount: repCount ?? this.repCount,
      isFormBad: isFormBad ?? this.isFormBad,
      currentAngle: currentAngle ?? this.currentAngle,
      lastRepScore: lastRepScore ?? this.lastRepScore,
      lastRepRom: lastRepRom ?? this.lastRepRom,
      currentPhase: currentPhase ?? this.currentPhase,
      calibrationMetrics: calibrationMetrics ?? this.calibrationMetrics,
    );
  }
}

class HoldWorkoutAnalysisState implements WorkoutAnalysisStatePayload {
  static const Object _selectedHoldSideUnset = Object();
  static const Object _holdFeedbackCodeUnset = Object();
  static const Object _holdEnginePhaseUnset = Object();

  const HoldWorkoutAnalysisState({
    this.isFormBad = false,
    this.currentAngle = 0.0,
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.selectedHoldSide,
    this.holdFeedbackCode,
    this.holdEnginePhase,
    this.isHolding = false,
    this.isHoldVisibilitySuspended = false,
    this.hadHoldFormBreak = false,
    this.currentPhase = 'READY',
    this.calibrationMetrics = const WorkoutCalibrationMetrics.hold(),
  });

  @override
  final bool isFormBad;
  @override
  final double currentAngle;
  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final HoldSide? selectedHoldSide;
  final HoldFeedbackCode? holdFeedbackCode;
  final HoldPhase? holdEnginePhase;
  final bool isHolding;
  final bool isHoldVisibilitySuspended;
  final bool hadHoldFormBreak;
  @override
  final String currentPhase;
  @override
  final WorkoutCalibrationMetrics calibrationMetrics;

  @override
  EngineKind get analysisKind => EngineKind.hold;

  HoldWorkoutAnalysisState copyWith({
    bool? isFormBad,
    double? currentAngle,
    double? currentHoldSeconds,
    double? bestHoldSeconds,
    Object? selectedHoldSide = _selectedHoldSideUnset,
    Object? holdFeedbackCode = _holdFeedbackCodeUnset,
    Object? holdEnginePhase = _holdEnginePhaseUnset,
    bool? isHolding,
    bool? isHoldVisibilitySuspended,
    bool? hadHoldFormBreak,
    String? currentPhase,
    WorkoutCalibrationMetrics? calibrationMetrics,
  }) {
    return HoldWorkoutAnalysisState(
      isFormBad: isFormBad ?? this.isFormBad,
      currentAngle: currentAngle ?? this.currentAngle,
      currentHoldSeconds: currentHoldSeconds ?? this.currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds ?? this.bestHoldSeconds,
      selectedHoldSide: selectedHoldSide == _selectedHoldSideUnset
          ? this.selectedHoldSide
          : selectedHoldSide as HoldSide?,
      holdFeedbackCode: holdFeedbackCode == _holdFeedbackCodeUnset
          ? this.holdFeedbackCode
          : holdFeedbackCode as HoldFeedbackCode?,
      holdEnginePhase: holdEnginePhase == _holdEnginePhaseUnset
          ? this.holdEnginePhase
          : holdEnginePhase as HoldPhase?,
      isHolding: isHolding ?? this.isHolding,
      isHoldVisibilitySuspended:
          isHoldVisibilitySuspended ?? this.isHoldVisibilitySuspended,
      hadHoldFormBreak: hadHoldFormBreak ?? this.hadHoldFormBreak,
      currentPhase: currentPhase ?? this.currentPhase,
      calibrationMetrics: calibrationMetrics ?? this.calibrationMetrics,
    );
  }
}

class WorkoutState {
  static const Object _landmarksUnset = Object();

  const WorkoutState._({
    List<PoseLandmark>? landmarks,
    required this.feedbackMessage,
    required this.cameraFps,
    required this.analysisFps,
    RangeRepWorkoutAnalysisState? rangeRepAnalysis,
    HoldWorkoutAnalysisState? holdAnalysis,
  }) : _landmarks = landmarks,
       _rangeRepAnalysis = rangeRepAnalysis,
       _holdAnalysis = holdAnalysis,
       assert(
         (rangeRepAnalysis == null) != (holdAnalysis == null),
         'WorkoutState must contain exactly one family payload.',
       );

  const WorkoutState.rangeRep({
    List<PoseLandmark>? landmarks,
    String feedbackMessage = 'Hazir misin?',
    double cameraFps = 0.0,
    double analysisFps = 0.0,
    RangeRepWorkoutAnalysisState analysis =
        const RangeRepWorkoutAnalysisState(),
  }) : this._(
         landmarks: landmarks,
         feedbackMessage: feedbackMessage,
         cameraFps: cameraFps,
         analysisFps: analysisFps,
         rangeRepAnalysis: analysis,
       );

  const WorkoutState.hold({
    List<PoseLandmark>? landmarks,
    String feedbackMessage = 'Hazir misin?',
    double cameraFps = 0.0,
    double analysisFps = 0.0,
    HoldWorkoutAnalysisState analysis = const HoldWorkoutAnalysisState(),
  }) : this._(
         landmarks: landmarks,
         feedbackMessage: feedbackMessage,
         cameraFps: cameraFps,
         analysisFps: analysisFps,
         holdAnalysis: analysis,
       );

  final List<PoseLandmark>? _landmarks;
  final RangeRepWorkoutAnalysisState? _rangeRepAnalysis;
  final HoldWorkoutAnalysisState? _holdAnalysis;
  final String feedbackMessage;
  final double cameraFps;
  final double analysisFps;

  List<PoseLandmark>? get landmarks => _landmarks;
  RangeRepWorkoutAnalysisState? get rangeRepAnalysis => _rangeRepAnalysis;
  HoldWorkoutAnalysisState? get holdAnalysis => _holdAnalysis;

  EngineKind get analysisKind => _analysis.analysisKind;
  WorkoutAnalysisStatePayload get _analysis =>
      _rangeRepAnalysis ?? _holdAnalysis!;

  int get repCount => _rangeRepAnalysis?.repCount ?? 0;
  bool get isFormBad => _analysis.isFormBad;
  double get currentAngle => _analysis.currentAngle;
  double get lastRepScore => _rangeRepAnalysis?.lastRepScore ?? 0.0;
  double get lastRepROM => _rangeRepAnalysis?.lastRepRom ?? 0.0;
  double get currentHoldSeconds => _holdAnalysis?.currentHoldSeconds ?? 0.0;
  double get bestHoldSeconds => _holdAnalysis?.bestHoldSeconds ?? 0.0;
  HoldSide? get selectedHoldSide => _holdAnalysis?.selectedHoldSide;
  HoldFeedbackCode? get holdFeedbackCode => _holdAnalysis?.holdFeedbackCode;
  HoldPhase? get holdEnginePhase => _holdAnalysis?.holdEnginePhase;
  bool get isHolding => _holdAnalysis?.isHolding ?? false;
  bool get isHoldVisibilitySuspended =>
      _holdAnalysis?.isHoldVisibilitySuspended ?? false;
  bool get hadHoldFormBreak => _holdAnalysis?.hadHoldFormBreak ?? false;
  String get currentPhase => _analysis.currentPhase;
  WorkoutCalibrationMetrics get calibrationMetrics =>
      _analysis.calibrationMetrics;

  WorkoutState copyWith({
    Object? landmarks = _landmarksUnset,
    String? feedbackMessage,
    double? cameraFps,
    double? analysisFps,
    RangeRepWorkoutAnalysisState? rangeRepAnalysis,
    HoldWorkoutAnalysisState? holdAnalysis,
  }) {
    if (_rangeRepAnalysis != null) {
      if (holdAnalysis != null) {
        throw ArgumentError(
          'Cannot apply hold analysis to a range-rep WorkoutState.',
        );
      }
      return WorkoutState.rangeRep(
        landmarks: landmarks == _landmarksUnset
            ? _landmarks
            : landmarks as List<PoseLandmark>?,
        feedbackMessage: feedbackMessage ?? this.feedbackMessage,
        cameraFps: cameraFps ?? this.cameraFps,
        analysisFps: analysisFps ?? this.analysisFps,
        analysis: rangeRepAnalysis ?? _rangeRepAnalysis,
      );
    }

    if (rangeRepAnalysis != null) {
      throw ArgumentError(
        'Cannot apply range-rep analysis to a hold WorkoutState.',
      );
    }
    return WorkoutState.hold(
      landmarks: landmarks == _landmarksUnset
          ? _landmarks
          : landmarks as List<PoseLandmark>?,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      cameraFps: cameraFps ?? this.cameraFps,
      analysisFps: analysisFps ?? this.analysisFps,
      analysis: holdAnalysis ?? _holdAnalysis!,
    );
  }

  WorkoutState copyWithRangeRepAnalysis(RangeRepWorkoutAnalysisState analysis) {
    if (_rangeRepAnalysis == null) {
      throw StateError(
        'copyWithRangeRepAnalysis is only valid for range-rep WorkoutState.',
      );
    }
    return copyWith(rangeRepAnalysis: analysis);
  }

  WorkoutState copyWithHoldAnalysis(HoldWorkoutAnalysisState analysis) {
    if (_holdAnalysis == null) {
      throw StateError(
        'copyWithHoldAnalysis is only valid for hold WorkoutState.',
      );
    }
    return copyWith(holdAnalysis: analysis);
  }
}
