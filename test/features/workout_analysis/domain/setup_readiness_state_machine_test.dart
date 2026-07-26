import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_camera_view_orientation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_framing_geometry.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_start_pose.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/setup_readiness_state_machine.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 26, 9);
  final thresholds = SetupReadinessThresholds(
    stableEvidenceDuration: Duration(seconds: 1),
    temporaryLossGraceDuration: Duration(milliseconds: 400),
    maximumEvidenceAge: Duration(milliseconds: 600),
  );

  test('requires continuous valid evidence before becoming ready', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);

    final first = machine.update(evidence: _validEvidence(), now: startedAt);
    final halfway = machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 500)),
    );
    final ready = machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(seconds: 1)),
    );

    expect(first.phase, SetupReadinessPhase.stabilizing);
    expect(first.diagnostics.stabilityProgress, 0);
    expect(halfway.phase, SetupReadinessPhase.stabilizing);
    expect(halfway.diagnostics.stabilityProgress, closeTo(0.5, 0.001));
    expect(ready.phase, SetupReadinessPhase.ready);
    expect(ready.isReady, isTrue);
    expect(ready.diagnostics.stabilityProgress, 1);
  });

  test('restores ready after a brief landmark loss', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 500)),
    );
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(seconds: 1)),
    );

    final lost = machine.update(
      evidence: _framingEvidence(SetupFramingStatus.noPerson),
      now: startedAt.add(const Duration(milliseconds: 1100)),
    );
    final recovered = machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 1350)),
    );

    expect(lost.phase, SetupReadinessPhase.temporarilyLost);
    expect(recovered.phase, SetupReadinessPhase.ready);
    expect(recovered.isReady, isTrue);
  });

  test('expires the temporary-loss grace window', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 500)),
    );
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(seconds: 1)),
    );
    machine.update(
      evidence: _framingEvidence(SetupFramingStatus.noPerson),
      now: startedAt.add(const Duration(milliseconds: 1100)),
    );

    final expired = machine.tick(
      now: startedAt.add(const Duration(milliseconds: 1500)),
    );

    expect(expired.phase, SetupReadinessPhase.noPerson);
    expect(expired.isReady, isFalse);
    expect(expired.diagnostics.temporaryLossDuration, Duration.zero);
  });

  test('does not hide conclusive framing changes behind the grace window', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 500)),
    );
    machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(seconds: 1)),
    );

    final tooNear = machine.update(
      evidence: _framingEvidence(SetupFramingStatus.tooNear),
      now: startedAt.add(const Duration(milliseconds: 1100)),
    );

    expect(tooNear.phase, SetupReadinessPhase.tooNear);
    expect(tooNear.isReady, isFalse);
  });

  test('maps unsupported camera view and unmatched start pose separately', () {
    final wrongViewMachine = SetupReadinessStateMachine(thresholds: thresholds)
      ..reset(now: startedAt);
    final wrongView = wrongViewMachine.update(
      evidence: _evidence(
        cameraStatus: SetupCameraViewAdvisoryStatus.unsupported,
      ),
      now: startedAt,
    );

    final startPoseMachine = SetupReadinessStateMachine(thresholds: thresholds)
      ..reset(now: startedAt);
    final startPose = startPoseMachine.update(
      evidence: _evidence(startPoseStatus: SetupStartPoseStatus.notMatched),
      now: startedAt,
    );

    expect(wrongView.phase, SetupReadinessPhase.wrongView);
    expect(startPose.phase, SetupReadinessPhase.startPoseMissing);
  });

  test('restarts stabilization after a conclusive adjustment', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);
    machine.update(
      evidence: _framingEvidence(SetupFramingStatus.offCenter),
      now: startedAt.add(const Duration(milliseconds: 600)),
    );

    final restarted = machine.update(
      evidence: _validEvidence(),
      now: startedAt.add(const Duration(milliseconds: 700)),
    );

    expect(restarted.phase, SetupReadinessPhase.stabilizing);
    expect(restarted.diagnostics.stabilityProgress, 0);
  });

  test('reports pending time-only transitions', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);

    expect(
      machine.nextTransitionDelay(
        now: startedAt.add(const Duration(milliseconds: 250)),
      ),
      const Duration(milliseconds: 350),
    );
  });

  test('treats stale valid evidence as a temporary loss', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);
    machine.update(evidence: _validEvidence(), now: startedAt);

    final stale = machine.tick(
      now: startedAt.add(const Duration(milliseconds: 600)),
    );

    expect(stale.phase, SetupReadinessPhase.temporarilyLost);
    expect(stale.diagnostics.rawPhase, SetupReadinessPhase.initializing);
  });

  test('surfaces explicit readiness errors', () {
    final machine = SetupReadinessStateMachine(thresholds: thresholds);
    machine.reset(now: startedAt);

    final snapshot = machine.update(
      evidence: const SetupReadinessEvidence(errorCode: 'camera-stream'),
      now: startedAt,
    );

    expect(snapshot.phase, SetupReadinessPhase.error);
    expect(snapshot.evidence.errorCode, 'camera-stream');
  });
}

SetupReadinessEvidence _validEvidence() => _evidence();

SetupReadinessEvidence _framingEvidence(SetupFramingStatus status) {
  return SetupReadinessEvidence(framingAssessment: _framing(status));
}

SetupReadinessEvidence _evidence({
  SetupFramingStatus framingStatus = SetupFramingStatus.ready,
  SetupCameraViewAdvisoryStatus cameraStatus =
      SetupCameraViewAdvisoryStatus.preferred,
  SetupStartPoseStatus startPoseStatus = SetupStartPoseStatus.matched,
}) {
  return SetupReadinessEvidence(
    framingAssessment: _framing(framingStatus),
    cameraViewAssessment: _cameraView(cameraStatus),
    startPoseAssessment: _startPose(startPoseStatus),
  );
}

SetupFramingAssessment _framing(SetupFramingStatus status) {
  final personDetected = status != SetupFramingStatus.noPerson;
  return SetupFramingAssessment(
    status: status,
    personDetected: personDetected,
    requiredLandmarksVisible:
        personDetected && status != SetupFramingStatus.incompleteCoverage,
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

SetupCameraViewAssessment _cameraView(SetupCameraViewAdvisoryStatus status) {
  return SetupCameraViewAssessment(
    status: status,
    detectedView: status == SetupCameraViewAdvisoryStatus.unsupported
        ? CameraView.front
        : CameraView.side,
    recommendedView: CameraView.side,
    detectedViewSupport: switch (status) {
      SetupCameraViewAdvisoryStatus.preferred => CameraViewSupport.preferred,
      SetupCameraViewAdvisoryStatus.supported => CameraViewSupport.supported,
      SetupCameraViewAdvisoryStatus.unsupported =>
        CameraViewSupport.unsupported,
      SetupCameraViewAdvisoryStatus.insufficientEvidence ||
      SetupCameraViewAdvisoryStatus.indeterminate => null,
    },
    confidence: 0.9,
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
