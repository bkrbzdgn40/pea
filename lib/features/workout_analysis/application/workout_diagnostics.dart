import 'package:flutter/foundation.dart';

import '../domain/hold_diagnostics.dart';
import '../domain/models/analysis_signal_role.dart';
import '../domain/models/camera_view_contract.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_feedback_code.dart';
import '../domain/models/hold_phase.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/hold_signal_validity.dart';
import '../domain/models/hold_signal_values.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_timing_trace.dart';

const String _defaultAppCommitSha = String.fromEnvironment(
  'PEA_COMMIT_SHA',
  defaultValue: 'unknown',
);

String get workoutDiagnosticsBuildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

class RangeRepWorkoutDiagnostics {
  const RangeRepWorkoutDiagnostics({
    this.repCount,
    this.currentPhase,
    this.sideSwitchCount = 0,
    this.activeRepSideSwitchCount = 0,
    this.activeRepResyncCount = 0,
    this.transitionCount = 0,
    this.abortCount = 0,
    this.validationCount = 0,
    this.validationStatusCounts = const <String, int>{},
    this.validationReasonCounts = const <String, int>{},
    this.tempoDiagnosticReasonCounts = const <String, int>{},
    this.transitionCounts = const <String, int>{},
    this.lastConfirmedTransition,
    this.lastValidationStatus,
    this.lastValidationReasons = const <String>[],
    this.lastTempoDiagnosticReasons = const <String>[],
    this.currentSelectedSide,
    this.lastCalibrationOffsetDegrees,
    this.signalRoles = const <RangeRepSignal, Set<AnalysisSignalRole>>{},
    this.activeTimingTrace,
    this.lastEndedTimingTrace,
    this.nonMonotonicObservationCount = 0,
  });

  final int? repCount;
  final String? currentPhase;
  final int sideSwitchCount;
  final int activeRepSideSwitchCount;
  final int activeRepResyncCount;
  final int transitionCount;
  final int abortCount;
  final int validationCount;
  final Map<String, int> validationStatusCounts;
  final Map<String, int> validationReasonCounts;
  final Map<String, int> tempoDiagnosticReasonCounts;
  final Map<String, int> transitionCounts;
  final String? lastConfirmedTransition;
  final String? lastValidationStatus;
  final List<String> lastValidationReasons;
  final List<String> lastTempoDiagnosticReasons;
  final String? currentSelectedSide;
  final double? lastCalibrationOffsetDegrees;
  final Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles;
  final RangeRepTimingTraceSnapshot? activeTimingTrace;
  final RangeRepTimingTraceSnapshot? lastEndedTimingTrace;
  final int nonMonotonicObservationCount;

  RangeRepWorkoutDiagnostics copyWith({
    Object? repCount = _unsetValue,
    Object? currentPhase = _unsetValue,
    int? sideSwitchCount,
    int? activeRepSideSwitchCount,
    int? activeRepResyncCount,
    int? transitionCount,
    int? abortCount,
    int? validationCount,
    Object? validationStatusCounts = _unsetValue,
    Object? validationReasonCounts = _unsetValue,
    Object? tempoDiagnosticReasonCounts = _unsetValue,
    Object? transitionCounts = _unsetValue,
    Object? lastConfirmedTransition = _unsetValue,
    Object? lastValidationStatus = _unsetValue,
    Object? lastValidationReasons = _unsetValue,
    Object? lastTempoDiagnosticReasons = _unsetValue,
    Object? currentSelectedSide = _unsetValue,
    Object? lastCalibrationOffsetDegrees = _unsetValue,
    Object? signalRoles = _unsetValue,
    Object? activeTimingTrace = _unsetValue,
    Object? lastEndedTimingTrace = _unsetValue,
    int? nonMonotonicObservationCount,
  }) {
    return RangeRepWorkoutDiagnostics(
      repCount: repCount == _unsetValue ? this.repCount : repCount as int?,
      currentPhase: currentPhase == _unsetValue
          ? this.currentPhase
          : currentPhase as String?,
      sideSwitchCount: sideSwitchCount ?? this.sideSwitchCount,
      activeRepSideSwitchCount:
          activeRepSideSwitchCount ?? this.activeRepSideSwitchCount,
      activeRepResyncCount: activeRepResyncCount ?? this.activeRepResyncCount,
      transitionCount: transitionCount ?? this.transitionCount,
      abortCount: abortCount ?? this.abortCount,
      validationCount: validationCount ?? this.validationCount,
      validationStatusCounts: validationStatusCounts == _unsetValue
          ? this.validationStatusCounts
          : Map<String, int>.unmodifiable(
              validationStatusCounts as Map<String, int>,
            ),
      validationReasonCounts: validationReasonCounts == _unsetValue
          ? this.validationReasonCounts
          : Map<String, int>.unmodifiable(
              validationReasonCounts as Map<String, int>,
            ),
      tempoDiagnosticReasonCounts: tempoDiagnosticReasonCounts == _unsetValue
          ? this.tempoDiagnosticReasonCounts
          : Map<String, int>.unmodifiable(
              tempoDiagnosticReasonCounts as Map<String, int>,
            ),
      transitionCounts: transitionCounts == _unsetValue
          ? this.transitionCounts
          : Map<String, int>.unmodifiable(transitionCounts as Map<String, int>),
      lastConfirmedTransition: lastConfirmedTransition == _unsetValue
          ? this.lastConfirmedTransition
          : lastConfirmedTransition as String?,
      lastValidationStatus: lastValidationStatus == _unsetValue
          ? this.lastValidationStatus
          : lastValidationStatus as String?,
      lastValidationReasons: lastValidationReasons == _unsetValue
          ? this.lastValidationReasons
          : List<String>.unmodifiable(lastValidationReasons as List<String>),
      lastTempoDiagnosticReasons: lastTempoDiagnosticReasons == _unsetValue
          ? this.lastTempoDiagnosticReasons
          : List<String>.unmodifiable(
              lastTempoDiagnosticReasons as List<String>,
            ),
      currentSelectedSide: currentSelectedSide == _unsetValue
          ? this.currentSelectedSide
          : currentSelectedSide as String?,
      lastCalibrationOffsetDegrees: lastCalibrationOffsetDegrees == _unsetValue
          ? this.lastCalibrationOffsetDegrees
          : lastCalibrationOffsetDegrees as double?,
      signalRoles: signalRoles == _unsetValue
          ? this.signalRoles
          : signalRoles as Map<RangeRepSignal, Set<AnalysisSignalRole>>,
      activeTimingTrace: activeTimingTrace == _unsetValue
          ? this.activeTimingTrace
          : activeTimingTrace as RangeRepTimingTraceSnapshot?,
      lastEndedTimingTrace: lastEndedTimingTrace == _unsetValue
          ? this.lastEndedTimingTrace
          : lastEndedTimingTrace as RangeRepTimingTraceSnapshot?,
      nonMonotonicObservationCount:
          nonMonotonicObservationCount ?? this.nonMonotonicObservationCount,
    );
  }
}

class HoldWorkoutDiagnostics {
  const HoldWorkoutDiagnostics({
    this.currentHoldSeconds,
    this.bestHoldSeconds,
    this.currentPhase,
    this.isHolding,
    this.presentedHoldFeedbackCode,
    this.engineHoldFeedbackCode,
    this.holdEnginePhase,
    this.currentHoldSide,
    this.lastVisibleHoldPosture,
    this.isHoldFormBreakGraceActive,
    this.isHoldVisibilitySuspended,
    HoldSignalValues? currentSignalValues,
    HoldSignalValues? targetSignalValues,
    HoldSignalValidity? signalValidity,
    this.signalRoles = const <HoldSignal, Set<AnalysisSignalRole>>{},
  }) : currentSignalValues =
           currentSignalValues ?? const HoldSignalValues.empty(),
       targetSignalValues =
           targetSignalValues ?? const HoldSignalValues.empty(),
       signalValidity = signalValidity ?? const HoldSignalValidity.empty();

  final int? currentHoldSeconds;
  final int? bestHoldSeconds;
  final String? currentPhase;
  final bool? isHolding;
  final HoldFeedbackCode? presentedHoldFeedbackCode;
  final HoldFeedbackCode? engineHoldFeedbackCode;
  final HoldPhase? holdEnginePhase;
  final HoldSide? currentHoldSide;
  final HoldPostureDiagnosticsSnapshot? lastVisibleHoldPosture;
  final bool? isHoldFormBreakGraceActive;
  final bool? isHoldVisibilitySuspended;
  final HoldSignalValues currentSignalValues;
  final HoldSignalValues targetSignalValues;
  final HoldSignalValidity signalValidity;
  final Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles;
}

const Object _unsetValue = Object();

/// Immutable, privacy-minimized diagnostics for one analysis session.
class WorkoutDiagnosticsSnapshot {
  const WorkoutDiagnosticsSnapshot({
    required this.schemaVersion,
    required this.appCommitSha,
    required this.buildMode,
    required this.analysisKind,
    required this.exerciseType,
    required this.configAssetPath,
    required this.configVersionFingerprint,
    required this.contractProfile,
    this.rangeRepSideMode,
    this.rangeRepPrimaryMetricKind,
    this.rangeRepPrimaryMetricDirection,
    this.holdAnalysisFamily,
    this.holdVariation,
    required this.sessionStartedAt,
    required this.snapshotCreatedAt,
    required this.elapsedMs,
    required this.cameraFrameCount,
    required this.analysisAttemptCount,
    required this.analysisCompletedCount,
    required this.throttledFrameCount,
    required this.reentrantDropCount,
    required this.converterDropCount,
    required this.noPoseFrameCount,
    this.detectedPoseFrameCount = 0,
    this.acceptedPoseFrameCount = 0,
    this.rejectedPoseFrameCount = 0,
    this.lowConfidencePoseFrameCount = 0,
    this.invalidPoseGeometryFrameCount = 0,
    required this.multiPoseFrameCount,
    required this.maxPoseCount,
    required this.analysisExceptionCount,
    required this.resyncCount,
    this.poseReacquisitionCount = 0,
    this.briefOcclusionCount = 0,
    this.briefOcclusionRecoveryCount = 0,
    this.briefOcclusionAbortCount = 0,
    this.holdVisibilitySuspendCount = 0,
    this.holdVisibilityRecoveryCount = 0,
    this.holdVisibilityAbortCount = 0,
    this.holdVisibilitySuspendedMsTotal = 0,
    this.lastHoldVisibilityGapMs,
    this.lastPoseRejectionReason,
    this.poseRejectionReasonCounts = const <String, int>{},
    this.poseQualitySampleCount = 0,
    this.minimumRequiredLikelihoodP05,
    this.minimumRequiredLikelihoodP50,
    this.meanRequiredLikelihoodP05,
    this.meanRequiredLikelihoodP50,
    this.poseQualityScoreP50,
    this.poseQualityScoreP95,
    this.currentPoseQualityStatus = 'stable',
    this.currentVisibilityStatus = 'stable',
    this.cameraViewContract,
    this.cameraLensDirection,
    this.sensorOrientationDegrees,
    this.deviceOrientation,
    this.rangeRepDiagnostics,
    this.holdDiagnostics,
    required this.currentCameraFps,
    required this.currentAnalysisFps,
    required this.fpsSampleCount,
    required this.cameraFpsP50,
    required this.cameraFpsP95,
    required this.analysisFpsP50,
    required this.analysisFpsP95,
    required this.frameProcessingMsP50,
    required this.frameProcessingMsP95,
    required this.frameProcessingMsMax,
  });

  final int schemaVersion;
  final String appCommitSha;
  final String buildMode;
  final String analysisKind;
  final String exerciseType;
  final String configAssetPath;
  final String configVersionFingerprint;
  final String contractProfile;
  final String? rangeRepSideMode;
  final String? rangeRepPrimaryMetricKind;
  final String? rangeRepPrimaryMetricDirection;
  final String? holdAnalysisFamily;
  final String? holdVariation;
  final DateTime sessionStartedAt;
  final DateTime snapshotCreatedAt;
  final int elapsedMs;
  final int cameraFrameCount;
  final int analysisAttemptCount;
  final int analysisCompletedCount;
  final int throttledFrameCount;
  final int reentrantDropCount;
  final int converterDropCount;
  final int noPoseFrameCount;
  final int detectedPoseFrameCount;
  final int acceptedPoseFrameCount;
  final int rejectedPoseFrameCount;
  final int lowConfidencePoseFrameCount;
  final int invalidPoseGeometryFrameCount;
  final int multiPoseFrameCount;
  final int maxPoseCount;
  final int analysisExceptionCount;
  final int resyncCount;
  final int poseReacquisitionCount;
  final int briefOcclusionCount;
  final int briefOcclusionRecoveryCount;
  final int briefOcclusionAbortCount;
  final int holdVisibilitySuspendCount;
  final int holdVisibilityRecoveryCount;
  final int holdVisibilityAbortCount;
  final int holdVisibilitySuspendedMsTotal;
  final int? lastHoldVisibilityGapMs;
  final String? lastPoseRejectionReason;
  final Map<String, int> poseRejectionReasonCounts;
  final int poseQualitySampleCount;
  final double? minimumRequiredLikelihoodP05;
  final double? minimumRequiredLikelihoodP50;
  final double? meanRequiredLikelihoodP05;
  final double? meanRequiredLikelihoodP50;
  final double? poseQualityScoreP50;
  final double? poseQualityScoreP95;
  final String currentPoseQualityStatus;
  final String currentVisibilityStatus;
  final CameraViewContract? cameraViewContract;
  final String? cameraLensDirection;
  final int? sensorOrientationDegrees;
  final String? deviceOrientation;
  final RangeRepWorkoutDiagnostics? rangeRepDiagnostics;
  final HoldWorkoutDiagnostics? holdDiagnostics;
  final double? currentCameraFps;
  final double? currentAnalysisFps;
  final int fpsSampleCount;
  final double? cameraFpsP50;
  final double? cameraFpsP95;
  final double? analysisFpsP50;
  final double? analysisFpsP95;
  final int? frameProcessingMsP50;
  final int? frameProcessingMsP95;
  final int? frameProcessingMsMax;

  Map<RangeRepSignal, Set<AnalysisSignalRole>> get rangeRepSignalRoles =>
      rangeRepDiagnostics?.signalRoles ??
      const <RangeRepSignal, Set<AnalysisSignalRole>>{};

  Map<HoldSignal, Set<AnalysisSignalRole>> get holdSignalRoles =>
      holdDiagnostics?.signalRoles ??
      const <HoldSignal, Set<AnalysisSignalRole>>{};

  int get sideSwitchCount => rangeRepDiagnostics?.sideSwitchCount ?? 0;

  int get activeRepSideSwitchCount =>
      rangeRepDiagnostics?.activeRepSideSwitchCount ?? 0;

  int get activeRepResyncCount =>
      rangeRepDiagnostics?.activeRepResyncCount ?? 0;

  int get rangeRepTransitionCount => rangeRepDiagnostics?.transitionCount ?? 0;

  int get rangeRepAbortCount => rangeRepDiagnostics?.abortCount ?? 0;

  int get rangeRepValidationCount => rangeRepDiagnostics?.validationCount ?? 0;

  Map<String, int> get rangeRepTransitionCounts =>
      rangeRepDiagnostics?.transitionCounts ?? const <String, int>{};

  Map<String, int> get rangeRepValidationStatusCounts =>
      rangeRepDiagnostics?.validationStatusCounts ?? const <String, int>{};

  Map<String, int> get rangeRepValidationReasonCounts =>
      rangeRepDiagnostics?.validationReasonCounts ?? const <String, int>{};

  Map<String, int> get rangeRepTempoDiagnosticReasonCounts =>
      rangeRepDiagnostics?.tempoDiagnosticReasonCounts ?? const <String, int>{};

  String? get lastRangeRepConfirmedTransition =>
      rangeRepDiagnostics?.lastConfirmedTransition;

  String? get lastRangeRepValidationStatus =>
      rangeRepDiagnostics?.lastValidationStatus;

  List<String> get lastRangeRepValidationReasons =>
      rangeRepDiagnostics?.lastValidationReasons ?? const <String>[];

  List<String> get lastRangeRepTempoDiagnosticReasons =>
      rangeRepDiagnostics?.lastTempoDiagnosticReasons ?? const <String>[];

  String? get currentSelectedSide => rangeRepDiagnostics?.currentSelectedSide;

  double? get lastCalibrationOffsetDegrees =>
      rangeRepDiagnostics?.lastCalibrationOffsetDegrees;

  RangeRepTimingTraceSnapshot? get activeRangeRepTimingTrace =>
      rangeRepDiagnostics?.activeTimingTrace;

  RangeRepTimingTraceSnapshot? get lastEndedRangeRepTimingTrace =>
      rangeRepDiagnostics?.lastEndedTimingTrace;

  int get nonMonotonicRangeRepObservationCount =>
      rangeRepDiagnostics?.nonMonotonicObservationCount ?? 0;

  int? get repCount {
    if (rangeRepDiagnostics != null) {
      return rangeRepDiagnostics!.repCount;
    }
    if (holdDiagnostics != null) {
      return 0;
    }
    return null;
  }

  int? get currentHoldSeconds {
    if (holdDiagnostics != null) {
      return holdDiagnostics!.currentHoldSeconds;
    }
    if (rangeRepDiagnostics != null) {
      return 0;
    }
    return null;
  }

  int? get bestHoldSeconds {
    if (holdDiagnostics != null) {
      return holdDiagnostics!.bestHoldSeconds;
    }
    if (rangeRepDiagnostics != null) {
      return 0;
    }
    return null;
  }

  String? get currentPhase =>
      rangeRepDiagnostics?.currentPhase ?? holdDiagnostics?.currentPhase;

  bool? get isHolding {
    if (holdDiagnostics != null) {
      return holdDiagnostics!.isHolding;
    }
    if (rangeRepDiagnostics != null) {
      return false;
    }
    return null;
  }

  HoldFeedbackCode? get presentedHoldFeedbackCode =>
      holdDiagnostics?.presentedHoldFeedbackCode;

  HoldFeedbackCode? get engineHoldFeedbackCode =>
      holdDiagnostics?.engineHoldFeedbackCode;

  HoldPhase? get holdEnginePhase => holdDiagnostics?.holdEnginePhase;

  HoldSide? get currentHoldSide => holdDiagnostics?.currentHoldSide;

  HoldPostureDiagnosticsSnapshot? get lastVisibleHoldPosture =>
      holdDiagnostics?.lastVisibleHoldPosture;

  bool? get isHoldFormBreakGraceActive =>
      holdDiagnostics?.isHoldFormBreakGraceActive;

  bool? get isHoldVisibilitySuspended =>
      holdDiagnostics?.isHoldVisibilitySuspended;

  HoldSignalValues get holdCurrentSignalValues =>
      holdDiagnostics?.currentSignalValues ?? const HoldSignalValues.empty();

  HoldSignalValues get holdTargetSignalValues =>
      holdDiagnostics?.targetSignalValues ?? const HoldSignalValues.empty();

  HoldSignalValidity get holdSignalValidity =>
      holdDiagnostics?.signalValidity ?? const HoldSignalValidity.empty();

  double? currentHoldSignalValue(HoldSignal signal) {
    return holdCurrentSignalValues.valueFor(signal);
  }

  double? targetHoldSignalValue(HoldSignal signal) {
    return holdTargetSignalValues.valueFor(signal);
  }

  bool? holdSignalValidityFor(HoldSignal signal) {
    return holdSignalValidity.validityFor(signal);
  }

  Iterable<HoldSignal> get holdSignals {
    final signalSet = <HoldSignal>{
      ...holdCurrentSignalValues.signals,
      ...holdTargetSignalValues.signals,
      ...holdSignalValidity.signals,
    };
    return HoldSignal.values.where(signalSet.contains);
  }

  bool hasHoldSignal(HoldSignal signal) {
    return currentHoldSignalValue(signal) != null ||
        targetHoldSignalValue(signal) != null ||
        holdSignalValidityFor(signal) != null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': schemaVersion,
    'app_commit_sha': appCommitSha,
    'build_mode': buildMode,
    'analysis_kind': analysisKind,
    'exercise_type': exerciseType,
    'config_asset_path': configAssetPath,
    'config_version_fingerprint': configVersionFingerprint,
    'contract_profile': contractProfile,
    'range_rep_side_mode': rangeRepSideMode,
    'range_rep_primary_metric_kind': rangeRepPrimaryMetricKind,
    'range_rep_primary_metric_direction': rangeRepPrimaryMetricDirection,
    'hold_analysis_family': holdAnalysisFamily,
    'hold_variation': holdVariation,
    'session_started_at': sessionStartedAt.toIso8601String(),
    'snapshot_created_at': snapshotCreatedAt.toIso8601String(),
    'elapsed_ms': elapsedMs,
    'camera_frame_count': cameraFrameCount,
    'analysis_attempt_count': analysisAttemptCount,
    'analysis_completed_count': analysisCompletedCount,
    'throttled_frame_count': throttledFrameCount,
    'reentrant_drop_count': reentrantDropCount,
    'converter_drop_count': converterDropCount,
    'no_pose_frame_count': noPoseFrameCount,
    'detected_pose_frame_count': detectedPoseFrameCount,
    'accepted_pose_frame_count': acceptedPoseFrameCount,
    'rejected_pose_frame_count': rejectedPoseFrameCount,
    'low_confidence_pose_frame_count': lowConfidencePoseFrameCount,
    'invalid_pose_geometry_frame_count': invalidPoseGeometryFrameCount,
    'multi_pose_frame_count': multiPoseFrameCount,
    'max_pose_count': maxPoseCount,
    'analysis_exception_count': analysisExceptionCount,
    'resync_count': resyncCount,
    'pose_reacquisition_count': poseReacquisitionCount,
    'brief_occlusion_count': briefOcclusionCount,
    'brief_occlusion_recovery_count': briefOcclusionRecoveryCount,
    'brief_occlusion_abort_count': briefOcclusionAbortCount,
    'hold_visibility_suspend_count': analysisKind == 'hold'
        ? holdVisibilitySuspendCount
        : null,
    'hold_visibility_recovery_count': analysisKind == 'hold'
        ? holdVisibilityRecoveryCount
        : null,
    'hold_visibility_abort_count': analysisKind == 'hold'
        ? holdVisibilityAbortCount
        : null,
    'hold_visibility_suspended_ms_total': analysisKind == 'hold'
        ? holdVisibilitySuspendedMsTotal
        : null,
    'last_hold_visibility_gap_ms': analysisKind == 'hold'
        ? lastHoldVisibilityGapMs
        : null,
    'last_pose_rejection_reason': lastPoseRejectionReason,
    'pose_rejection_reason_counts': poseRejectionReasonCounts.isEmpty
        ? null
        : poseRejectionReasonCounts,
    'pose_quality_sample_count': poseQualitySampleCount,
    'minimum_required_likelihood_p05': minimumRequiredLikelihoodP05,
    'minimum_required_likelihood_p50': minimumRequiredLikelihoodP50,
    'mean_required_likelihood_p05': meanRequiredLikelihoodP05,
    'mean_required_likelihood_p50': meanRequiredLikelihoodP50,
    'pose_quality_score_p50': poseQualityScoreP50,
    'pose_quality_score_p95': poseQualityScoreP95,
    'current_pose_quality_status': currentPoseQualityStatus,
    'current_visibility_status': currentVisibilityStatus,
    'camera_view_contract': _serializeCameraViewContract(cameraViewContract),
    'camera_lens_direction': cameraLensDirection,
    'sensor_orientation_degrees': sensorOrientationDegrees,
    'device_orientation': deviceOrientation,
    'range_rep_signal_roles': _serializeRangeRepSignalRoles(
      rangeRepSignalRoles,
    ),
    'hold_signal_roles': _serializeHoldSignalRoles(holdSignalRoles),
    'side_switch_count': sideSwitchCount,
    'active_rep_side_switch_count': activeRepSideSwitchCount,
    'active_rep_resync_count': activeRepResyncCount,
    'range_rep_transition_count': rangeRepTransitionCount,
    'range_rep_transition_counts': rangeRepTransitionCounts.isEmpty
        ? null
        : rangeRepTransitionCounts,
    'range_rep_abort_count': rangeRepAbortCount,
    'range_rep_validation_count': rangeRepValidationCount,
    'range_rep_validation_status_counts': rangeRepValidationStatusCounts.isEmpty
        ? null
        : rangeRepValidationStatusCounts,
    'range_rep_validation_reason_counts': rangeRepValidationReasonCounts.isEmpty
        ? null
        : rangeRepValidationReasonCounts,
    'range_rep_tempo_diagnostic_reason_counts':
        rangeRepTempoDiagnosticReasonCounts.isEmpty
        ? null
        : rangeRepTempoDiagnosticReasonCounts,
    'last_range_rep_confirmed_transition': lastRangeRepConfirmedTransition,
    'last_range_rep_validation_status': lastRangeRepValidationStatus,
    'last_range_rep_validation_reasons': lastRangeRepValidationReasons.isEmpty
        ? null
        : lastRangeRepValidationReasons,
    'last_range_rep_tempo_diagnostic_reasons':
        lastRangeRepTempoDiagnosticReasons.isEmpty
        ? null
        : lastRangeRepTempoDiagnosticReasons,
    'current_selected_side': currentSelectedSide,
    'last_calibration_offset_degrees': lastCalibrationOffsetDegrees,
    'range_rep_active_timing_trace': activeRangeRepTimingTrace?.toJson(),
    'range_rep_last_ended_timing_trace': lastEndedRangeRepTimingTrace?.toJson(),
    'range_rep_non_monotonic_observation_count':
        nonMonotonicRangeRepObservationCount,
    'current_camera_fps': currentCameraFps,
    'current_analysis_fps': currentAnalysisFps,
    'fps_sample_count': fpsSampleCount,
    'camera_fps_p50': cameraFpsP50,
    'camera_fps_p95': cameraFpsP95,
    'analysis_fps_p50': analysisFpsP50,
    'analysis_fps_p95': analysisFpsP95,
    'frame_processing_ms_p50': frameProcessingMsP50,
    'frame_processing_ms_p95': frameProcessingMsP95,
    'frame_processing_ms_max': frameProcessingMsMax,
    'rep_count': repCount,
    'current_hold_seconds': currentHoldSeconds,
    'best_hold_seconds': bestHoldSeconds,
    'current_phase': currentPhase,
    'is_holding': isHolding,
    'presented_hold_feedback_code': presentedHoldFeedbackCode?.code,
    'engine_hold_feedback_code': engineHoldFeedbackCode?.code,
    'hold_engine_phase': holdEnginePhase?.code,
    'current_hold_side': currentHoldSide?.name,
    'hold_current_signals': _serializeHoldDoubleMap(
      holdCurrentSignalValues.asMap(),
    ),
    'hold_target_signals': _serializeHoldDoubleMap(
      holdTargetSignalValues.asMap(),
    ),
    'hold_signal_validity': _serializeHoldBoolMap(holdSignalValidity.asMap()),
    'hold_has_complete_metrics': lastVisibleHoldPosture?.hasCompleteMetrics,
    'hold_has_active_posture': lastVisibleHoldPosture?.hasActivePosture,
    'hold_is_body_aligned': lastVisibleHoldPosture?.validityFor(
      HoldSignal.alignment,
    ),
    'hold_is_arm_supported': lastVisibleHoldPosture?.validityFor(
      HoldSignal.support,
    ),
    'hold_are_legs_extended': lastVisibleHoldPosture?.validityFor(
      HoldSignal.extension,
    ),
    'hold_is_form_break_grace_active': isHoldFormBreakGraceActive,
    'hold_is_visibility_suspended': isHoldVisibilitySuspended,
  };
}

/// Session-level accumulator. Processing and FPS samples use a 10,000-item
/// rolling window and deterministic nearest-rank percentiles.
class WorkoutDiagnosticsAccumulator {
  WorkoutDiagnosticsAccumulator({
    required DateTime sessionStartedAt,
    required String analysisKind,
    required String exerciseType,
    required String configAssetPath,
    required CameraViewContract cameraViewContract,
    RangeRepContract? rangeRepContract,
    HoldContract? holdContract,
    String appCommitSha = _defaultAppCommitSha,
    String? buildMode,
  }) : _appCommitSha = appCommitSha,
       _buildMode = buildMode ?? workoutDiagnosticsBuildMode,
       _exerciseType = exerciseType,
       _configAssetPath = configAssetPath,
       _contractProfile = rangeRepContract != null
           ? 'rangeRep:${rangeRepContract.extensionProfile.name}'
           : holdContract != null
           ? 'hold:${holdContract.family.name}'
           : analysisKind,
       _rangeRepSideMode = rangeRepContract?.sideMode.name,
       _rangeRepPrimaryMetricKind = rangeRepContract?.primaryMetricKind.name,
       _rangeRepPrimaryMetricDirection =
           rangeRepContract?.primaryMetricDirection.name,
       _holdAnalysisFamily = holdContract?.family.name,
       _holdVariation = holdContract?.hollowHoldVariation?.variation.name,
       _cameraViewContract = cameraViewContract,
       _sessionStartedAt = sessionStartedAt,
       _analysisKind = analysisKind;

  static const int maxProcessingDurationSamples = 10000;

  final String _appCommitSha;
  final String _buildMode;
  final String _exerciseType;
  final String _configAssetPath;
  final String _contractProfile;
  final String? _rangeRepSideMode;
  final String? _rangeRepPrimaryMetricKind;
  final String? _rangeRepPrimaryMetricDirection;
  final String? _holdAnalysisFamily;
  final String? _holdVariation;
  final CameraViewContract _cameraViewContract;
  late DateTime _sessionStartedAt;
  late String _analysisKind;
  final List<int> _processingDurationMs = <int>[];
  final List<double> _minimumRequiredLikelihoodSamples = <double>[];
  final List<double> _meanRequiredLikelihoodSamples = <double>[];
  final List<double> _poseQualityScoreSamples = <double>[];
  final List<double> _cameraFpsSamples = <double>[];
  final List<double> _analysisFpsSamples = <double>[];
  final Map<String, int> _poseRejectionReasonCounts = <String, int>{};

  int _cameraFrameCount = 0;
  int _analysisAttemptCount = 0;
  int _analysisCompletedCount = 0;
  int _throttledFrameCount = 0;
  int _reentrantDropCount = 0;
  int _converterDropCount = 0;
  int _noPoseFrameCount = 0;
  int _detectedPoseFrameCount = 0;
  int _acceptedPoseFrameCount = 0;
  int _rejectedPoseFrameCount = 0;
  int _lowConfidencePoseFrameCount = 0;
  int _invalidPoseGeometryFrameCount = 0;
  int _poseQualitySampleCount = 0;
  int _multiPoseFrameCount = 0;
  int _maxPoseCount = 0;
  int _analysisExceptionCount = 0;
  int _resyncCount = 0;
  int _poseReacquisitionCount = 0;
  int _briefOcclusionCount = 0;
  int _briefOcclusionRecoveryCount = 0;
  int _briefOcclusionAbortCount = 0;
  int _holdVisibilitySuspendCount = 0;
  int _holdVisibilityRecoveryCount = 0;
  int _holdVisibilityAbortCount = 0;
  int _holdVisibilitySuspendedMsTotal = 0;
  int? _lastHoldVisibilityGapMs;
  String? _lastPoseRejectionReason;
  String _currentPoseQualityStatus = 'stable';
  String _currentVisibilityStatus = 'stable';
  String? _cameraLensDirection;
  int? _sensorOrientationDegrees;
  String? _deviceOrientation;
  double? _currentCameraFps;
  double? _currentAnalysisFps;
  RangeRepWorkoutDiagnostics? _rangeRepDiagnostics;
  HoldWorkoutDiagnostics? _holdDiagnostics;

  void recordCameraFrame() => _cameraFrameCount++;
  void recordAnalysisAttempt() => _analysisAttemptCount++;
  void recordAnalysisCompleted() => _analysisCompletedCount++;
  void recordThrottledFrame() => _throttledFrameCount++;
  void recordReentrantDrop() => _reentrantDropCount++;
  void recordConverterDrop() => _converterDropCount++;
  void recordAnalysisException() => _analysisExceptionCount++;
  void recordResync({bool hadActiveRepContext = false}) {
    _resyncCount++;
    if (!hadActiveRepContext) {
      return;
    }
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    _rangeRepDiagnostics = previous.copyWith(
      activeRepResyncCount: previous.activeRepResyncCount + 1,
    );
    _holdDiagnostics = null;
  }

  void recordAcceptedPoseFrame() => _acceptedPoseFrameCount++;
  void recordPoseReacquisition() => _poseReacquisitionCount++;
  void recordBriefOcclusion() => _briefOcclusionCount++;
  void recordBriefOcclusionRecovery() => _briefOcclusionRecoveryCount++;
  void recordBriefOcclusionAbort() => _briefOcclusionAbortCount++;

  void recordHoldVisibilitySuspend() => _holdVisibilitySuspendCount++;

  void recordHoldVisibilityRecovery(Duration gapDuration) {
    _recordCompletedHoldVisibilityGap(gapDuration);
    _holdVisibilityRecoveryCount++;
  }

  void recordHoldVisibilityAbort(Duration gapDuration) {
    _recordCompletedHoldVisibilityGap(gapDuration);
    _holdVisibilityAbortCount++;
  }

  void _recordCompletedHoldVisibilityGap(Duration gapDuration) {
    if (gapDuration.isNegative) {
      throw ArgumentError.value(
        gapDuration,
        'gapDuration',
        'Must not be negative',
      );
    }
    final gapMs = gapDuration.inMilliseconds;
    _holdVisibilitySuspendedMsTotal += gapMs;
    _lastHoldVisibilityGapMs = gapMs;
  }

  void recordPoseCount(int poseCount) {
    if (poseCount < 0) throw ArgumentError.value(poseCount, 'poseCount');
    if (poseCount == 0) _noPoseFrameCount++;
    if (poseCount > 0) _detectedPoseFrameCount++;
    if (poseCount > 1) _multiPoseFrameCount++;
    if (poseCount > _maxPoseCount) _maxPoseCount = poseCount;
  }

  void recordRejectedPose({required String rejectionReasonCode}) {
    _rejectedPoseFrameCount++;
    _lastPoseRejectionReason = rejectionReasonCode;
    _poseRejectionReasonCounts.update(
      rejectionReasonCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  void recordPoseQualitySample({
    double? minimumRequiredLikelihood,
    double? meanRequiredLikelihood,
    required double qualityScore,
  }) {
    _poseQualitySampleCount++;
    _appendFiniteSample(
      _minimumRequiredLikelihoodSamples,
      minimumRequiredLikelihood,
    );
    _appendFiniteSample(_meanRequiredLikelihoodSamples, meanRequiredLikelihood);
    _appendFiniteSample(_poseQualityScoreSamples, qualityScore);
  }

  void recordLowConfidencePose() => _lowConfidencePoseFrameCount++;

  void recordInvalidPoseGeometry() => _invalidPoseGeometryFrameCount++;

  void updatePoseQualityStatus({
    required String status,
    String? lastRejectionReason,
  }) {
    _currentPoseQualityStatus = status;
    if (lastRejectionReason != null) {
      _lastPoseRejectionReason = lastRejectionReason;
    }
  }

  void updateVisibilityStatus(String status) {
    _currentVisibilityStatus = status;
  }

  void updateCameraRuntimeContext({
    required int sensorOrientationDegrees,
    String? cameraLensDirection,
    String? deviceOrientation,
  }) {
    _sensorOrientationDegrees = sensorOrientationDegrees;
    if (cameraLensDirection != null) {
      _cameraLensDirection = cameraLensDirection;
    }
    if (deviceOrientation != null) {
      _deviceOrientation = deviceOrientation;
    }
  }

  void recordRangeRepTransition(String transitionCode) {
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    final transitionCounts = Map<String, int>.from(previous.transitionCounts);
    transitionCounts.update(
      transitionCode,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    _rangeRepDiagnostics = previous.copyWith(
      transitionCount: previous.transitionCount + 1,
      abortCount:
          previous.abortCount + (transitionCode == 'abortToNeutral' ? 1 : 0),
      transitionCounts: transitionCounts,
      lastConfirmedTransition: transitionCode,
    );
    _holdDiagnostics = null;
  }

  void recordRangeRepValidation({
    required String statusCode,
    required List<String> reasonCodes,
    List<String> tempoDiagnosticReasonCodes = const <String>[],
  }) {
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    final statusCounts = Map<String, int>.from(previous.validationStatusCounts);
    statusCounts.update(statusCode, (count) => count + 1, ifAbsent: () => 1);

    final reasonCounts = Map<String, int>.from(previous.validationReasonCounts);
    for (final reasonCode in reasonCodes) {
      reasonCounts.update(reasonCode, (count) => count + 1, ifAbsent: () => 1);
    }

    final tempoDiagnosticReasonCounts = Map<String, int>.from(
      previous.tempoDiagnosticReasonCounts,
    );
    for (final reasonCode in tempoDiagnosticReasonCodes) {
      tempoDiagnosticReasonCounts.update(
        reasonCode,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    _rangeRepDiagnostics = previous.copyWith(
      validationCount: previous.validationCount + 1,
      validationStatusCounts: statusCounts,
      validationReasonCounts: reasonCounts,
      tempoDiagnosticReasonCounts: tempoDiagnosticReasonCounts,
      lastValidationStatus: statusCode,
      lastValidationReasons: reasonCodes,
      lastTempoDiagnosticReasons: tempoDiagnosticReasonCodes,
    );
    _holdDiagnostics = null;
  }

  /// The first non-null side is an assignment, not a switch. Repeating a side
  /// and transitions to null are not switches. A null transition clears the
  /// current side, so the next non-null side is a fresh assignment.
  void recordSelectedSide({
    required String? selectedSide,
    required bool hasActiveRepContext,
  }) {
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    if (selectedSide == null) {
      _rangeRepDiagnostics = previous.copyWith(currentSelectedSide: null);
      _holdDiagnostics = null;
      return;
    }

    final previousSide = previous.currentSelectedSide;
    var sideSwitchCount = previous.sideSwitchCount;
    var activeRepSideSwitchCount = previous.activeRepSideSwitchCount;
    if (previousSide != null && previousSide != selectedSide) {
      sideSwitchCount++;
      if (hasActiveRepContext) {
        activeRepSideSwitchCount++;
      }
    }
    _rangeRepDiagnostics = previous.copyWith(
      currentSelectedSide: selectedSide,
      sideSwitchCount: sideSwitchCount,
      activeRepSideSwitchCount: activeRepSideSwitchCount,
    );
    _holdDiagnostics = null;
  }

  void recordProcessingDuration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative');
    }
    if (_processingDurationMs.length == maxProcessingDurationSamples) {
      _processingDurationMs.removeAt(0);
    }
    _processingDurationMs.add(duration.inMilliseconds);
  }

  void updateLivePerformance({
    required double cameraFps,
    required double analysisFps,
  }) {
    _currentCameraFps = cameraFps;
    _currentAnalysisFps = analysisFps;
  }

  void recordLivePerformanceSample({
    required double cameraFps,
    required double analysisFps,
  }) {
    if (!cameraFps.isFinite || cameraFps < 0) {
      throw ArgumentError.value(
        cameraFps,
        'cameraFps',
        'Must be finite and >= 0',
      );
    }
    if (!analysisFps.isFinite || analysisFps < 0) {
      throw ArgumentError.value(
        analysisFps,
        'analysisFps',
        'Must be finite and >= 0',
      );
    }
    _appendFiniteNonNegativeSample(_cameraFpsSamples, cameraFps);
    _appendFiniteNonNegativeSample(_analysisFpsSamples, analysisFps);
  }

  void updateRangeRepState({
    required int repCount,
    required String currentPhase,
    required Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles,
    double? calibrationOffsetDegrees,
    RangeRepTimingTraceSnapshot? activeTimingTrace,
    RangeRepTimingTraceSnapshot? lastEndedTimingTrace,
    int nonMonotonicObservationCount = 0,
  }) {
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    _rangeRepDiagnostics = previous.copyWith(
      repCount: repCount,
      currentPhase: currentPhase,
      lastCalibrationOffsetDegrees: calibrationOffsetDegrees,
      signalRoles: signalRoles,
      activeTimingTrace: activeTimingTrace,
      lastEndedTimingTrace: lastEndedTimingTrace,
      nonMonotonicObservationCount: nonMonotonicObservationCount,
    );
    _holdDiagnostics = null;
  }

  void updateHoldState({
    required int currentHoldSeconds,
    required int bestHoldSeconds,
    required String currentPhase,
    required bool isHolding,
    required Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles,
    HoldFeedbackCode? presentedHoldFeedbackCode,
    HoldDiagnosticsSnapshot? holdDiagnostics,
    HoldSide? currentHoldSide,
    HoldSignalValues? currentSignalValues,
    HoldSignalValues? targetSignalValues,
    HoldSignalValidity? signalValidity,
  }) {
    _holdDiagnostics = HoldWorkoutDiagnostics(
      currentHoldSeconds: currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds,
      currentPhase: currentPhase,
      isHolding: isHolding,
      presentedHoldFeedbackCode: presentedHoldFeedbackCode,
      engineHoldFeedbackCode: holdDiagnostics?.feedbackCode,
      holdEnginePhase: holdDiagnostics?.phase,
      currentHoldSide: currentHoldSide,
      lastVisibleHoldPosture: holdDiagnostics?.lastVisiblePosture,
      isHoldFormBreakGraceActive: holdDiagnostics?.isFormBreakGraceActive,
      isHoldVisibilitySuspended: holdDiagnostics?.isVisibilitySuspended,
      currentSignalValues: currentSignalValues,
      targetSignalValues:
          targetSignalValues ?? holdDiagnostics?.targetSignalValues,
      signalValidity: signalValidity ?? holdDiagnostics?.signalValidity,
      signalRoles: signalRoles,
    );
    _rangeRepDiagnostics = null;
  }

  WorkoutDiagnosticsSnapshot snapshot({required DateTime now}) {
    final sortedDurations = _processingDurationMs.toList()..sort();
    final sortedMinimumLikelihoods = _minimumRequiredLikelihoodSamples.toList()
      ..sort();
    final sortedMeanLikelihoods = _meanRequiredLikelihoodSamples.toList()
      ..sort();
    final sortedQualityScores = _poseQualityScoreSamples.toList()..sort();
    final sortedCameraFpsSamples = _cameraFpsSamples.toList()..sort();
    final sortedAnalysisFpsSamples = _analysisFpsSamples.toList()..sort();
    return WorkoutDiagnosticsSnapshot(
      schemaVersion: 8,
      appCommitSha: _appCommitSha,
      buildMode: _buildMode,
      analysisKind: _analysisKind,
      exerciseType: _exerciseType,
      configAssetPath: _configAssetPath,
      configVersionFingerprint: '$_configAssetPath@$_appCommitSha',
      contractProfile: _contractProfile,
      rangeRepSideMode: _rangeRepSideMode,
      rangeRepPrimaryMetricKind: _rangeRepPrimaryMetricKind,
      rangeRepPrimaryMetricDirection: _rangeRepPrimaryMetricDirection,
      holdAnalysisFamily: _holdAnalysisFamily,
      holdVariation: _holdVariation,
      sessionStartedAt: _sessionStartedAt,
      snapshotCreatedAt: now,
      elapsedMs: now.difference(_sessionStartedAt).inMilliseconds,
      cameraFrameCount: _cameraFrameCount,
      analysisAttemptCount: _analysisAttemptCount,
      analysisCompletedCount: _analysisCompletedCount,
      throttledFrameCount: _throttledFrameCount,
      reentrantDropCount: _reentrantDropCount,
      converterDropCount: _converterDropCount,
      noPoseFrameCount: _noPoseFrameCount,
      detectedPoseFrameCount: _detectedPoseFrameCount,
      acceptedPoseFrameCount: _acceptedPoseFrameCount,
      rejectedPoseFrameCount: _rejectedPoseFrameCount,
      lowConfidencePoseFrameCount: _lowConfidencePoseFrameCount,
      invalidPoseGeometryFrameCount: _invalidPoseGeometryFrameCount,
      multiPoseFrameCount: _multiPoseFrameCount,
      maxPoseCount: _maxPoseCount,
      analysisExceptionCount: _analysisExceptionCount,
      resyncCount: _resyncCount,
      poseReacquisitionCount: _poseReacquisitionCount,
      briefOcclusionCount: _briefOcclusionCount,
      briefOcclusionRecoveryCount: _briefOcclusionRecoveryCount,
      briefOcclusionAbortCount: _briefOcclusionAbortCount,
      holdVisibilitySuspendCount: _holdVisibilitySuspendCount,
      holdVisibilityRecoveryCount: _holdVisibilityRecoveryCount,
      holdVisibilityAbortCount: _holdVisibilityAbortCount,
      holdVisibilitySuspendedMsTotal: _holdVisibilitySuspendedMsTotal,
      lastHoldVisibilityGapMs: _lastHoldVisibilityGapMs,
      lastPoseRejectionReason: _lastPoseRejectionReason,
      poseRejectionReasonCounts: Map<String, int>.unmodifiable(
        _poseRejectionReasonCounts,
      ),
      poseQualitySampleCount: _poseQualitySampleCount,
      minimumRequiredLikelihoodP05: _nearestRankDouble(
        sortedMinimumLikelihoods,
        0.05,
      ),
      minimumRequiredLikelihoodP50: _nearestRankDouble(
        sortedMinimumLikelihoods,
        0.50,
      ),
      meanRequiredLikelihoodP05: _nearestRankDouble(
        sortedMeanLikelihoods,
        0.05,
      ),
      meanRequiredLikelihoodP50: _nearestRankDouble(
        sortedMeanLikelihoods,
        0.50,
      ),
      poseQualityScoreP50: _nearestRankDouble(sortedQualityScores, 0.50),
      poseQualityScoreP95: _nearestRankDouble(sortedQualityScores, 0.95),
      currentPoseQualityStatus: _currentPoseQualityStatus,
      currentVisibilityStatus: _currentVisibilityStatus,
      cameraViewContract: _cameraViewContract,
      cameraLensDirection: _cameraLensDirection,
      sensorOrientationDegrees: _sensorOrientationDegrees,
      deviceOrientation: _deviceOrientation,
      rangeRepDiagnostics: _rangeRepDiagnostics,
      holdDiagnostics: _holdDiagnostics,
      currentCameraFps: _currentCameraFps,
      currentAnalysisFps: _currentAnalysisFps,
      fpsSampleCount: _analysisFpsSamples.length,
      cameraFpsP50: _nearestRankDouble(sortedCameraFpsSamples, 0.50),
      cameraFpsP95: _nearestRankDouble(sortedCameraFpsSamples, 0.95),
      analysisFpsP50: _nearestRankDouble(sortedAnalysisFpsSamples, 0.50),
      analysisFpsP95: _nearestRankDouble(sortedAnalysisFpsSamples, 0.95),
      frameProcessingMsP50: _nearestRank(sortedDurations, 0.50),
      frameProcessingMsP95: _nearestRank(sortedDurations, 0.95),
      frameProcessingMsMax: sortedDurations.isEmpty
          ? null
          : sortedDurations.last,
    );
  }

  void reset({required DateTime now, required String analysisKind}) {
    _sessionStartedAt = now;
    _analysisKind = analysisKind;
    _processingDurationMs.clear();
    _minimumRequiredLikelihoodSamples.clear();
    _meanRequiredLikelihoodSamples.clear();
    _poseQualityScoreSamples.clear();
    _cameraFpsSamples.clear();
    _analysisFpsSamples.clear();
    _poseRejectionReasonCounts.clear();
    _cameraFrameCount = 0;
    _analysisAttemptCount = 0;
    _analysisCompletedCount = 0;
    _throttledFrameCount = 0;
    _reentrantDropCount = 0;
    _converterDropCount = 0;
    _noPoseFrameCount = 0;
    _detectedPoseFrameCount = 0;
    _acceptedPoseFrameCount = 0;
    _rejectedPoseFrameCount = 0;
    _lowConfidencePoseFrameCount = 0;
    _invalidPoseGeometryFrameCount = 0;
    _poseQualitySampleCount = 0;
    _multiPoseFrameCount = 0;
    _maxPoseCount = 0;
    _analysisExceptionCount = 0;
    _resyncCount = 0;
    _poseReacquisitionCount = 0;
    _briefOcclusionCount = 0;
    _briefOcclusionRecoveryCount = 0;
    _briefOcclusionAbortCount = 0;
    _holdVisibilitySuspendCount = 0;
    _holdVisibilityRecoveryCount = 0;
    _holdVisibilityAbortCount = 0;
    _holdVisibilitySuspendedMsTotal = 0;
    _lastHoldVisibilityGapMs = null;
    _lastPoseRejectionReason = null;
    _currentPoseQualityStatus = 'stable';
    _currentVisibilityStatus = 'stable';
    _cameraLensDirection = null;
    _sensorOrientationDegrees = null;
    _deviceOrientation = null;
    _currentCameraFps = null;
    _currentAnalysisFps = null;
    _rangeRepDiagnostics = null;
    _holdDiagnostics = null;
  }

  int? _nearestRank(List<int> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return null;
    final rank = (percentile * sortedValues.length).ceil().clamp(
      1,
      sortedValues.length,
    );
    return sortedValues[rank - 1];
  }

  double? _nearestRankDouble(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return null;
    final rank = (percentile * sortedValues.length).ceil().clamp(
      1,
      sortedValues.length,
    );
    return sortedValues[rank - 1];
  }

  void _appendFiniteSample(List<double> samples, double? value) {
    if (value == null || !value.isFinite) {
      return;
    }
    if (samples.length == maxProcessingDurationSamples) {
      samples.removeAt(0);
    }
    samples.add(value);
  }

  void _appendFiniteNonNegativeSample(List<double> samples, double value) {
    if (samples.length == maxProcessingDurationSamples) {
      samples.removeAt(0);
    }
    samples.add(value);
  }
}

Map<String, String>? _serializeCameraViewContract(
  CameraViewContract? contract,
) {
  if (contract == null) {
    return null;
  }

  return <String, String>{
    for (final view in CameraView.values)
      view.name: contract.supportFor(view).name,
  };
}

Map<String, List<String>>? _serializeRangeRepSignalRoles(
  Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles,
) {
  if (signalRoles.isEmpty) {
    return null;
  }

  return <String, List<String>>{
    for (final signal in RangeRepSignal.values)
      if (signalRoles.containsKey(signal))
        signal.name: _serializeAnalysisSignalRoles(signalRoles[signal]!),
  };
}

Map<String, List<String>>? _serializeHoldSignalRoles(
  Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles,
) {
  if (signalRoles.isEmpty) {
    return null;
  }

  return <String, List<String>>{
    for (final signal in HoldSignal.values)
      if (signalRoles.containsKey(signal))
        signal.name: _serializeAnalysisSignalRoles(signalRoles[signal]!),
  };
}

List<String> _serializeAnalysisSignalRoles(Set<AnalysisSignalRole> roles) {
  return <String>[
    for (final role in AnalysisSignalRole.values)
      if (roles.contains(role)) role.name,
  ];
}

Map<String, double>? _serializeHoldDoubleMap(Map<HoldSignal, double> values) {
  if (values.isEmpty) {
    return null;
  }

  return <String, double>{
    for (final signal in HoldSignal.values)
      if (values.containsKey(signal)) signal.name: values[signal]!,
  };
}

Map<String, bool>? _serializeHoldBoolMap(Map<HoldSignal, bool> values) {
  if (values.isEmpty) {
    return null;
  }

  return <String, bool>{
    for (final signal in HoldSignal.values)
      if (values.containsKey(signal)) signal.name: values[signal]!,
  };
}
