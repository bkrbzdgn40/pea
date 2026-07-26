import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_camera_view_orientation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_framing_geometry.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_start_pose.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/setup_readiness_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/setup_readiness_view_data.dart';

void main() {
  const turkish = AppLocalizations(Locale('tr'));
  const english = AppLocalizations(Locale('en'));

  test('prioritizes missing person over camera-view evidence', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.noPerson,
        framing: _framing(SetupFramingStatus.noPerson),
        cameraView: _cameraView(
          SetupCameraViewAdvisoryStatus.unsupported,
          recommendedView: CameraView.side,
        ),
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
      _check(viewData, SetupReadinessCheckType.startPose).state,
      SetupReadinessCheckState.pending,
    );
  });

  test('projects one actionable message for every framing problem', () {
    final expectations = <SetupReadinessPhase, String>{
      SetupReadinessPhase.incompleteCoverage:
          'Some required joints are not visible. Bring the requested body areas into the frame.',
      SetupReadinessPhase.clipped:
          'Part of your body is outside the frame. Move slightly farther back.',
      SetupReadinessPhase.tooNear:
          'You are too close to the camera. Move a little farther back.',
      SetupReadinessPhase.tooFar:
          'You are too far from the camera. Move a little closer.',
      SetupReadinessPhase.offCenter: 'Move toward the center of the frame.',
    };

    for (final entry in expectations.entries) {
      final viewData = mapSetupReadinessToViewData(
        localizations: english,
        readinessSnapshot: _snapshot(
          phase: entry.key,
          framing: _framing(_framingStatus(entry.key)),
          cameraView: _cameraView(
            SetupCameraViewAdvisoryStatus.unsupported,
            recommendedView: CameraView.side,
          ),
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

  test('asks for the recommended side view when front is unsupported', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.wrongView,
        framing: _framing(SetupFramingStatus.ready),
        cameraView: _cameraView(
          SetupCameraViewAdvisoryStatus.unsupported,
          detectedView: CameraView.front,
          recommendedView: CameraView.side,
        ),
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

  test('projects unmatched start pose without changing completed checks', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.startPoseMissing,
        framing: _framing(SetupFramingStatus.ready),
        cameraView: _cameraView(
          SetupCameraViewAdvisoryStatus.preferred,
          detectedView: CameraView.side,
          recommendedView: CameraView.side,
        ),
        startPose: _startPose(SetupStartPoseStatus.notMatched),
      ),
    );

    expect(
      viewData.message,
      'Hareketin başlangıç pozisyonunu al ve kısa süre sabit kal.',
    );
    expect(
      _check(viewData, SetupReadinessCheckType.framing).state,
      SetupReadinessCheckState.complete,
    );
    expect(
      _check(viewData, SetupReadinessCheckType.cameraView).state,
      SetupReadinessCheckState.complete,
    );
    expect(
      _check(viewData, SetupReadinessCheckType.startPose).state,
      SetupReadinessCheckState.needsAdjustment,
    );
  });

  test('shows stabilizing and temporary-loss states as checking', () {
    final evidence = _snapshot(
      phase: SetupReadinessPhase.stabilizing,
      framing: _framing(SetupFramingStatus.ready),
      cameraView: _cameraView(SetupCameraViewAdvisoryStatus.preferred),
      startPose: _startPose(SetupStartPoseStatus.matched),
    );
    final stabilizing = mapSetupReadinessToViewData(
      localizations: english,
      readinessSnapshot: evidence,
    );
    final temporarilyLost = mapSetupReadinessToViewData(
      localizations: english,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.temporarilyLost,
        framing: _framing(SetupFramingStatus.noPerson),
      ),
    );

    expect(stabilizing.statusLabel, 'Checking');
    expect(stabilizing.message, contains('Hold still briefly'));
    expect(stabilizing.isReady, isFalse);
    expect(temporarilyLost.statusLabel, 'Checking');
    expect(temporarilyLost.message, contains('reacquiring'));
  });

  test('marks only a stable ready snapshot as ready', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: turkish,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.ready,
        framing: _framing(SetupFramingStatus.ready),
        cameraView: _cameraView(
          SetupCameraViewAdvisoryStatus.preferred,
          detectedView: CameraView.side,
          recommendedView: CameraView.side,
        ),
        startPose: _startPose(SetupStartPoseStatus.matched),
      ),
    );

    expect(viewData.statusLabel, 'Hazır');
    expect(
      viewData.message,
      'Kadraj, kamera açısı ve başlangıç pozisyonu uygun.',
    );
    expect(viewData.visualState, SetupReadinessVisualState.ready);
    expect(viewData.isReady, isTrue);
    expect(
      viewData.checks.map((item) => item.state),
      everyElement(equals(SetupReadinessCheckState.complete)),
    );
  });

  test('keeps supported secondary view usable after stabilization', () {
    final viewData = mapSetupReadinessToViewData(
      localizations: english,
      readinessSnapshot: _snapshot(
        phase: SetupReadinessPhase.ready,
        framing: _framing(SetupFramingStatus.ready),
        cameraView: _cameraView(
          SetupCameraViewAdvisoryStatus.supported,
          detectedView: CameraView.front,
          recommendedView: CameraView.side,
        ),
        startPose: _startPose(SetupStartPoseStatus.matched),
      ),
    );

    expect(viewData.statusLabel, 'Ready');
    expect(viewData.message, contains('recommended view'));
    expect(viewData.isReady, isTrue);
  });
}

SetupReadinessCheckItem _check(
  SetupReadinessViewData viewData,
  SetupReadinessCheckType type,
) {
  return viewData.checks.singleWhere((item) => item.type == type);
}

SetupReadinessSnapshot _snapshot({
  required SetupReadinessPhase phase,
  SetupFramingAssessment? framing,
  SetupCameraViewAssessment? cameraView,
  SetupStartPoseAssessment? startPose,
}) {
  final now = DateTime.utc(2026, 7, 26);
  return SetupReadinessSnapshot(
    phase: phase,
    evidence: SetupReadinessEvidence(
      framingAssessment: framing,
      cameraViewAssessment: cameraView,
      startPoseAssessment: startPose,
    ),
    enteredAt: now,
    updatedAt: now,
    diagnostics: SetupReadinessDiagnosticsSnapshot(
      rawPhase: phase,
      framingStatus: framing?.status,
      cameraViewStatus: cameraView?.status,
      startPoseStatus: startPose?.status,
      stableEvidenceDuration: Duration.zero,
      temporaryLossDuration: Duration.zero,
      stabilityProgress: phase == SetupReadinessPhase.ready ? 1 : 0,
      confidence: 0.9,
    ),
  );
}

SetupFramingStatus _framingStatus(SetupReadinessPhase phase) {
  return switch (phase) {
    SetupReadinessPhase.incompleteCoverage =>
      SetupFramingStatus.incompleteCoverage,
    SetupReadinessPhase.clipped => SetupFramingStatus.clipped,
    SetupReadinessPhase.tooNear => SetupFramingStatus.tooNear,
    SetupReadinessPhase.tooFar => SetupFramingStatus.tooFar,
    SetupReadinessPhase.offCenter => SetupFramingStatus.offCenter,
    _ => SetupFramingStatus.ready,
  };
}

SetupFramingAssessment _framing(SetupFramingStatus status) {
  final personDetected = status != SetupFramingStatus.noPerson;
  final coverageVisible =
      personDetected && status != SetupFramingStatus.incompleteCoverage;
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

SetupStartPoseAssessment _startPose(SetupStartPoseStatus status) {
  final contract = SetupStartPoseContract(
    exerciseType: ExerciseType.squat,
    family: StartPoseFamily.standingNeutralSide,
    checks: const {SetupStartPoseCheck.uprightTorso},
  );
  final outcome = switch (status) {
    SetupStartPoseStatus.matched => SetupStartPoseCheckOutcome.passed,
    SetupStartPoseStatus.notMatched => SetupStartPoseCheckOutcome.failed,
    SetupStartPoseStatus.insufficientEvidence =>
      SetupStartPoseCheckOutcome.unavailable,
  };
  return SetupStartPoseAssessment(
    contract: contract,
    status: status,
    results: {
      SetupStartPoseCheck.uprightTorso: SetupStartPoseCheckResult(
        check: SetupStartPoseCheck.uprightTorso,
        outcome: outcome,
        confidence: 0.9,
      ),
    },
    confidence: 0.9,
  );
}
