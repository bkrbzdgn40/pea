import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 12, 10);

  WorkoutDiagnosticsAccumulator accumulator() => WorkoutDiagnosticsAccumulator(
    sessionStartedAt: startedAt,
    analysisKind: 'rangeRep',
    appCommitSha: 'abc123',
    buildMode: 'debug',
  );

  test('initial snapshot is typed and empty', () {
    final snapshot = accumulator().snapshot(now: startedAt);
    expect(snapshot.schemaVersion, 3);
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.elapsedMs, 0);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.frameProcessingMsP50, isNull);
    expect(snapshot.rangeRepDiagnostics, isNull);
    expect(snapshot.holdDiagnostics, isNull);
    expect(snapshot.repCount, isNull);
    expect(snapshot.currentHoldSeconds, isNull);
    expect(snapshot.bestHoldSeconds, isNull);
    expect(snapshot.isHolding, isNull);
    expect(snapshot.presentedHoldFeedbackCode, isNull);
    expect(snapshot.engineHoldFeedbackCode, isNull);
    expect(snapshot.holdEnginePhase, isNull);
    expect(snapshot.currentHoldSide, isNull);
  });

  test(
    'records camera, analysis, throttle, reentrant and converter counts',
    () {
      final subject = accumulator()
        ..recordCameraFrame()
        ..recordAnalysisAttempt()
        ..recordAnalysisCompleted()
        ..recordThrottledFrame()
        ..recordReentrantDrop()
        ..recordConverterDrop();
      final snapshot = subject.snapshot(now: startedAt);
      expect(snapshot.cameraFrameCount, 1);
      expect(snapshot.analysisAttemptCount, 1);
      expect(snapshot.analysisCompletedCount, 1);
      expect(snapshot.throttledFrameCount, 1);
      expect(snapshot.reentrantDropCount, 1);
      expect(snapshot.converterDropCount, 1);
    },
  );

  test('records zero, one, multi pose and maximum count', () {
    final subject = accumulator()
      ..recordPoseCount(0)
      ..recordPoseCount(1)
      ..recordPoseCount(2)
      ..recordPoseCount(4);
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.noPoseFrameCount, 1);
    expect(snapshot.detectedPoseFrameCount, 3);
    expect(snapshot.multiPoseFrameCount, 2);
    expect(snapshot.maxPoseCount, 4);
    expect(() => subject.recordPoseCount(-1), throwsArgumentError);
  });

  test('records pose quality, rejection, and brief-occlusion telemetry', () {
    final subject = accumulator()
      ..recordAcceptedPoseFrame()
      ..recordRejectedPose(rejectionReasonCode: 'low_landmark_likelihood')
      ..recordLowConfidencePose()
      ..recordInvalidPoseGeometry()
      ..recordPoseReacquisition()
      ..recordBriefOcclusion()
      ..recordBriefOcclusionRecovery()
      ..recordBriefOcclusionAbort()
      ..updatePoseQualityStatus(
        status: 'rejected',
        lastRejectionReason: 'low_landmark_likelihood',
      )
      ..updateVisibilityStatus('brief_freeze');

    final snapshot = subject.snapshot(now: startedAt);

    expect(snapshot.acceptedPoseFrameCount, 1);
    expect(snapshot.rejectedPoseFrameCount, 1);
    expect(snapshot.lowConfidencePoseFrameCount, 1);
    expect(snapshot.invalidPoseGeometryFrameCount, 1);
    expect(snapshot.poseReacquisitionCount, 1);
    expect(snapshot.briefOcclusionCount, 1);
    expect(snapshot.briefOcclusionRecoveryCount, 1);
    expect(snapshot.briefOcclusionAbortCount, 1);
    expect(snapshot.lastPoseRejectionReason, 'low_landmark_likelihood');
    expect(snapshot.currentPoseQualityStatus, 'rejected');
    expect(snapshot.currentVisibilityStatus, 'brief_freeze');
  });

  test('records exception and resync separately', () {
    final subject = accumulator()
      ..recordAnalysisException()
      ..recordResync();
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.analysisExceptionCount, 1);
    expect(snapshot.resyncCount, 1);
  });

  test(
    'range-rep diagnostics keep side assignment semantics inside range-rep payload',
    () {
      final subject = accumulator()
        ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: false)
        ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: true)
        ..recordSelectedSide(selectedSide: null, hasActiveRepContext: true)
        ..recordSelectedSide(selectedSide: 'right', hasActiveRepContext: false)
        ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: true)
        ..updateRangeRepState(
          repCount: 3,
          currentPhase: 'ASCENDING',
          calibrationOffsetDegrees: 2.5,
        );

      final snapshot = subject.snapshot(now: startedAt);
      expect(snapshot.rangeRepDiagnostics, isNotNull);
      expect(snapshot.holdDiagnostics, isNull);
      expect(snapshot.sideSwitchCount, 1);
      expect(snapshot.activeRepSideSwitchCount, 1);
      expect(snapshot.currentSelectedSide, 'left');
      expect(snapshot.repCount, 3);
      expect(snapshot.currentHoldSeconds, 0);
      expect(snapshot.bestHoldSeconds, 0);
      expect(snapshot.currentPhase, 'ASCENDING');
      expect(snapshot.isHolding, isFalse);
      expect(snapshot.lastCalibrationOffsetDegrees, 2.5);
      final json = snapshot.toJson();
      expect(json['schema_version'], 3);
      expect(json['rep_count'], 3);
      expect(json['current_hold_seconds'], 0);
      expect(json['best_hold_seconds'], 0);
      expect(json['is_holding'], isFalse);
      expect(json['current_phase'], 'ASCENDING');
      expect(json['current_selected_side'], 'left');
      expect(json['last_calibration_offset_degrees'], 2.5);
      expect(json['presented_hold_feedback_code'], isNull);
      expect(json['engine_hold_feedback_code'], isNull);
    },
  );

  test('hold diagnostics stay hold-owned and clear range-rep live payload', () {
    final holdDiagnostics = HoldDiagnosticsSnapshot(
      phase: HoldPhase.holding,
      feedbackCode: HoldFeedbackCode.holdPosition,
      lastVisiblePosture: HoldPostureDiagnosticsSnapshot(
        hasCompleteMetrics: true,
        hasActivePosture: true,
        signalValidity: HoldSignalValidity(
          values: <HoldSignal, bool>{
            HoldSignal.alignment: true,
            HoldSignal.support: true,
            HoldSignal.extension: true,
          },
        ),
      ),
      isFormBreakGraceActive: false,
      isVisibilitySuspended: false,
    );
    final subject = accumulator()
      ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: true)
      ..updateRangeRepState(repCount: 2, currentPhase: 'PEAK')
      ..updateLivePerformance(cameraFps: 30, analysisFps: 8)
      ..updateHoldState(
        currentHoldSeconds: 4,
        bestHoldSeconds: 7,
        currentPhase: 'HOLDING',
        isHolding: true,
        presentedHoldFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        holdDiagnostics: holdDiagnostics,
        currentHoldSide: HoldSide.right,
      );
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.currentCameraFps, 30);
    expect(snapshot.currentAnalysisFps, 8);
    expect(snapshot.rangeRepDiagnostics, isNull);
    expect(snapshot.holdDiagnostics, isNotNull);
    expect(snapshot.sideSwitchCount, 0);
    expect(snapshot.currentSelectedSide, isNull);
    expect(snapshot.repCount, 0);
    expect(snapshot.currentHoldSeconds, 4);
    expect(snapshot.bestHoldSeconds, 7);
    expect(snapshot.currentPhase, 'HOLDING');
    expect(snapshot.isHolding, isTrue);
    expect(snapshot.presentedHoldFeedbackCode, HoldFeedbackCode.bodyNotVisible);
    expect(snapshot.engineHoldFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(snapshot.holdEnginePhase, HoldPhase.holding);
    expect(snapshot.currentHoldSide, HoldSide.right);
    expect(snapshot.lastVisibleHoldPosture?.hasCompleteMetrics, isTrue);
    expect(snapshot.lastVisibleHoldPosture?.hasActivePosture, isTrue);
    expect(snapshot.lastVisibleHoldPosture?.isBodyAligned, isTrue);
    expect(snapshot.lastVisibleHoldPosture?.isArmSupported, isTrue);
    expect(snapshot.lastVisibleHoldPosture?.areLegsExtended, isTrue);
    expect(snapshot.isHoldFormBreakGraceActive, isFalse);
    expect(snapshot.isHoldVisibilitySuspended, isFalse);
    final json = snapshot.toJson();
    expect(json['schema_version'], 3);
    expect(json['rep_count'], 0);
    expect(json['current_hold_seconds'], 4);
    expect(json['best_hold_seconds'], 7);
    expect(json['current_phase'], 'HOLDING');
    expect(json['is_holding'], isTrue);
    expect(
      json['presented_hold_feedback_code'],
      HoldFeedbackCode.bodyNotVisible.code,
    );
    expect(
      json['engine_hold_feedback_code'],
      HoldFeedbackCode.holdPosition.code,
    );
    expect(json['hold_engine_phase'], HoldPhase.holding.code);
    expect(json['current_hold_side'], 'right');
    expect(json['current_selected_side'], isNull);
  });

  test('processing duration uses deterministic nearest-rank percentiles', () {
    final subject = accumulator();
    for (final ms in <int>[10, 20, 30, 40, 100]) {
      subject.recordProcessingDuration(Duration(milliseconds: ms));
    }
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.frameProcessingMsP50, 30);
    expect(snapshot.frameProcessingMsP95, 100);
    expect(snapshot.frameProcessingMsMax, 100);
    expect(
      () => subject.recordProcessingDuration(const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });

  test('processing duration keeps the newest 10000 samples', () {
    final subject = accumulator();
    for (var index = 0; index <= 10000; index++) {
      subject.recordProcessingDuration(Duration(milliseconds: index));
    }
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.frameProcessingMsP50, 5000);
    expect(snapshot.frameProcessingMsP95, 9500);
    expect(snapshot.frameProcessingMsMax, 10000);
  });

  test('reset clears diagnostics and starts a new session', () {
    final resetAt = startedAt.add(const Duration(minutes: 1));
    final subject = accumulator()
      ..recordCameraFrame()
      ..recordPoseCount(3)
      ..recordProcessingDuration(const Duration(milliseconds: 20))
      ..updateHoldState(
        currentHoldSeconds: 5,
        bestHoldSeconds: 5,
        currentPhase: 'HOLDING',
        isHolding: true,
        presentedHoldFeedbackCode: HoldFeedbackCode.preparePosition,
        holdDiagnostics: HoldDiagnosticsSnapshot(
          phase: HoldPhase.ready,
          feedbackCode: HoldFeedbackCode.preparePosition,
          lastVisiblePosture: HoldPostureDiagnosticsSnapshot(
            hasCompleteMetrics: true,
          ),
        ),
        currentHoldSide: HoldSide.left,
      )
      ..reset(now: resetAt, analysisKind: 'hold');
    final snapshot = subject.snapshot(
      now: resetAt.add(const Duration(seconds: 1)),
    );
    expect(snapshot.sessionStartedAt, resetAt);
    expect(snapshot.analysisKind, 'hold');
    expect(snapshot.elapsedMs, 1000);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.multiPoseFrameCount, 0);
    expect(snapshot.frameProcessingMsP50, isNull);
    expect(snapshot.rangeRepDiagnostics, isNull);
    expect(snapshot.holdDiagnostics, isNull);
    expect(snapshot.repCount, isNull);
    expect(snapshot.presentedHoldFeedbackCode, isNull);
    expect(snapshot.engineHoldFeedbackCode, isNull);
    expect(snapshot.holdEnginePhase, isNull);
    expect(snapshot.currentHoldSide, isNull);
    expect(snapshot.lastVisibleHoldPosture, isNull);
  });

  test('toJson is snake_case and preserves the existing key contract', () {
    final json = accumulator().snapshot(now: startedAt).toJson();
    expect(json['schema_version'], 3);
    expect(json['app_commit_sha'], 'abc123');
    expect(json['build_mode'], 'debug');
    expect(json['camera_frame_count'], 0);
    expect(json['accepted_pose_frame_count'], 0);
    expect(json['current_pose_quality_status'], 'stable');
    expect(json['side_switch_count'], 0);
    expect(json['active_rep_side_switch_count'], 0);
    expect(json['rep_count'], isNull);
    expect(json['current_hold_seconds'], isNull);
    expect(json['best_hold_seconds'], isNull);
    expect(json['is_holding'], isNull);
    expect(json['presented_hold_feedback_code'], isNull);
    expect(json['engine_hold_feedback_code'], isNull);
    expect(json['hold_engine_phase'], isNull);
    expect(json['current_hold_side'], isNull);
    expect(json['hold_has_complete_metrics'], isNull);
    expect(json['hold_has_active_posture'], isNull);
    expect(json['hold_is_body_aligned'], isNull);
    expect(json['hold_is_arm_supported'], isNull);
    expect(json['hold_are_legs_extended'], isNull);
    expect(json['hold_is_form_break_grace_active'], isNull);
    expect(json['hold_is_visibility_suspended'], isNull);
    expect(() => jsonEncode(json), returnsNormally);
    expect(
      json.keys,
      isNot(
        containsAll(<String>[
          'frame_bytes',
          'landmarks',
          'firebase_uid',
          'email',
          'session_id',
          'exception_message',
          'stack_trace',
        ]),
      ),
    );
    expect(json.keys.every((key) => !RegExp('[A-Z]').hasMatch(key)), isTrue);
  });
}
