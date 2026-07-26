import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_camera_view_orientation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_framing_geometry.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/setup_readiness_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/setup_readiness_view_data.dart';

void main() {
  const turkish = AppLocalizations(Locale('tr'));
  const english = AppLocalizations(Locale('en'));

  test('prioritizes missing person over camera-view evidence', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      framingAssessment: _framing(SetupFramingStatus.noPerson),
      cameraViewAssessment: _cameraView(
        SetupCameraViewAdvisoryStatus.unsupported,
        recommendedView: CameraView.side,
      ),
    );

    expect(viewData.message, 'Kadraja geç ve vücudunu kameraya göster.');
    expect(viewData.visualState, SetupReadinessVisualState.needsAdjustment);
    expect(viewData.isReady, isFalse);
    expect(
      _check(viewData, SetupReadinessCheckType.person).state,
      SetupReadinessCheckState.pending,
    );
    expect(
      _check(viewData, SetupReadinessCheckType.cameraView).state,
      SetupReadinessCheckState.pending,
    );
  });

  test('projects one actionable message for every framing problem', () {
    final expectations = <SetupFramingStatus, String>{
      SetupFramingStatus.incompleteCoverage:
          'Some required joints are not visible. Bring the requested body areas into the frame.',
      SetupFramingStatus.clipped:
          'Part of your body is outside the frame. Move slightly farther back.',
      SetupFramingStatus.tooNear:
          'You are too close to the camera. Move a little farther back.',
      SetupFramingStatus.tooFar:
          'You are too far from the camera. Move a little closer.',
      SetupFramingStatus.offCenter: 'Move toward the center of the frame.',
    };

    for (final entry in expectations.entries) {
      final viewData = mapSetupReadinessToViewData(
        localizations: english,
        framingAssessment: _framing(entry.key),
        cameraViewAssessment: _cameraView(
          SetupCameraViewAdvisoryStatus.unsupported,
          recommendedView: CameraView.side,
        ),
      );

      expect(viewData.message, entry.value, reason: entry.key.name);
      expect(
        _check(viewData, SetupReadinessCheckType.person).state,
        SetupReadinessCheckState.complete,
      );
      expect(
        _check(viewData, SetupReadinessCheckType.framing).state,
        SetupReadinessCheckState.needsAdjustment,
      );
      expect(
        _check(viewData, SetupReadinessCheckType.cameraView).state,
        SetupReadinessCheckState.pending,
      );
    }
  });

  test('keeps camera view in checking state when evidence is inconclusive', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: english,
      framingAssessment: _framing(SetupFramingStatus.ready),
      cameraViewAssessment: _cameraView(
        SetupCameraViewAdvisoryStatus.indeterminate,
      ),
    );

    expect(viewData.statusLabel, 'Checking');
    expect(
      viewData.message,
      'Keep your shoulders and hips visible and hold still briefly.',
    );
    expect(viewData.visualState, SetupReadinessVisualState.checking);
    expect(viewData.isReady, isFalse);
    expect(
      _check(viewData, SetupReadinessCheckType.framing).state,
      SetupReadinessCheckState.complete,
    );
    expect(
      _check(viewData, SetupReadinessCheckType.cameraView).state,
      SetupReadinessCheckState.pending,
    );
  });

  test('asks for the recommended side view when front is unsupported', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      framingAssessment: _framing(SetupFramingStatus.ready),
      cameraViewAssessment: _cameraView(
        SetupCameraViewAdvisoryStatus.unsupported,
        detectedView: CameraView.front,
        recommendedView: CameraView.side,
      ),
    );

    expect(viewData.message, 'Sağ veya sol yanını kameraya dön.');
    expect(viewData.statusLabel, 'Konumunu ayarla');
    expect(viewData.isReady, isFalse);
    expect(
      _check(viewData, SetupReadinessCheckType.cameraView).state,
      SetupReadinessCheckState.needsAdjustment,
    );
  });

  test('marks preferred framing and view as ready', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      framingAssessment: _framing(SetupFramingStatus.ready),
      cameraViewAssessment: _cameraView(
        SetupCameraViewAdvisoryStatus.preferred,
        detectedView: CameraView.side,
        recommendedView: CameraView.side,
      ),
    );

    expect(viewData.statusLabel, 'Hazır');
    expect(viewData.message, 'Kadraj ve kamera açısı uygun.');
    expect(viewData.visualState, SetupReadinessVisualState.ready);
    expect(viewData.isReady, isTrue);
    expect(
      viewData.checks.map((item) => item.state),
      everyElement(equals(SetupReadinessCheckState.complete)),
    );
  });

  test('treats a supported secondary view as usable without blocking', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: english,
      framingAssessment: _framing(SetupFramingStatus.ready),
      cameraViewAssessment: _cameraView(
        SetupCameraViewAdvisoryStatus.supported,
        detectedView: CameraView.front,
        recommendedView: CameraView.side,
      ),
    );

    expect(viewData.statusLabel, 'Ready');
    expect(viewData.message, contains('recommended view'));
    expect(viewData.isReady, isTrue);
    expect(
      _check(viewData, SetupReadinessCheckType.cameraView).state,
      SetupReadinessCheckState.complete,
    );
  });
}

SetupReadinessCheckItem _check(
  SetupReadinessViewData viewData,
  SetupReadinessCheckType type,
) {
  return viewData.checks.singleWhere((item) => item.type == type);
}

SetupFramingAssessment _framing(SetupFramingStatus status) {
  final personDetected = status != SetupFramingStatus.noPerson;
  final coverageVisible =
      status != SetupFramingStatus.noPerson &&
      status != SetupFramingStatus.incompleteCoverage;
  return SetupFramingAssessment(
    status: status,
    personDetected: personDetected,
    requiredLandmarksVisible: coverageVisible,
    visibleRequiredRegions: const {},
    missingRequiredRegions: const {},
    bodyBounds: null,
    horizontalCenterOffset: null,
    topMargin: null,
    bottomMargin: null,
    bodyScaleRatio: null,
    clippedEdges: const {},
    confidence: personDetected ? 0.9 : 0,
  );
}

SetupCameraViewAssessment _cameraView(
  SetupCameraViewAdvisoryStatus status, {
  CameraView? detectedView,
  CameraView? recommendedView,
}) {
  return SetupCameraViewAssessment(
    status: status,
    detectedView: detectedView,
    recommendedView: recommendedView,
    detectedViewSupport: switch (status) {
      SetupCameraViewAdvisoryStatus.preferred => CameraViewSupport.preferred,
      SetupCameraViewAdvisoryStatus.supported => CameraViewSupport.supported,
      SetupCameraViewAdvisoryStatus.unsupported =>
        CameraViewSupport.unsupported,
      SetupCameraViewAdvisoryStatus.insufficientEvidence ||
      SetupCameraViewAdvisoryStatus.indeterminate => null,
    },
    confidence: status == SetupCameraViewAdvisoryStatus.indeterminate
        ? 0.4
        : 0.9,
    frontScore: 0.2,
    sideScore: 0.8,
    completeBilateralPairCount: 2,
    evidenceLikelihood: 0.9,
    torsoLengthRatio: 0.3,
    averagePairWidthRatio: 0.2,
    averageDepthSeparationRatio: 0.4,
  );
}
