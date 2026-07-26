import 'setup_camera_view_orientation.dart';
import 'setup_framing_geometry.dart';
import 'setup_start_pose.dart';

/// Stable preparation state produced from framing, camera-view, and start-pose
/// evidence.
enum SetupReadinessPhase {
  initializing,
  noPerson,
  incompleteCoverage,
  clipped,
  tooNear,
  tooFar,
  offCenter,
  wrongView,
  startPoseMissing,
  stabilizing,
  ready,
  temporarilyLost,
  error,
}

/// Timing thresholds for conservative preparation readiness.
class SetupReadinessThresholds {
  factory SetupReadinessThresholds({
    required Duration stableEvidenceDuration,
    required Duration temporaryLossGraceDuration,
    required Duration maximumEvidenceAge,
  }) {
    assert(!stableEvidenceDuration.isNegative);
    assert(!temporaryLossGraceDuration.isNegative);
    assert(maximumEvidenceAge > Duration.zero);
    return SetupReadinessThresholds._(
      stableEvidenceDuration: stableEvidenceDuration,
      temporaryLossGraceDuration: temporaryLossGraceDuration,
      maximumEvidenceAge: maximumEvidenceAge,
    );
  }

  const SetupReadinessThresholds._({
    required this.stableEvidenceDuration,
    required this.temporaryLossGraceDuration,
    required this.maximumEvidenceAge,
  });

  static const SetupReadinessThresholds defaults = SetupReadinessThresholds._(
    stableEvidenceDuration: Duration(milliseconds: 1200),
    temporaryLossGraceDuration: Duration(milliseconds: 450),
    maximumEvidenceAge: Duration(milliseconds: 700),
  );

  final Duration stableEvidenceDuration;
  final Duration temporaryLossGraceDuration;
  final Duration maximumEvidenceAge;
}

/// One synchronized set of preparation diagnostics.
class SetupReadinessEvidence {
  const SetupReadinessEvidence({
    this.framingAssessment,
    this.cameraViewAssessment,
    this.startPoseAssessment,
    this.errorCode,
  });

  final SetupFramingAssessment? framingAssessment;
  final SetupCameraViewAssessment? cameraViewAssessment;
  final SetupStartPoseAssessment? startPoseAssessment;
  final String? errorCode;

  bool get hasError => errorCode != null;
}

/// Traceable timing and raw-evidence snapshot for debugging and tests.
class SetupReadinessDiagnosticsSnapshot {
  const SetupReadinessDiagnosticsSnapshot({
    required this.rawPhase,
    required this.framingStatus,
    required this.cameraViewStatus,
    required this.startPoseStatus,
    required this.stableEvidenceDuration,
    required this.temporaryLossDuration,
    required this.stabilityProgress,
    required this.confidence,
  });

  final SetupReadinessPhase rawPhase;
  final SetupFramingStatus? framingStatus;
  final SetupCameraViewAdvisoryStatus? cameraViewStatus;
  final SetupStartPoseStatus? startPoseStatus;
  final Duration stableEvidenceDuration;
  final Duration temporaryLossDuration;
  final double stabilityProgress;
  final double confidence;
}

/// Immutable state exposed to preparation presentation consumers.
class SetupReadinessSnapshot {
  const SetupReadinessSnapshot({
    required this.phase,
    required this.evidence,
    required this.enteredAt,
    required this.updatedAt,
    required this.diagnostics,
  });

  final SetupReadinessPhase phase;
  final SetupReadinessEvidence evidence;
  final DateTime enteredAt;
  final DateTime updatedAt;
  final SetupReadinessDiagnosticsSnapshot diagnostics;

  bool get isReady => phase == SetupReadinessPhase.ready;
}
