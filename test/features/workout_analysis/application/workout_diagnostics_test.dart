import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';

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
    expect(snapshot.schemaVersion, 2);
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.elapsedMs, 0);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.frameProcessingMsP50, isNull);
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

  test('side assignment, repeat, null and real switches are distinguished', () {
    final subject = accumulator()
      ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: false)
      ..recordSelectedSide(selectedSide: 'left', hasActiveRepContext: true)
      ..recordSelectedSide(selectedSide: null, hasActiveRepContext: true);
    expect(subject.snapshot(now: startedAt).sideSwitchCount, 0);
    expect(subject.snapshot(now: startedAt).currentSelectedSide, isNull);

    subject.recordSelectedSide(
      selectedSide: 'right',
      hasActiveRepContext: false,
    );
    subject.recordSelectedSide(selectedSide: 'left', hasActiveRepContext: true);
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.sideSwitchCount, 1);
    expect(snapshot.activeRepSideSwitchCount, 1);
    expect(snapshot.currentSelectedSide, 'left');
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

  test('updates live performance and workout state', () {
    final subject = accumulator()
      ..updateLivePerformance(cameraFps: 30, analysisFps: 8)
      ..updateWorkoutState(
        repCount: 3,
        currentHoldSeconds: 4,
        bestHoldSeconds: 7,
        currentPhase: 'DESCENDING',
        isHolding: true,
        calibrationOffsetDegrees: 2.5,
      );
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.currentCameraFps, 30);
    expect(snapshot.currentAnalysisFps, 8);
    expect(snapshot.repCount, 3);
    expect(snapshot.currentHoldSeconds, 4);
    expect(snapshot.bestHoldSeconds, 7);
    expect(snapshot.currentPhase, 'DESCENDING');
    expect(snapshot.isHolding, isTrue);
    expect(snapshot.lastCalibrationOffsetDegrees, 2.5);
  });

  test('reset clears diagnostics and starts a new session', () {
    final resetAt = startedAt.add(const Duration(minutes: 1));
    final subject = accumulator()
      ..recordCameraFrame()
      ..recordPoseCount(3)
      ..recordProcessingDuration(const Duration(milliseconds: 20))
      ..updateWorkoutState(
        repCount: 2,
        currentHoldSeconds: 0,
        bestHoldSeconds: 0,
        currentPhase: 'PEAK',
        isHolding: false,
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
    expect(snapshot.repCount, isNull);
  });

  test('toJson is snake_case and excludes privacy-forbidden fields', () {
    final json = accumulator().snapshot(now: startedAt).toJson();
    expect(json['schema_version'], 2);
    expect(json['app_commit_sha'], 'abc123');
    expect(json['build_mode'], 'debug');
    expect(json['camera_frame_count'], 0);
    expect(json['accepted_pose_frame_count'], 0);
    expect(json['current_pose_quality_status'], 'stable');
    expect(json['is_holding'], isNull);
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
