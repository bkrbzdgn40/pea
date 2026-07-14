import 'package:flutter/foundation.dart';

import '../domain/hold_diagnostics.dart';
import '../domain/models/hold_feedback_code.dart';
import '../domain/models/hold_phase.dart';
import '../domain/models/hold_side.dart';

const String _defaultAppCommitSha = String.fromEnvironment(
  'PEA_COMMIT_SHA',
  defaultValue: 'unknown',
);

String get workoutDiagnosticsBuildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

/// Immutable, privacy-minimized diagnostics for one analysis session.
class WorkoutDiagnosticsSnapshot {
  const WorkoutDiagnosticsSnapshot({
    required this.schemaVersion,
    required this.appCommitSha,
    required this.buildMode,
    required this.analysisKind,
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
    this.lastPoseRejectionReason,
    this.currentPoseQualityStatus = 'stable',
    this.currentVisibilityStatus = 'stable',
    required this.sideSwitchCount,
    required this.activeRepSideSwitchCount,
    required this.currentSelectedSide,
    required this.lastCalibrationOffsetDegrees,
    required this.currentCameraFps,
    required this.currentAnalysisFps,
    required this.frameProcessingMsP50,
    required this.frameProcessingMsP95,
    required this.frameProcessingMsMax,
    required this.repCount,
    required this.currentHoldSeconds,
    required this.bestHoldSeconds,
    required this.currentPhase,
    required this.isHolding,
    this.presentedHoldFeedbackCode,
    this.engineHoldFeedbackCode,
    this.holdEnginePhase,
    this.currentHoldSide,
    this.lastVisibleHoldPosture,
    this.isHoldFormBreakGraceActive,
    this.isHoldVisibilitySuspended,
  });

  final int schemaVersion;
  final String appCommitSha;
  final String buildMode;
  final String analysisKind;
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
  final String? lastPoseRejectionReason;
  final String currentPoseQualityStatus;
  final String currentVisibilityStatus;
  final int sideSwitchCount;
  final int activeRepSideSwitchCount;
  final String? currentSelectedSide;
  final double? lastCalibrationOffsetDegrees;
  final double? currentCameraFps;
  final double? currentAnalysisFps;
  final int? frameProcessingMsP50;
  final int? frameProcessingMsP95;
  final int? frameProcessingMsMax;
  final int? repCount;
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

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': schemaVersion,
    'app_commit_sha': appCommitSha,
    'build_mode': buildMode,
    'analysis_kind': analysisKind,
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
    'last_pose_rejection_reason': lastPoseRejectionReason,
    'current_pose_quality_status': currentPoseQualityStatus,
    'current_visibility_status': currentVisibilityStatus,
    'side_switch_count': sideSwitchCount,
    'active_rep_side_switch_count': activeRepSideSwitchCount,
    'current_selected_side': currentSelectedSide,
    'last_calibration_offset_degrees': lastCalibrationOffsetDegrees,
    'current_camera_fps': currentCameraFps,
    'current_analysis_fps': currentAnalysisFps,
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
    'hold_has_complete_metrics': lastVisibleHoldPosture?.hasCompleteMetrics,
    'hold_has_active_posture': lastVisibleHoldPosture?.hasActivePosture,
    'hold_is_body_aligned': lastVisibleHoldPosture?.isBodyAligned,
    'hold_is_arm_supported': lastVisibleHoldPosture?.isArmSupported,
    'hold_are_legs_extended': lastVisibleHoldPosture?.areLegsExtended,
    'hold_is_form_break_grace_active': isHoldFormBreakGraceActive,
    'hold_is_visibility_suspended': isHoldVisibilitySuspended,
  };
}

/// Session-level accumulator. Processing samples use a 10,000-item rolling
/// window and deterministic nearest-rank percentiles.
class WorkoutDiagnosticsAccumulator {
  WorkoutDiagnosticsAccumulator({
    required DateTime sessionStartedAt,
    required String analysisKind,
    String appCommitSha = _defaultAppCommitSha,
    String? buildMode,
  }) : _appCommitSha = appCommitSha,
       _buildMode = buildMode ?? workoutDiagnosticsBuildMode,
       _sessionStartedAt = sessionStartedAt,
       _analysisKind = analysisKind;

  static const int maxProcessingDurationSamples = 10000;

  final String _appCommitSha;
  final String _buildMode;
  late DateTime _sessionStartedAt;
  late String _analysisKind;
  final List<int> _processingDurationMs = <int>[];

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
  int _multiPoseFrameCount = 0;
  int _maxPoseCount = 0;
  int _analysisExceptionCount = 0;
  int _resyncCount = 0;
  int _poseReacquisitionCount = 0;
  int _briefOcclusionCount = 0;
  int _briefOcclusionRecoveryCount = 0;
  int _briefOcclusionAbortCount = 0;
  String? _lastPoseRejectionReason;
  String _currentPoseQualityStatus = 'stable';
  String _currentVisibilityStatus = 'stable';
  int _sideSwitchCount = 0;
  int _activeRepSideSwitchCount = 0;
  String? _currentSelectedSide;
  double? _lastCalibrationOffsetDegrees;
  double? _currentCameraFps;
  double? _currentAnalysisFps;
  int? _repCount;
  int? _currentHoldSeconds;
  int? _bestHoldSeconds;
  String? _currentPhase;
  bool? _isHolding;
  HoldFeedbackCode? _presentedHoldFeedbackCode;
  HoldFeedbackCode? _engineHoldFeedbackCode;
  HoldPhase? _holdEnginePhase;
  HoldSide? _currentHoldSide;
  HoldPostureDiagnosticsSnapshot? _lastVisibleHoldPosture;
  bool? _isHoldFormBreakGraceActive;
  bool? _isHoldVisibilitySuspended;

  void recordCameraFrame() => _cameraFrameCount++;
  void recordAnalysisAttempt() => _analysisAttemptCount++;
  void recordAnalysisCompleted() => _analysisCompletedCount++;
  void recordThrottledFrame() => _throttledFrameCount++;
  void recordReentrantDrop() => _reentrantDropCount++;
  void recordConverterDrop() => _converterDropCount++;
  void recordAnalysisException() => _analysisExceptionCount++;
  void recordResync() => _resyncCount++;
  void recordAcceptedPoseFrame() => _acceptedPoseFrameCount++;
  void recordPoseReacquisition() => _poseReacquisitionCount++;
  void recordBriefOcclusion() => _briefOcclusionCount++;
  void recordBriefOcclusionRecovery() => _briefOcclusionRecoveryCount++;
  void recordBriefOcclusionAbort() => _briefOcclusionAbortCount++;

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

  /// The first non-null side is an assignment, not a switch. Repeating a side
  /// and transitions to null are not switches. A null transition clears the
  /// current side, so the next non-null side is a fresh assignment.
  void recordSelectedSide({
    required String? selectedSide,
    required bool hasActiveRepContext,
  }) {
    if (selectedSide == null) {
      _currentSelectedSide = null;
      return;
    }
    final previousSide = _currentSelectedSide;
    if (previousSide != null && previousSide != selectedSide) {
      _sideSwitchCount++;
      if (hasActiveRepContext) _activeRepSideSwitchCount++;
    }
    _currentSelectedSide = selectedSide;
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

  void updateWorkoutState({
    required int repCount,
    required int currentHoldSeconds,
    required int bestHoldSeconds,
    required String currentPhase,
    required bool isHolding,
    double? calibrationOffsetDegrees,
    HoldFeedbackCode? presentedHoldFeedbackCode,
    HoldDiagnosticsSnapshot? holdDiagnostics,
    HoldSide? currentHoldSide,
  }) {
    _repCount = repCount;
    _currentHoldSeconds = currentHoldSeconds;
    _bestHoldSeconds = bestHoldSeconds;
    _currentPhase = currentPhase;
    _isHolding = isHolding;
    _lastCalibrationOffsetDegrees = calibrationOffsetDegrees;
    _presentedHoldFeedbackCode = presentedHoldFeedbackCode;
    _engineHoldFeedbackCode = holdDiagnostics?.feedbackCode;
    _holdEnginePhase = holdDiagnostics?.phase;
    _currentHoldSide = currentHoldSide;
    _lastVisibleHoldPosture = holdDiagnostics?.lastVisiblePosture;
    _isHoldFormBreakGraceActive = holdDiagnostics?.isFormBreakGraceActive;
    _isHoldVisibilitySuspended = holdDiagnostics?.isVisibilitySuspended;
  }

  WorkoutDiagnosticsSnapshot snapshot({required DateTime now}) {
    final sortedDurations = _processingDurationMs.toList()..sort();
    return WorkoutDiagnosticsSnapshot(
      schemaVersion: 3,
      appCommitSha: _appCommitSha,
      buildMode: _buildMode,
      analysisKind: _analysisKind,
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
      lastPoseRejectionReason: _lastPoseRejectionReason,
      currentPoseQualityStatus: _currentPoseQualityStatus,
      currentVisibilityStatus: _currentVisibilityStatus,
      sideSwitchCount: _sideSwitchCount,
      activeRepSideSwitchCount: _activeRepSideSwitchCount,
      currentSelectedSide: _currentSelectedSide,
      lastCalibrationOffsetDegrees: _lastCalibrationOffsetDegrees,
      currentCameraFps: _currentCameraFps,
      currentAnalysisFps: _currentAnalysisFps,
      frameProcessingMsP50: _nearestRank(sortedDurations, 0.50),
      frameProcessingMsP95: _nearestRank(sortedDurations, 0.95),
      frameProcessingMsMax: sortedDurations.isEmpty
          ? null
          : sortedDurations.last,
      repCount: _repCount,
      currentHoldSeconds: _currentHoldSeconds,
      bestHoldSeconds: _bestHoldSeconds,
      currentPhase: _currentPhase,
      isHolding: _isHolding,
      presentedHoldFeedbackCode: _presentedHoldFeedbackCode,
      engineHoldFeedbackCode: _engineHoldFeedbackCode,
      holdEnginePhase: _holdEnginePhase,
      currentHoldSide: _currentHoldSide,
      lastVisibleHoldPosture: _lastVisibleHoldPosture,
      isHoldFormBreakGraceActive: _isHoldFormBreakGraceActive,
      isHoldVisibilitySuspended: _isHoldVisibilitySuspended,
    );
  }

  void reset({required DateTime now, required String analysisKind}) {
    _sessionStartedAt = now;
    _analysisKind = analysisKind;
    _processingDurationMs.clear();
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
    _multiPoseFrameCount = 0;
    _maxPoseCount = 0;
    _analysisExceptionCount = 0;
    _resyncCount = 0;
    _poseReacquisitionCount = 0;
    _briefOcclusionCount = 0;
    _briefOcclusionRecoveryCount = 0;
    _briefOcclusionAbortCount = 0;
    _lastPoseRejectionReason = null;
    _currentPoseQualityStatus = 'stable';
    _currentVisibilityStatus = 'stable';
    _sideSwitchCount = 0;
    _activeRepSideSwitchCount = 0;
    _currentSelectedSide = null;
    _lastCalibrationOffsetDegrees = null;
    _currentCameraFps = null;
    _currentAnalysisFps = null;
    _repCount = null;
    _currentHoldSeconds = null;
    _bestHoldSeconds = null;
    _currentPhase = null;
    _isHolding = null;
    _presentedHoldFeedbackCode = null;
    _engineHoldFeedbackCode = null;
    _holdEnginePhase = null;
    _currentHoldSide = null;
    _lastVisibleHoldPosture = null;
    _isHoldFormBreakGraceActive = null;
    _isHoldVisibilitySuspended = null;
  }

  int? _nearestRank(List<int> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return null;
    final rank = (percentile * sortedValues.length).ceil().clamp(
      1,
      sortedValues.length,
    );
    return sortedValues[rank - 1];
  }
}
