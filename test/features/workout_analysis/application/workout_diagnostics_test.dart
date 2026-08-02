import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 12, 10);
  final sideViewContract = CameraViewContract(
    views: const <CameraView, CameraViewSupport>{
      CameraView.side: CameraViewSupport.preferred,
      CameraView.front: CameraViewSupport.unsupported,
    },
  );
  final frontViewContract = CameraViewContract(
    views: const <CameraView, CameraViewSupport>{
      CameraView.side: CameraViewSupport.unsupported,
      CameraView.front: CameraViewSupport.preferred,
    },
  );

  WorkoutDiagnosticsAccumulator accumulator({
    CameraViewContract? cameraViewContract,
  }) => WorkoutDiagnosticsAccumulator(
    sessionStartedAt: startedAt,
    analysisKind: 'rangeRep',
    exerciseType: 'squat',
    configAssetPath: 'assets/config/exercises/squat.json',
    cameraViewContract: cameraViewContract ?? sideViewContract,
    rangeRepContract: RangeRepContracts.squat,
    appCommitSha: 'abc123',
    buildMode: 'debug',
  );

  test('initial snapshot is typed and empty', () {
    final snapshot = accumulator().snapshot(now: startedAt);
    expect(snapshot.schemaVersion, 12);
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.elapsedMs, 0);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisTimeoutCount, 0);
    expect(snapshot.fpsSampleCount, 0);
    expect(snapshot.cameraFpsP50, isNull);
    expect(snapshot.cameraFpsP95, isNull);
    expect(snapshot.analysisFpsP50, isNull);
    expect(snapshot.analysisFpsP95, isNull);
    expect(snapshot.frameProcessingMsP50, isNull);
    expect(snapshot.framePosePipelineTimings.conversion.sampleCount, 0);
    expect(snapshot.framePosePipelineTimings.poseDetection.sampleCount, 0);
    expect(
      snapshot.framePosePipelineTimings.candidateEvaluation.sampleCount,
      0,
    );
    expect(snapshot.framePosePipelineTimings.total.sampleCount, 0);
    expect(snapshot.currentLeftMeasurementConfidence, isNull);
    expect(snapshot.currentRightMeasurementConfidence, isNull);
    expect(snapshot.lastRepMeasurementConfidence, isNull);
    expect(snapshot.measurementConfidenceKnownRepCount, 0);
    expect(snapshot.measurementConfidenceUnknownRepCount, 0);
    expect(snapshot.measurementConfidenceIssueCounts, isEmpty);
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
    expect(snapshot.holdCurrentSignalValues.asMap(), isEmpty);
    expect(snapshot.holdTargetSignalValues.asMap(), isEmpty);
    expect(snapshot.holdSignalValidity.asMap(), isEmpty);
    expect(snapshot.cameraViewContract, same(sideViewContract));
  });

  test('analysis timeout count is exported separately from exceptions', () {
    final subject = accumulator()
      ..recordAnalysisException()
      ..recordAnalysisTimeout();

    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.analysisExceptionCount, 1);
    expect(snapshot.analysisTimeoutCount, 1);
    expect(snapshot.toJson()['analysis_timeout_count'], 1);
  });

  test('confidence v2 diagnostics serialize current and last breakdowns', () {
    final left = MeasurementConfidenceBreakdown(
      landmarkLikelihood: 0.91,
      signalAvailability: 0.75,
      geometryPlausibility: 1.0,
      temporalContinuity: null,
      combined: null,
      issues: const <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.temporalHistoryUnavailable,
      ],
    );
    final right = MeasurementConfidenceBreakdown(
      landmarkLikelihood: 0.98,
      signalAvailability: 1.0,
      geometryPlausibility: 1.0,
      temporalContinuity: 0.94,
      combined: 0.975,
      issues: const <MeasurementConfidenceIssue>[],
    );
    final subject = accumulator()
      ..updateRangeRepState(
        repCount: 0,
        currentPhase: 'WAITING',
        signalRoles: RangeRepContracts.squat.signalRoles,
        currentLeftMeasurementConfidence: left,
        currentRightMeasurementConfidence: right,
      )
      ..recordRangeRepValidation(
        statusCode: 'valid',
        reasonCodes: const <String>[],
        measurementConfidence: right,
      )
      ..recordRangeRepValidation(
        statusCode: 'invalid',
        reasonCodes: const <String>['coverageLoss'],
        measurementConfidence: left,
      );

    final snapshot = subject.snapshot(now: startedAt);
    final json = snapshot.toJson();
    expect(snapshot.currentLeftMeasurementConfidence, same(left));
    expect(snapshot.currentRightMeasurementConfidence, same(right));
    expect(snapshot.lastRepMeasurementConfidence, same(left));
    expect(snapshot.measurementConfidenceKnownRepCount, 1);
    expect(snapshot.measurementConfidenceUnknownRepCount, 1);
    expect(snapshot.measurementConfidenceIssueCounts, <String, int>{
      'temporal_history_unavailable': 1,
    });
    expect(snapshot.leftRangeRepSideConfidence, isNull);
    expect(snapshot.rightRangeRepSideConfidence, right.combined);

    expect(json['current_left_measurement_confidence'], <String, Object?>{
      'landmark_likelihood': 0.91,
      'signal_availability': 0.75,
      'geometry_plausibility': 1.0,
      'temporal_continuity': null,
      'combined': null,
      'issues': <String>['temporal_history_unavailable'],
    });
    expect(json['current_right_measurement_confidence'], <String, Object?>{
      'landmark_likelihood': 0.98,
      'signal_availability': 1.0,
      'geometry_plausibility': 1.0,
      'temporal_continuity': 0.94,
      'combined': 0.975,
      'issues': <String>[],
    });
    expect(
      json['last_rep_measurement_confidence'],
      json['current_left_measurement_confidence'],
    );
    expect(json['measurement_confidence_known_rep_count'], 1);
    expect(json['measurement_confidence_unknown_rep_count'], 1);
    expect(json['measurement_confidence_issue_counts'], <String, int>{
      'temporal_history_unavailable': 1,
    });
    expect(json['left_range_rep_side_confidence'], isNull);
    expect(json['right_range_rep_side_confidence'], right.combined);
  });

  test('camera-view metadata serializes in enum order per active contract', () {
    final sideSnapshot = accumulator().snapshot(now: startedAt);
    final frontSnapshot = accumulator(
      cameraViewContract: frontViewContract,
    ).snapshot(now: startedAt);

    expect(sideSnapshot.cameraViewContract, same(sideViewContract));
    expect(frontSnapshot.cameraViewContract, same(frontViewContract));
    expect(sideSnapshot.toJson()['camera_view_contract'], <String, String>{
      'side': 'preferred',
      'front': 'unsupported',
    });

    final serialized =
        frontSnapshot.toJson()['camera_view_contract']! as Map<String, String>;
    expect(serialized.keys.toList(), <String>['side', 'front']);
    expect(serialized, <String, String>{
      'side': 'unsupported',
      'front': 'preferred',
    });
  });

  test('schema v12 identifies the exact exercise and contract context', () {
    final snapshot = accumulator().snapshot(now: startedAt);
    final json = snapshot.toJson();

    expect(snapshot.schemaVersion, 12);
    expect(snapshot.exerciseType, 'squat');
    expect(snapshot.configAssetPath, 'assets/config/exercises/squat.json');
    expect(
      snapshot.configVersionFingerprint,
      'assets/config/exercises/squat.json@abc123',
    );
    expect(snapshot.contractProfile, 'rangeRep:squat');
    expect(snapshot.rangeRepSideMode, 'selectedSide');
    expect(snapshot.rangeRepPrimaryMetricKind, 'jointAngle');
    expect(snapshot.rangeRepPrimaryMetricDirection, 'decreasingToPeak');
    expect(snapshot.holdAnalysisFamily, isNull);
    expect(snapshot.holdVariation, isNull);
    expect(json['exercise_type'], 'squat');
    expect(json['contract_profile'], 'rangeRep:squat');
  });

  test('schema v12 identifies hold family and hollow-hold variation', () {
    final subject = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: startedAt,
      analysisKind: 'hold',
      exerciseType: 'hollow_hold',
      configAssetPath: 'assets/config/exercises/hollow_hold.json',
      cameraViewContract: sideViewContract,
      holdContract: HoldContracts.hollowHold,
      appCommitSha: 'abc123',
      buildMode: 'debug',
    );

    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.contractProfile, 'hold:hollowHold');
    expect(snapshot.holdAnalysisFamily, 'hollowHold');
    expect(snapshot.holdVariation, 'straightLegOverhead');
    expect(snapshot.rangeRepSideMode, isNull);
    expect(snapshot.rangeRepPrimaryMetricDirection, isNull);
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
      ..recordRejectedPose(rejectionReasonCode: 'low_landmark_likelihood')
      ..recordRejectedPose(rejectionReasonCode: 'degenerate_geometry')
      ..recordPoseQualitySample(
        minimumRequiredLikelihood: 0.51,
        meanRequiredLikelihood: 0.70,
        qualityScore: 0.61,
      )
      ..recordPoseQualitySample(
        minimumRequiredLikelihood: 0.80,
        meanRequiredLikelihood: 0.90,
        qualityScore: 0.85,
      )
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
    expect(snapshot.rejectedPoseFrameCount, 3);
    expect(snapshot.lowConfidencePoseFrameCount, 1);
    expect(snapshot.invalidPoseGeometryFrameCount, 1);
    expect(snapshot.poseReacquisitionCount, 1);
    expect(snapshot.briefOcclusionCount, 1);
    expect(snapshot.briefOcclusionRecoveryCount, 1);
    expect(snapshot.briefOcclusionAbortCount, 1);
    expect(snapshot.lastPoseRejectionReason, 'low_landmark_likelihood');
    expect(snapshot.poseRejectionReasonCounts, <String, int>{
      'low_landmark_likelihood': 2,
      'degenerate_geometry': 1,
    });
    expect(snapshot.poseQualitySampleCount, 2);
    expect(snapshot.minimumRequiredLikelihoodP05, 0.51);
    expect(snapshot.minimumRequiredLikelihoodP50, 0.51);
    expect(snapshot.meanRequiredLikelihoodP05, 0.70);
    expect(snapshot.meanRequiredLikelihoodP50, 0.70);
    expect(snapshot.poseQualityScoreP50, 0.61);
    expect(snapshot.poseQualityScoreP95, 0.85);
    expect(snapshot.currentPoseQualityStatus, 'rejected');
    expect(snapshot.currentVisibilityStatus, 'brief_freeze');
  });

  test(
    'records hold visibility lifecycle telemetry with completed gap time',
    () {
      final subject = WorkoutDiagnosticsAccumulator(
        sessionStartedAt: startedAt,
        analysisKind: 'hold',
        exerciseType: 'plank',
        configAssetPath: 'assets/config/exercises/plank.json',
        cameraViewContract: sideViewContract,
        holdContract: HoldContracts.plankFamily,
        appCommitSha: 'abc123',
        buildMode: 'debug',
      )..recordHoldVisibilitySuspend();

      final openGapSnapshot = subject.snapshot(now: startedAt);
      expect(openGapSnapshot.holdVisibilitySuspendCount, 1);
      expect(openGapSnapshot.holdVisibilitySuspendedMsTotal, 0);
      expect(openGapSnapshot.lastHoldVisibilityGapMs, isNull);

      subject
        ..recordHoldVisibilityRecovery(const Duration(milliseconds: 400))
        ..recordHoldVisibilitySuspend()
        ..recordHoldVisibilityAbort(const Duration(milliseconds: 1500));

      final snapshot = subject.snapshot(now: startedAt);
      final json = snapshot.toJson();

      expect(snapshot.holdVisibilitySuspendCount, 2);
      expect(snapshot.holdVisibilityRecoveryCount, 1);
      expect(snapshot.holdVisibilityAbortCount, 1);
      expect(snapshot.holdVisibilitySuspendedMsTotal, 1900);
      expect(snapshot.lastHoldVisibilityGapMs, 1500);
      expect(json['hold_visibility_suspend_count'], 2);
      expect(json['hold_visibility_recovery_count'], 1);
      expect(json['hold_visibility_abort_count'], 1);
      expect(json['hold_visibility_suspended_ms_total'], 1900);
      expect(json['last_hold_visibility_gap_ms'], 1500);
      expect(
        () =>
            subject.recordHoldVisibilityAbort(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    },
  );

  test('records exception and resync separately', () {
    final subject = accumulator()
      ..recordAnalysisException()
      ..recordResync()
      ..recordResync(hadActiveRepContext: true);
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.analysisExceptionCount, 1);
    expect(snapshot.resyncCount, 2);
    expect(snapshot.activeRepResyncCount, 1);
  });

  test('records range-rep transitions, aborts, and validation reasons', () {
    final subject = accumulator()
      ..recordRangeRepTransition('acquireNeutral')
      ..recordRangeRepTransition('startDescending')
      ..recordRangeRepTransition('abortToNeutral')
      ..recordRangeRepValidation(
        statusCode: 'invalid',
        reasonCodes: const <String>['insufficientRom', 'coverageLoss'],
      )
      ..recordRangeRepValidation(
        statusCode: 'valid',
        reasonCodes: const <String>[],
        tempoDiagnosticReasonCodes: const <String>['excessiveDescentSpeed'],
      );

    final snapshot = subject.snapshot(now: startedAt);
    final json = snapshot.toJson();

    expect(snapshot.rangeRepTransitionCount, 3);
    expect(snapshot.rangeRepAbortCount, 1);
    expect(snapshot.rangeRepTransitionCounts, <String, int>{
      'acquireNeutral': 1,
      'startDescending': 1,
      'abortToNeutral': 1,
    });
    expect(snapshot.rangeRepValidationCount, 2);
    expect(snapshot.rangeRepValidationStatusCounts, <String, int>{
      'invalid': 1,
      'valid': 1,
    });
    expect(snapshot.rangeRepValidationReasonCounts, <String, int>{
      'insufficientRom': 1,
      'coverageLoss': 1,
    });
    expect(snapshot.lastRangeRepConfirmedTransition, 'abortToNeutral');
    expect(snapshot.lastRangeRepValidationStatus, 'valid');
    expect(snapshot.lastRangeRepValidationReasons, isEmpty);
    expect(snapshot.rangeRepTempoDiagnosticReasonCounts, <String, int>{
      'excessiveDescentSpeed': 1,
    });
    expect(snapshot.lastRangeRepTempoDiagnosticReasons, <String>[
      'excessiveDescentSpeed',
    ]);
    expect(json['range_rep_tempo_diagnostic_reason_counts'], <String, int>{
      'excessiveDescentSpeed': 1,
    });
    expect(json['last_range_rep_tempo_diagnostic_reasons'], <String>[
      'excessiveDescentSpeed',
    ]);
    expect(json['range_rep_abort_count'], 1);
  });

  test(
    'records actual camera runtime context separately from camera contract',
    () {
      final subject = accumulator()
        ..updateCameraRuntimeContext(
          sensorOrientationDegrees: 90,
          cameraLensDirection: 'front',
          deviceOrientation: 'landscapeLeft',
        );

      final snapshot = subject.snapshot(now: startedAt);
      expect(snapshot.cameraLensDirection, 'front');
      expect(snapshot.sensorOrientationDegrees, 90);
      expect(snapshot.deviceOrientation, 'landscapeLeft');
      expect(snapshot.toJson()['camera_lens_direction'], 'front');
    },
  );

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
          signalRoles: RangeRepContracts.squat.signalRoles,
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
      expect(json['schema_version'], 12);
      expect(json['rep_count'], 3);
      expect(json['current_hold_seconds'], 0);
      expect(json['best_hold_seconds'], 0);
      expect(json['is_holding'], isFalse);
      expect(json['current_phase'], 'ASCENDING');
      expect(json['current_selected_side'], 'left');
      expect(json['last_calibration_offset_degrees'], 2.5);
      expect(json['presented_hold_feedback_code'], isNull);
      expect(json['engine_hold_feedback_code'], isNull);
      expect(json['hold_current_signals'], isNull);
      expect(json['hold_target_signals'], isNull);
      expect(json['hold_signal_validity'], isNull);
    },
  );

  test(
    'range-rep timing trace serializes observation and confirmation facts',
    () {
      final firstObservedAt = startedAt.add(const Duration(milliseconds: 200));
      final lastObservedAt = startedAt.add(const Duration(milliseconds: 820));
      final trace = RangeRepTimingTraceSnapshot(
        outcome: RangeRepTimingTraceOutcome.completed,
        sampleCount: 7,
        towardPeakSampleCount: 3,
        peakSampleCount: 1,
        returnSampleCount: 3,
        directionChangeCount: 2,
        intervalSampleCount: 6,
        averageObservationIntervalMs: 103.3,
        maxObservationIntervalMs: 120,
        lastProcessingLagMs: 340,
        maxProcessingLagMs: 680,
        firstObservedAt: firstObservedAt,
        lastObservedAt: lastObservedAt,
        firstPrimaryMetric: 140,
        lastPrimaryMetric: 170,
        minPrimaryMetric: 90,
        maxPrimaryMetric: 170,
        hadVisibilityGap: true,
        transitions: <RangeRepTimingTransitionTrace>[
          RangeRepTimingTransitionTrace(
            type: 'startTowardPeak',
            effectiveAt: firstObservedAt,
            confirmedAt: firstObservedAt.add(const Duration(milliseconds: 100)),
          ),
        ],
      );
      final subject = accumulator()
        ..updateRangeRepState(
          repCount: 1,
          currentPhase: 'NEUTRAL',
          signalRoles: RangeRepContracts.squat.signalRoles,
          lastEndedTimingTrace: trace,
          lastTempoMeasurementAssessment: TempoMeasurementAssessment(
            status: TempoMeasurementStatus.unavailable,
            issues: const <TempoMeasurementIssue>[
              TempoMeasurementIssue.visibilityInterrupted,
            ],
            measuredTempo: const TempoRepResult(
              repIndex: 1,
              eccentricDuration: Duration(milliseconds: 300),
              bottomPauseDuration: Duration(milliseconds: 100),
              concentricDuration: Duration(milliseconds: 400),
              topPauseDuration: Duration.zero,
              totalRepDuration: Duration(milliseconds: 800),
              towardPeakDuration: Duration(milliseconds: 300),
              returnDuration: Duration(milliseconds: 400),
            ),
            trace: trace,
          ),
          nonMonotonicObservationCount: 2,
        );

      final snapshot = subject.snapshot(now: startedAt);
      final json = snapshot.toJson();
      final serializedTrace =
          json['range_rep_last_ended_timing_trace']! as Map<String, Object?>;

      expect(snapshot.lastEndedRangeRepTimingTrace, same(trace));
      expect(snapshot.activeRangeRepTimingTrace, isNull);
      expect(snapshot.nonMonotonicRangeRepObservationCount, 2);
      expect(serializedTrace['outcome'], 'completed');
      expect(serializedTrace['sample_count'], 7);
      expect(serializedTrace['average_observation_interval_ms'], 103.3);
      expect(serializedTrace['max_processing_lag_ms'], 680);
      expect(serializedTrace['had_visibility_gap'], isTrue);
      expect(serializedTrace['used_sparse_cycle_recovery'], isFalse);
      final assessmentJson =
          json['range_rep_last_tempo_measurement_assessment']!
              as Map<String, Object?>;
      expect(assessmentJson['status'], 'unavailable');
      expect(assessmentJson['issues'], <String>['visibilityInterrupted']);
      expect(
        (serializedTrace['transitions']! as List<Object?>).single,
        <String, Object?>{
          'type': 'startTowardPeak',
          'effective_at': firstObservedAt.toIso8601String(),
          'confirmed_at': firstObservedAt
              .add(const Duration(milliseconds: 100))
              .toIso8601String(),
          'confirmation_lag_ms': 100,
        },
      );
      expect(json['range_rep_non_monotonic_observation_count'], 2);
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
      ..updateRangeRepState(
        repCount: 2,
        currentPhase: 'PEAK',
        signalRoles: RangeRepContracts.squat.signalRoles,
      )
      ..updateLivePerformance(cameraFps: 30, analysisFps: 8)
      ..updateHoldState(
        currentHoldSeconds: 4,
        bestHoldSeconds: 7,
        currentPhase: 'HOLDING',
        isHolding: true,
        signalRoles: HoldContracts.plankFamily.signalRoles,
        presentedHoldFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        holdDiagnostics: holdDiagnostics,
        currentHoldSide: HoldSide.right,
        currentSignalValues: HoldSignalValues(
          values: <HoldSignal, double>{
            HoldSignal.alignment: 168.0,
            HoldSignal.support: 90.0,
            HoldSignal.extension: 170.0,
          },
        ),
      );
    final snapshot = subject.snapshot(now: startedAt);
    expect(snapshot.currentCameraFps, 30);
    expect(snapshot.currentAnalysisFps, 8);
    expect(snapshot.fpsSampleCount, 0);
    expect(snapshot.cameraFpsP50, isNull);
    expect(snapshot.analysisFpsP50, isNull);
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
    expect(snapshot.holdCurrentSignalValues.asMap(), <HoldSignal, double>{
      HoldSignal.alignment: 168.0,
      HoldSignal.support: 90.0,
      HoldSignal.extension: 170.0,
    });
    expect(snapshot.holdTargetSignalValues.asMap(), <HoldSignal, double>{});
    expect(snapshot.holdSignalValidity.asMap(), <HoldSignal, bool>{
      HoldSignal.alignment: true,
      HoldSignal.support: true,
      HoldSignal.extension: true,
    });
    final json = snapshot.toJson();
    expect(json['schema_version'], 12);
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
    expect(json['hold_current_signals'], <String, double>{
      'alignment': 168.0,
      'support': 90.0,
      'extension': 170.0,
    });
    expect(json['hold_target_signals'], isNull);
    expect(json['hold_signal_validity'], <String, bool>{
      'alignment': true,
      'support': true,
      'extension': true,
    });
  });

  test(
    'hollow hold diagnostics serialize generic signal maps without fake plank booleans',
    () {
      final holdDiagnostics = HoldDiagnosticsSnapshot(
        phase: HoldPhase.holding,
        feedbackCode: HoldFeedbackCode.holdPosition,
        targetSignalValues: HoldSignalValues(
          values: <HoldSignal, double>{
            HoldSignal.compression: 169.0,
            HoldSignal.armExtension: 135.0,
            HoldSignal.kneeExtension: 165.0,
          },
        ),
        lastVisiblePosture: HoldPostureDiagnosticsSnapshot(
          hasCompleteMetrics: true,
          hasActivePosture: true,
          signalValidity: HoldSignalValidity(
            values: <HoldSignal, bool>{
              HoldSignal.compression: true,
              HoldSignal.armExtension: true,
              HoldSignal.kneeExtension: true,
            },
          ),
        ),
      );
      final subject = accumulator()
        ..updateHoldState(
          currentHoldSeconds: 5,
          bestHoldSeconds: 8,
          currentPhase: 'HOLDING',
          isHolding: true,
          signalRoles: HoldContracts.hollowHold.signalRoles,
          presentedHoldFeedbackCode: HoldFeedbackCode.holdPosition,
          holdDiagnostics: holdDiagnostics,
          currentHoldSide: HoldSide.left,
          currentSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.compression: 164.3,
              HoldSignal.armExtension: 136.3,
              HoldSignal.kneeExtension: 173.0,
            },
          ),
        );

      final json = subject.snapshot(now: startedAt).toJson();

      expect(json['hold_current_signals'], <String, double>{
        'compression': 164.3,
        'armExtension': 136.3,
        'kneeExtension': 173.0,
      });
      expect(json['hold_target_signals'], <String, double>{
        'compression': 169.0,
        'armExtension': 135.0,
        'kneeExtension': 165.0,
      });
      expect(json['hold_signal_validity'], <String, bool>{
        'compression': true,
        'armExtension': true,
        'kneeExtension': true,
      });
      expect(json['hold_is_body_aligned'], isNull);
      expect(json['hold_is_arm_supported'], isNull);
      expect(json['hold_are_legs_extended'], isNull);
    },
  );

  test('live performance samples expose run-level FPS percentiles', () {
    final subject = accumulator()
      ..updateLivePerformance(cameraFps: 31, analysisFps: 7)
      ..recordLivePerformanceSample(cameraFps: 30, analysisFps: 6)
      ..recordLivePerformanceSample(cameraFps: 28, analysisFps: 5)
      ..recordLivePerformanceSample(cameraFps: 32, analysisFps: 8)
      ..recordLivePerformanceSample(cameraFps: 29, analysisFps: 7);

    final snapshot = subject.snapshot(now: startedAt);
    final json = snapshot.toJson();

    expect(snapshot.currentCameraFps, 31);
    expect(snapshot.currentAnalysisFps, 7);
    expect(snapshot.fpsSampleCount, 4);
    expect(snapshot.cameraFpsP50, 29);
    expect(snapshot.cameraFpsP95, 32);
    expect(snapshot.analysisFpsP50, 6);
    expect(snapshot.analysisFpsP95, 8);
    expect(json['fps_sample_count'], 4);
    expect(json['camera_fps_p50'], 29);
    expect(json['camera_fps_p95'], 32);
    expect(json['analysis_fps_p50'], 6);
    expect(json['analysis_fps_p95'], 8);
    expect(
      () => subject.recordLivePerformanceSample(cameraFps: -1, analysisFps: 6),
      throwsArgumentError,
    );
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

  test('frame-pose pipeline stages keep independent duration baselines', () {
    final subject = accumulator()
      ..recordFramePosePipelineDurations(
        conversionDuration: const Duration(microseconds: 2500),
        poseDetectionDuration: const Duration(milliseconds: 8),
        candidateEvaluationDuration: const Duration(milliseconds: 3),
        totalDuration: const Duration(milliseconds: 15),
      )
      ..recordFramePosePipelineDurations(
        conversionDuration: const Duration(milliseconds: 4),
        poseDetectionDuration: const Duration(milliseconds: 12),
        candidateEvaluationDuration: const Duration(milliseconds: 5),
        totalDuration: const Duration(milliseconds: 24),
      )
      ..recordFramePosePipelineDurations(
        poseDetectionDuration: const Duration(milliseconds: 10),
        candidateEvaluationDuration: const Duration(milliseconds: 4),
        totalDuration: const Duration(milliseconds: 16),
      );

    final snapshot = subject.snapshot(now: startedAt);
    final timings = snapshot.framePosePipelineTimings;
    final json =
        snapshot.toJson()['frame_pose_pipeline_ms']! as Map<String, Object?>;

    expect(timings.conversion.sampleCount, 2);
    expect(timings.conversion.p50Ms, 2.5);
    expect(timings.conversion.p95Ms, 4);
    expect(timings.conversion.maxMs, 4);
    expect(timings.poseDetection.sampleCount, 3);
    expect(timings.poseDetection.p50Ms, 10);
    expect(timings.poseDetection.p95Ms, 12);
    expect(timings.candidateEvaluation.p50Ms, 4);
    expect(timings.total.p50Ms, 16);
    expect(timings.total.p95Ms, 24);
    expect(timings.total.maxMs, 24);
    expect(json['pose_detection'], <String, Object?>{
      'sample_count': 3,
      'p50': 10.0,
      'p95': 12.0,
      'max': 12.0,
    });
    expect(
      () => subject.recordFramePosePipelineDurations(
        totalDuration: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('range-rep roles serialize by enum order without frame values', () {
    final subject = accumulator()
      ..updateRangeRepState(
        repCount: 0,
        currentPhase: 'AWAITING_NEUTRAL',
        signalRoles: <RangeRepSignal, Set<AnalysisSignalRole>>{
          RangeRepSignal.formMetric: <AnalysisSignalRole>{
            AnalysisSignalRole.scoring,
            AnalysisSignalRole.validation,
            AnalysisSignalRole.technique,
          },
          RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
            AnalysisSignalRole.scoring,
            AnalysisSignalRole.detection,
            AnalysisSignalRole.validation,
          },
        },
      );

    final snapshot = subject.snapshot(now: startedAt);
    final json = snapshot.toJson();
    final serialized = json['range_rep_signal_roles']! as Map<String, Object?>;

    expect(
      snapshot.rangeRepSignalRoles.keys,
      containsAll(<RangeRepSignal>[
        RangeRepSignal.primaryMetric,
        RangeRepSignal.formMetric,
      ]),
    );
    expect(serialized.keys.toList(), <String>['primaryMetric', 'formMetric']);
    expect(serialized['primaryMetric'], <String>[
      'detection',
      'validation',
      'scoring',
    ]);
    expect(serialized['formMetric'], <String>[
      'validation',
      'technique',
      'scoring',
    ]);
    expect(json['hold_signal_roles'], isNull);
  });

  test('hold roles expose only the active hold contract signals', () {
    final subject = accumulator()
      ..updateHoldState(
        currentHoldSeconds: 0,
        bestHoldSeconds: 0,
        currentPhase: 'READY',
        isHolding: false,
        signalRoles: HoldContracts.hollowHold.signalRoles,
      );

    final snapshot = subject.snapshot(now: startedAt);
    final json = snapshot.toJson();
    final serialized = json['hold_signal_roles']! as Map<String, Object?>;

    expect(snapshot.holdSignalRoles, HoldContracts.hollowHold.signalRoles);
    expect(serialized.keys.toList(), <String>[
      'compression',
      'armExtension',
      'kneeExtension',
    ]);
    expect(serialized['compression'], <String>['detection', 'setup']);
    expect(serialized, isNot(contains(HoldSignal.alignment.name)));
    expect(json['range_rep_signal_roles'], isNull);
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
      ..recordAnalysisException()
      ..recordAnalysisTimeout()
      ..recordPoseCount(3)
      ..recordRejectedPose(rejectionReasonCode: 'low_landmark_likelihood')
      ..recordPoseQualitySample(
        minimumRequiredLikelihood: 0.55,
        meanRequiredLikelihood: 0.70,
        qualityScore: 0.60,
      )
      ..updateCameraRuntimeContext(
        sensorOrientationDegrees: 90,
        cameraLensDirection: 'front',
        deviceOrientation: 'portraitUp',
      )
      ..recordProcessingDuration(const Duration(milliseconds: 20))
      ..recordFramePosePipelineDurations(
        conversionDuration: const Duration(milliseconds: 2),
        poseDetectionDuration: const Duration(milliseconds: 8),
        candidateEvaluationDuration: const Duration(milliseconds: 3),
        totalDuration: const Duration(milliseconds: 15),
      )
      ..recordLivePerformanceSample(cameraFps: 30, analysisFps: 7)
      ..recordHoldVisibilitySuspend()
      ..recordHoldVisibilityRecovery(const Duration(milliseconds: 500))
      ..updateHoldState(
        currentHoldSeconds: 5,
        bestHoldSeconds: 5,
        currentPhase: 'HOLDING',
        isHolding: true,
        signalRoles: HoldContracts.plankFamily.signalRoles,
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
      ..reset(now: resetAt, analysisKind: 'rangeRep');
    final snapshot = subject.snapshot(
      now: resetAt.add(const Duration(seconds: 1)),
    );
    expect(snapshot.sessionStartedAt, resetAt);
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.exerciseType, 'squat');
    expect(snapshot.configAssetPath, 'assets/config/exercises/squat.json');
    expect(snapshot.elapsedMs, 1000);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisExceptionCount, 0);
    expect(snapshot.analysisTimeoutCount, 0);
    expect(snapshot.multiPoseFrameCount, 0);
    expect(snapshot.frameProcessingMsP50, isNull);
    expect(snapshot.framePosePipelineTimings.total.sampleCount, 0);
    expect(snapshot.framePosePipelineTimings.total.p50Ms, isNull);
    expect(snapshot.fpsSampleCount, 0);
    expect(snapshot.cameraFpsP50, isNull);
    expect(snapshot.cameraFpsP95, isNull);
    expect(snapshot.analysisFpsP50, isNull);
    expect(snapshot.analysisFpsP95, isNull);
    expect(snapshot.holdVisibilitySuspendCount, 0);
    expect(snapshot.holdVisibilityRecoveryCount, 0);
    expect(snapshot.holdVisibilityAbortCount, 0);
    expect(snapshot.holdVisibilitySuspendedMsTotal, 0);
    expect(snapshot.lastHoldVisibilityGapMs, isNull);
    expect(snapshot.poseRejectionReasonCounts, isEmpty);
    expect(snapshot.poseQualitySampleCount, 0);
    expect(snapshot.cameraLensDirection, isNull);
    expect(snapshot.sensorOrientationDegrees, isNull);
    expect(snapshot.deviceOrientation, isNull);
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
    expect(json['schema_version'], 12);
    expect(json['app_commit_sha'], 'abc123');
    expect(json['build_mode'], 'debug');
    expect(json['exercise_type'], 'squat');
    expect(
      json['config_version_fingerprint'],
      'assets/config/exercises/squat.json@abc123',
    );
    expect(json['contract_profile'], 'rangeRep:squat');
    expect(json['camera_frame_count'], 0);
    expect(json['accepted_pose_frame_count'], 0);
    expect(json['current_pose_quality_status'], 'stable');
    expect(json['camera_view_contract'], <String, String>{
      'side': 'preferred',
      'front': 'unsupported',
    });
    expect(json['side_switch_count'], 0);
    expect(json['active_rep_side_switch_count'], 0);
    expect(json['current_left_measurement_confidence'], isNull);
    expect(json['current_right_measurement_confidence'], isNull);
    expect(json['last_rep_measurement_confidence'], isNull);
    expect(json['measurement_confidence_known_rep_count'], 0);
    expect(json['measurement_confidence_unknown_rep_count'], 0);
    expect(json['measurement_confidence_issue_counts'], isNull);
    expect(json['left_range_rep_side_confidence'], isNull);
    expect(json['right_range_rep_side_confidence'], isNull);
    expect(json['fps_sample_count'], 0);
    expect(json['camera_fps_p50'], isNull);
    expect(json['camera_fps_p95'], isNull);
    expect(json['analysis_fps_p50'], isNull);
    expect(json['analysis_fps_p95'], isNull);
    expect(json['frame_pose_pipeline_ms'], <String, Object?>{
      'conversion': <String, Object?>{
        'sample_count': 0,
        'p50': null,
        'p95': null,
        'max': null,
      },
      'pose_detection': <String, Object?>{
        'sample_count': 0,
        'p50': null,
        'p95': null,
        'max': null,
      },
      'candidate_evaluation': <String, Object?>{
        'sample_count': 0,
        'p50': null,
        'p95': null,
        'max': null,
      },
      'total': <String, Object?>{
        'sample_count': 0,
        'p50': null,
        'p95': null,
        'max': null,
      },
    });
    expect(json['rep_count'], isNull);
    expect(json['current_hold_seconds'], isNull);
    expect(json['best_hold_seconds'], isNull);
    expect(json['is_holding'], isNull);
    expect(json['presented_hold_feedback_code'], isNull);
    expect(json['engine_hold_feedback_code'], isNull);
    expect(json['hold_engine_phase'], isNull);
    expect(json['current_hold_side'], isNull);
    expect(json['hold_current_signals'], isNull);
    expect(json['hold_target_signals'], isNull);
    expect(json['hold_signal_validity'], isNull);
    expect(json['hold_has_complete_metrics'], isNull);
    expect(json['hold_has_active_posture'], isNull);
    expect(json['hold_is_body_aligned'], isNull);
    expect(json['hold_is_arm_supported'], isNull);
    expect(json['hold_are_legs_extended'], isNull);
    expect(json['hold_is_form_break_grace_active'], isNull);
    expect(json['hold_is_visibility_suspended'], isNull);
    expect(json['hold_visibility_suspend_count'], isNull);
    expect(json['hold_visibility_recovery_count'], isNull);
    expect(json['hold_visibility_abort_count'], isNull);
    expect(json['hold_visibility_suspended_ms_total'], isNull);
    expect(json['last_hold_visibility_gap_ms'], isNull);
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
