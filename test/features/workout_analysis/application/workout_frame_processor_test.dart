import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/common_frame_pose_pipeline.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_acceptance_stabilizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_analysis_runtime.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_frame_processor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  test(
    'camera orchestration owns reentrant and throttled drops and always releases the gate',
    () async {
      final clock = TestFakeClock();
      final cameraResult = Completer<FramePosePipelineResult>();
      final pipeline = _ControlledFramePosePipeline(
        cameraResult: cameraResult.future,
        inputResult: Future<FramePosePipelineResult>.value(
          const FramePosePipelineResult.noPose(poseCount: 0),
        ),
      );
      final runtime = _buildRuntime(
        clock: clock,
        pipeline: pipeline,
        diagnosticsEnabled: true,
      );
      final events = <String>[];
      var detectorReads = 0;
      final processor = WorkoutFrameProcessor(
        runtime: runtime,
        clock: clock.now,
        callbacks: WorkoutFrameProcessorCallbacks(
          onCameraFrameObserved: () => events.add('camera'),
          onAnalysisFrameObserved: () => events.add('analysis'),
          onTrackingResult: (result, observedAt) {
            events.add('tracking:${result.kind.name}');
          },
          onDetectedPoseFrame: (frame, observedAt) {
            events.add('frame:${frame.kind.name}');
          },
        ),
      );

      final firstFuture = processor.processCameraImage(
        image: _FakeCameraImage(),
        sensorOrientation: 90,
        cameraLensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitUp,
        readDetector: () {
          detectorReads++;
          return TestQueuedPoseDetector();
        },
        isPaused: () => false,
      );
      final second = await processor.processCameraImage(
        image: _FakeCameraImage(),
        sensorOrientation: 90,
        cameraLensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitUp,
        readDetector: () {
          detectorReads++;
          return TestQueuedPoseDetector();
        },
        isPaused: () => false,
      );

      expect(second.status, WorkoutFrameProcessingStatus.reentrantDrop);
      cameraResult.complete(const FramePosePipelineResult.noPose(poseCount: 0));
      final first = await firstFuture;
      final third = await processor.processCameraImage(
        image: _FakeCameraImage(),
        sensorOrientation: 90,
        cameraLensDirection: CameraLensDirection.back,
        deviceOrientation: DeviceOrientation.portraitUp,
        readDetector: () {
          detectorReads++;
          return TestQueuedPoseDetector();
        },
        isPaused: () => false,
      );

      expect(first.status, WorkoutFrameProcessingStatus.analyzed);
      expect(third.status, WorkoutFrameProcessingStatus.throttledDrop);
      expect(detectorReads, 1);
      expect(pipeline.cameraProcessCallCount, 1);
      expect(pipeline.finishCallCount, 1);
      expect(events, <String>[
        'camera',
        'camera',
        'analysis',
        'tracking:noPose',
        'frame:noPose',
        'camera',
      ]);

      final snapshot = runtime.diagnosticsReporter.snapshot(now: clock.now());
      expect(snapshot.cameraFrameCount, 3);
      expect(snapshot.analysisAttemptCount, 1);
      expect(snapshot.analysisCompletedCount, 1);
      expect(snapshot.reentrantDropCount, 1);
      expect(snapshot.throttledFrameCount, 1);
      expect(snapshot.noPoseFrameCount, 1);
    },
  );

  test(
    'accepted direct input is converted to an exercise-neutral detected frame',
    () async {
      final clock = TestFakeClock();
      final pose = buildSquatPose(angle: 170, defaultLikelihood: 0.80);
      final assessment = const PoseQualityPolicy().assess(
        pose: pose,
        config: buildSquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );
      final pipeline = _ControlledFramePosePipeline(
        cameraResult: Future<FramePosePipelineResult>.value(
          const FramePosePipelineResult.noPose(poseCount: 0),
        ),
        inputResult: Future<FramePosePipelineResult>.value(
          FramePosePipelineResult.accepted(
            poseCount: 1,
            selectedPose: pose,
            selectedAssessment: assessment,
            didBecomeStableTracking: true,
          ),
        ),
      );
      final runtime = _buildRuntime(
        clock: clock,
        pipeline: pipeline,
        diagnosticsEnabled: true,
      );
      WorkoutDetectedPoseFrame? detectedFrame;
      var analysisFrames = 0;
      final processor = WorkoutFrameProcessor(
        runtime: runtime,
        clock: clock.now,
        callbacks: WorkoutFrameProcessorCallbacks(
          onCameraFrameObserved: () {},
          onAnalysisFrameObserved: () => analysisFrames++,
          onTrackingResult: (result, observedAt) {},
          onDetectedPoseFrame: (frame, observedAt) {
            detectedFrame = frame;
          },
        ),
      );

      final outcome = await processor.processInputImage(
        inputImage: dummyInputImage(),
        readDetector: TestQueuedPoseDetector.new,
        isPaused: () => false,
      );

      expect(outcome.status, WorkoutFrameProcessingStatus.analyzed);
      expect(analysisFrames, 1);
      expect(detectedFrame, isNotNull);
      expect(detectedFrame!.kind, WorkoutPoseFrameKind.accepted);
      expect(detectedFrame!.didBecomeStableTracking, isTrue);
      expect(detectedFrame!.metrics.hasPose, isTrue);
      expect(detectedFrame!.metrics.primaryAngle, closeTo(170, 0.001));
      expect(
        detectedFrame!.qualityAcceptedRangeRepSides,
        contains(RangeRepSide.left),
      );

      final snapshot = runtime.diagnosticsReporter.snapshot(now: clock.now());
      expect(snapshot.analysisAttemptCount, 1);
      expect(snapshot.analysisCompletedCount, 1);
      expect(snapshot.detectedPoseFrameCount, 1);
      expect(snapshot.analysisExceptionCount, 0);
    },
  );

  test(
    'pipeline failures are returned with their stack and recorded once',
    () async {
      final clock = TestFakeClock();
      final pipeline = _ControlledFramePosePipeline(
        cameraError: StateError('camera failed'),
        inputError: StateError('input failed'),
      );
      final runtime = _buildRuntime(
        clock: clock,
        pipeline: pipeline,
        diagnosticsEnabled: true,
      );
      final processor = WorkoutFrameProcessor(
        runtime: runtime,
        clock: clock.now,
        callbacks: WorkoutFrameProcessorCallbacks(
          onCameraFrameObserved: () {},
          onAnalysisFrameObserved: () {},
          onTrackingResult: (result, observedAt) {},
          onDetectedPoseFrame: (frame, observedAt) {},
        ),
      );

      final outcome = await processor.processInputImage(
        inputImage: dummyInputImage(),
        readDetector: TestQueuedPoseDetector.new,
        isPaused: () => false,
      );

      expect(outcome.status, WorkoutFrameProcessingStatus.failed);
      expect(outcome.error, isA<StateError>());
      expect(outcome.stackTrace, isNotNull);
      final snapshot = runtime.diagnosticsReporter.snapshot(now: clock.now());
      expect(snapshot.analysisAttemptCount, 1);
      expect(snapshot.analysisCompletedCount, 0);
      expect(snapshot.analysisExceptionCount, 1);
    },
  );
}

WorkoutAnalysisRuntime _buildRuntime({
  required TestFakeClock clock,
  required WorkoutFramePosePipeline pipeline,
  required bool diagnosticsEnabled,
}) {
  return const WorkoutAnalysisRuntimeFactory().create(
    activeExercise: ExerciseType.squat,
    config: buildSquatConfig(),
    clock: clock.now,
    framePosePipelineFactory:
        ({required PoseAcceptanceStabilizer poseAcceptanceStabilizer}) {
          return pipeline;
        },
    rangeRepCoordinatorFactory:
        ({
          required RangeRepAnalysisEngine engine,
          required ExerciseConfig config,
          required RangeRepContract rangeRepContract,
          required RangeRepValidationConfig rangeRepValidationConfig,
        }) {
          return DefaultRangeRepCoordinator(
            engine: engine,
            config: config,
            rangeRepContract: rangeRepContract,
            rangeRepValidationConfig: rangeRepValidationConfig,
          );
        },
    holdCoordinatorFactory:
        ({
          required HoldAnalysisEngine engine,
          required ExerciseConfig config,
          required HoldContract holdContract,
        }) {
          return DefaultHoldCoordinator(
            engine: engine,
            config: config,
            holdContract: holdContract,
          );
        },
    diagnosticsEnabled: diagnosticsEnabled,
  );
}

class _ControlledFramePosePipeline extends WorkoutFramePosePipeline {
  _ControlledFramePosePipeline({
    this.cameraResult,
    this.inputResult,
    this.cameraError,
    this.inputError,
  }) : assert(cameraResult != null || cameraError != null),
       assert(inputResult != null || inputError != null);

  final Future<FramePosePipelineResult>? cameraResult;
  final Future<FramePosePipelineResult>? inputResult;
  final Object? cameraError;
  final Object? inputError;
  int cameraProcessCallCount = 0;
  int finishCallCount = 0;

  @override
  Future<FramePosePipelineResult> processCameraFrame({
    required CameraImage image,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required CameraLensDirection? lensDirection,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) {
    cameraProcessCallCount++;
    final error = cameraError;
    if (error != null) {
      return Future<FramePosePipelineResult>.error(error, StackTrace.current);
    }
    return cameraResult!;
  }

  @override
  Future<FramePosePipelineResult> processInputImage({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) {
    final error = inputError;
    if (error != null) {
      return Future<FramePosePipelineResult>.error(error, StackTrace.current);
    }
    return inputResult!;
  }

  @override
  void finishCameraFrame() {
    finishCallCount++;
    super.finishCameraFrame();
  }
}

class _FakeCameraImage implements CameraImage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
