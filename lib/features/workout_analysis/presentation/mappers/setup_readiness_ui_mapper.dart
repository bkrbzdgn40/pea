import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/camera_view_contract.dart';
import '../../domain/models/setup_camera_view_orientation.dart';
import '../../domain/models/setup_framing_geometry.dart';
import '../../domain/models/setup_readiness_state.dart';
import '../../domain/models/setup_start_pose.dart';
import '../models/setup_readiness_view_data.dart';

SetupReadinessViewData mapSetupReadinessToViewData({
  required AppLocalizations localizations,
  required SetupReadinessSnapshot readinessSnapshot,
}) {
  final projection = _projectReadiness(
    localizations: localizations,
    snapshot: readinessSnapshot,
  );
  final evidence = readinessSnapshot.evidence;

  return SetupReadinessViewData(
    statusLabel: projection.statusLabel,
    message: projection.message,
    visualState: projection.visualState,
    isReady: readinessSnapshot.isReady,
    checks: <SetupReadinessCheckItem>[
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.person,
        label: localizations.preparationCheckPersonVisibility,
        state: _personCheckState(evidence.framingAssessment),
      ),
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.framing,
        label: localizations.preparationCheckFraming,
        state: _framingCheckState(evidence.framingAssessment),
      ),
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.cameraView,
        label: localizations.preparationCheckCameraView,
        state: _cameraViewCheckState(
          evidence.framingAssessment,
          evidence.cameraViewAssessment,
        ),
      ),
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.startPose,
        label: localizations.preparationCheckStartPose,
        state: _startPoseCheckState(
          evidence.framingAssessment,
          evidence.cameraViewAssessment,
          evidence.startPoseAssessment,
        ),
      ),
    ],
  );
}

_SetupReadinessProjection _projectReadiness({
  required AppLocalizations localizations,
  required SetupReadinessSnapshot snapshot,
}) {
  return switch (snapshot.phase) {
    SetupReadinessPhase.initializing => _checking(
      localizations,
      localizations.preparationCameraViewCheckingGuidance,
    ),
    SetupReadinessPhase.noPerson => _needsAdjustment(
      localizations,
      localizations.preparationNoPersonGuidance,
    ),
    SetupReadinessPhase.incompleteCoverage => _needsAdjustment(
      localizations,
      localizations.preparationIncompleteCoverageGuidance,
    ),
    SetupReadinessPhase.clipped => _needsAdjustment(
      localizations,
      localizations.preparationClippedGuidance,
    ),
    SetupReadinessPhase.tooNear => _needsAdjustment(
      localizations,
      localizations.preparationTooNearGuidance,
    ),
    SetupReadinessPhase.tooFar => _needsAdjustment(
      localizations,
      localizations.preparationTooFarGuidance,
    ),
    SetupReadinessPhase.offCenter => _needsAdjustment(
      localizations,
      localizations.preparationOffCenterGuidance,
    ),
    SetupReadinessPhase.wrongView => _needsAdjustment(
      localizations,
      _cameraViewGuidance(localizations, snapshot),
    ),
    SetupReadinessPhase.startPoseMissing => _needsAdjustment(
      localizations,
      localizations.preparationStartPoseGuidance,
    ),
    SetupReadinessPhase.stabilizing => _checking(
      localizations,
      localizations.preparationStabilizingGuidance,
    ),
    SetupReadinessPhase.ready => _ready(localizations, snapshot),
    SetupReadinessPhase.temporarilyLost => _checking(
      localizations,
      localizations.preparationTemporarilyLostGuidance,
    ),
    SetupReadinessPhase.error => _needsAdjustment(
      localizations,
      localizations.preparationReadinessErrorGuidance,
    ),
  };
}

_SetupReadinessProjection _checking(
  AppLocalizations localizations,
  String message,
) {
  return _SetupReadinessProjection(
    visualState: SetupReadinessVisualState.checking,
    statusLabel: localizations.preparationReadinessChecking,
    message: message,
  );
}

_SetupReadinessProjection _needsAdjustment(
  AppLocalizations localizations,
  String message,
) {
  return _SetupReadinessProjection(
    visualState: SetupReadinessVisualState.needsAdjustment,
    statusLabel: localizations.preparationReadinessNeedsAdjustment,
    message: message,
  );
}

_SetupReadinessProjection _ready(
  AppLocalizations localizations,
  SetupReadinessSnapshot snapshot,
) {
  final cameraStatus = snapshot.evidence.cameraViewAssessment?.status;
  return _SetupReadinessProjection(
    visualState: SetupReadinessVisualState.ready,
    statusLabel: localizations.preparationReadinessReady,
    message: cameraStatus == SetupCameraViewAdvisoryStatus.supported
        ? localizations.preparationSupportedCameraViewGuidance
        : localizations.preparationReadyGuidance,
  );
}

String _cameraViewGuidance(
  AppLocalizations localizations,
  SetupReadinessSnapshot snapshot,
) {
  return switch (snapshot.evidence.cameraViewAssessment?.recommendedView) {
    CameraView.front => localizations.preparationFaceCameraGuidance,
    CameraView.side => localizations.preparationTurnSideGuidance,
    null => localizations.preparationCameraViewCheckingGuidance,
  };
}

SetupReadinessCheckState _personCheckState(SetupFramingAssessment? assessment) {
  if (assessment == null || !assessment.personDetected) {
    return SetupReadinessCheckState.pending;
  }
  return SetupReadinessCheckState.complete;
}

SetupReadinessCheckState _framingCheckState(
  SetupFramingAssessment? assessment,
) {
  if (assessment == null || !assessment.personDetected) {
    return SetupReadinessCheckState.pending;
  }
  if (assessment.isReady) {
    return SetupReadinessCheckState.complete;
  }
  return SetupReadinessCheckState.needsAdjustment;
}

SetupReadinessCheckState _cameraViewCheckState(
  SetupFramingAssessment? framingAssessment,
  SetupCameraViewAssessment? cameraViewAssessment,
) {
  if (framingAssessment?.isReady != true || cameraViewAssessment == null) {
    return SetupReadinessCheckState.pending;
  }

  return switch (cameraViewAssessment.status) {
    SetupCameraViewAdvisoryStatus.preferred ||
    SetupCameraViewAdvisoryStatus.supported =>
      SetupReadinessCheckState.complete,
    SetupCameraViewAdvisoryStatus.unsupported =>
      SetupReadinessCheckState.needsAdjustment,
    SetupCameraViewAdvisoryStatus.insufficientEvidence ||
    SetupCameraViewAdvisoryStatus.indeterminate =>
      SetupReadinessCheckState.pending,
  };
}

SetupReadinessCheckState _startPoseCheckState(
  SetupFramingAssessment? framingAssessment,
  SetupCameraViewAssessment? cameraViewAssessment,
  SetupStartPoseAssessment? startPoseAssessment,
) {
  final cameraViewReady =
      cameraViewAssessment?.status == SetupCameraViewAdvisoryStatus.preferred ||
      cameraViewAssessment?.status == SetupCameraViewAdvisoryStatus.supported;
  if (framingAssessment?.isReady != true ||
      !cameraViewReady ||
      startPoseAssessment == null) {
    return SetupReadinessCheckState.pending;
  }

  return switch (startPoseAssessment.status) {
    SetupStartPoseStatus.matched => SetupReadinessCheckState.complete,
    SetupStartPoseStatus.notMatched => SetupReadinessCheckState.needsAdjustment,
    SetupStartPoseStatus.insufficientEvidence =>
      SetupReadinessCheckState.pending,
  };
}

class _SetupReadinessProjection {
  const _SetupReadinessProjection({
    required this.visualState,
    required this.statusLabel,
    required this.message,
  });

  final SetupReadinessVisualState visualState;
  final String statusLabel;
  final String message;
}
