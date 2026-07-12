import 'package:flutter/foundation.dart';

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
    required this.multiPoseFrameCount,
    required this.maxPoseCount,
    required this.analysisExceptionCount,
    required this.resyncCount,
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
  final int multiPoseFrameCount;
  final int maxPoseCount;
  final int analysisExceptionCount;
  final int resyncCount;
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
    'multi_pose_frame_count': multiPoseFrameCount,
    'max_pose_count': maxPoseCount,
    'analysis_exception_count': analysisExceptionCount,
    'resync_count': resyncCount,
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
  int _multiPoseFrameCount = 0;
  int _maxPoseCount = 0;
  int _analysisExceptionCount = 0;
  int _resyncCount = 0;
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

  void recordCameraFrame() => _cameraFrameCount++;
  void recordAnalysisAttempt() => _analysisAttemptCount++;
  void recordAnalysisCompleted() => _analysisCompletedCount++;
  void recordThrottledFrame() => _throttledFrameCount++;
  void recordReentrantDrop() => _reentrantDropCount++;
  void recordConverterDrop() => _converterDropCount++;
  void recordAnalysisException() => _analysisExceptionCount++;
  void recordResync() => _resyncCount++;

  void recordPoseCount(int poseCount) {
    if (poseCount < 0) throw ArgumentError.value(poseCount, 'poseCount');
    if (poseCount == 0) _noPoseFrameCount++;
    if (poseCount > 1) _multiPoseFrameCount++;
    if (poseCount > _maxPoseCount) _maxPoseCount = poseCount;
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
  }) {
    _repCount = repCount;
    _currentHoldSeconds = currentHoldSeconds;
    _bestHoldSeconds = bestHoldSeconds;
    _currentPhase = currentPhase;
    _isHolding = isHolding;
    _lastCalibrationOffsetDegrees = calibrationOffsetDegrees;
  }

  WorkoutDiagnosticsSnapshot snapshot({required DateTime now}) {
    final sortedDurations = _processingDurationMs.toList()..sort();
    return WorkoutDiagnosticsSnapshot(
      schemaVersion: 1,
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
      multiPoseFrameCount: _multiPoseFrameCount,
      maxPoseCount: _maxPoseCount,
      analysisExceptionCount: _analysisExceptionCount,
      resyncCount: _resyncCount,
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
    _multiPoseFrameCount = 0;
    _maxPoseCount = 0;
    _analysisExceptionCount = 0;
    _resyncCount = 0;
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
