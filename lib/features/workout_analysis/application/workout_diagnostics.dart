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
    this.currentSelectedSide,
    this.lastCalibrationOffsetDegrees,
    this.signalRoles = const <RangeRepSignal, Set<AnalysisSignalRole>>{},
  });

  final int? repCount;
  final String? currentPhase;
  final int sideSwitchCount;
  final int activeRepSideSwitchCount;
  final String? currentSelectedSide;
  final double? lastCalibrationOffsetDegrees;
  final Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles;

  RangeRepWorkoutDiagnostics copyWith({
    Object? repCount = _unsetValue,
    Object? currentPhase = _unsetValue,
    int? sideSwitchCount,
    int? activeRepSideSwitchCount,
    Object? currentSelectedSide = _unsetValue,
    Object? lastCalibrationOffsetDegrees = _unsetValue,
    Object? signalRoles = _unsetValue,
  }) {
    return RangeRepWorkoutDiagnostics(
      repCount: repCount == _unsetValue ? this.repCount : repCount as int?,
      currentPhase: currentPhase == _unsetValue
          ? this.currentPhase
          : currentPhase as String?,
      sideSwitchCount: sideSwitchCount ?? this.sideSwitchCount,
      activeRepSideSwitchCount:
          activeRepSideSwitchCount ?? this.activeRepSideSwitchCount,
      currentSelectedSide: currentSelectedSide == _unsetValue
          ? this.currentSelectedSide
          : currentSelectedSide as String?,
      lastCalibrationOffsetDegrees: lastCalibrationOffsetDegrees == _unsetValue
          ? this.lastCalibrationOffsetDegrees
          : lastCalibrationOffsetDegrees as double?,
      signalRoles: signalRoles == _unsetValue
          ? this.signalRoles
          : signalRoles as Map<RangeRepSignal, Set<AnalysisSignalRole>>,
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
    this.cameraViewContract,
    this.rangeRepDiagnostics,
    this.holdDiagnostics,
    required this.currentCameraFps,
    required this.currentAnalysisFps,
    required this.frameProcessingMsP50,
    required this.frameProcessingMsP95,
    required this.frameProcessingMsMax,
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
  final CameraViewContract? cameraViewContract;
  final RangeRepWorkoutDiagnostics? rangeRepDiagnostics;
  final HoldWorkoutDiagnostics? holdDiagnostics;
  final double? currentCameraFps;
  final double? currentAnalysisFps;
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

  String? get currentSelectedSide => rangeRepDiagnostics?.currentSelectedSide;

  double? get lastCalibrationOffsetDegrees =>
      rangeRepDiagnostics?.lastCalibrationOffsetDegrees;

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
    'camera_view_contract': _serializeCameraViewContract(cameraViewContract),
    'range_rep_signal_roles': _serializeRangeRepSignalRoles(
      rangeRepSignalRoles,
    ),
    'hold_signal_roles': _serializeHoldSignalRoles(holdSignalRoles),
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

/// Session-level accumulator. Processing samples use a 10,000-item rolling
/// window and deterministic nearest-rank percentiles.
class WorkoutDiagnosticsAccumulator {
  WorkoutDiagnosticsAccumulator({
    required DateTime sessionStartedAt,
    required String analysisKind,
    required CameraViewContract cameraViewContract,
    String appCommitSha = _defaultAppCommitSha,
    String? buildMode,
  }) : _appCommitSha = appCommitSha,
       _buildMode = buildMode ?? workoutDiagnosticsBuildMode,
       _cameraViewContract = cameraViewContract,
       _sessionStartedAt = sessionStartedAt,
       _analysisKind = analysisKind;

  static const int maxProcessingDurationSamples = 10000;

  final String _appCommitSha;
  final String _buildMode;
  final CameraViewContract _cameraViewContract;
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

  void updateRangeRepState({
    required int repCount,
    required String currentPhase,
    required Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles,
    double? calibrationOffsetDegrees,
  }) {
    final previous = _rangeRepDiagnostics ?? const RangeRepWorkoutDiagnostics();
    _rangeRepDiagnostics = previous.copyWith(
      repCount: repCount,
      currentPhase: currentPhase,
      lastCalibrationOffsetDegrees: calibrationOffsetDegrees,
      signalRoles: signalRoles,
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
    return WorkoutDiagnosticsSnapshot(
      schemaVersion: 5,
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
      cameraViewContract: _cameraViewContract,
      rangeRepDiagnostics: _rangeRepDiagnostics,
      holdDiagnostics: _holdDiagnostics,
      currentCameraFps: _currentCameraFps,
      currentAnalysisFps: _currentAnalysisFps,
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
