import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/camera_view_contract.dart';
import '../../domain/models/setup_camera_view_orientation.dart';
import '../../domain/models/setup_framing_geometry.dart';
import '../models/setup_readiness_view_data.dart';

SetupReadinessViewData mapSetupReadinessToViewData({
  required AppLocalizations localizations,
  required SetupFramingAssessment? framingAssessment,
  required SetupCameraViewAssessment? cameraViewAssessment,
}) {
  final projection = framingAssessment == null
      ? _SetupReadinessProjection(
          visualState: SetupReadinessVisualState.checking,
          statusLabel: localizations.preparationReadinessChecking,
          message: localizations.preparationCameraViewCheckingGuidance,
          isReady: false,
        )
      : switch (framingAssessment.status) {
          SetupFramingStatus.noPerson => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationNoPersonGuidance,
            isReady: false,
          ),
          SetupFramingStatus.incompleteCoverage => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationIncompleteCoverageGuidance,
            isReady: false,
          ),
          SetupFramingStatus.clipped => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationClippedGuidance,
            isReady: false,
          ),
          SetupFramingStatus.tooNear => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationTooNearGuidance,
            isReady: false,
          ),
          SetupFramingStatus.tooFar => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationTooFarGuidance,
            isReady: false,
          ),
          SetupFramingStatus.offCenter => _SetupReadinessProjection(
            visualState: SetupReadinessVisualState.needsAdjustment,
            statusLabel: localizations.preparationReadinessNeedsAdjustment,
            message: localizations.preparationOffCenterGuidance,
            isReady: false,
          ),
          SetupFramingStatus.ready => _projectCameraView(
            localizations: localizations,
            assessment: cameraViewAssessment,
          ),
        };

  return SetupReadinessViewData(
    statusLabel: projection.statusLabel,
    message: projection.message,
    visualState: projection.visualState,
    isReady: projection.isReady,
    checks: <SetupReadinessCheckItem>[
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.person,
        label: localizations.preparationCheckPersonVisibility,
        state: _personCheckState(framingAssessment),
      ),
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.framing,
        label: localizations.preparationCheckFraming,
        state: _framingCheckState(framingAssessment),
      ),
      SetupReadinessCheckItem(
        type: SetupReadinessCheckType.cameraView,
        label: localizations.preparationCheckCameraView,
        state: _cameraViewCheckState(framingAssessment, cameraViewAssessment),
      ),
    ],
  );
}

_SetupReadinessProjection _projectCameraView({
  required AppLocalizations localizations,
  required SetupCameraViewAssessment? assessment,
}) {
  if (assessment == null ||
      assessment.status == SetupCameraViewAdvisoryStatus.insufficientEvidence ||
      assessment.status == SetupCameraViewAdvisoryStatus.indeterminate) {
    return _SetupReadinessProjection(
      visualState: SetupReadinessVisualState.checking,
      statusLabel: localizations.preparationReadinessChecking,
      message: localizations.preparationCameraViewCheckingGuidance,
      isReady: false,
    );
  }

  if (assessment.status == SetupCameraViewAdvisoryStatus.unsupported) {
    final message = switch (assessment.recommendedView) {
      CameraView.front => localizations.preparationFaceCameraGuidance,
      CameraView.side => localizations.preparationTurnSideGuidance,
      null => localizations.preparationCameraViewCheckingGuidance,
    };
    return _SetupReadinessProjection(
      visualState: SetupReadinessVisualState.needsAdjustment,
      statusLabel: localizations.preparationReadinessNeedsAdjustment,
      message: message,
      isReady: false,
    );
  }

  if (assessment.status == SetupCameraViewAdvisoryStatus.supported) {
    return _SetupReadinessProjection(
      visualState: SetupReadinessVisualState.ready,
      statusLabel: localizations.preparationReadinessReady,
      message: localizations.preparationSupportedCameraViewGuidance,
      isReady: true,
    );
  }

  return _SetupReadinessProjection(
    visualState: SetupReadinessVisualState.ready,
    statusLabel: localizations.preparationReadinessReady,
    message: localizations.preparationReadyGuidance,
    isReady: true,
  );
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

class _SetupReadinessProjection {
  const _SetupReadinessProjection({
    required this.visualState,
    required this.statusLabel,
    required this.message,
    required this.isReady,
  });

  final SetupReadinessVisualState visualState;
  final String statusLabel;
  final String message;
  final bool isReady;
}
