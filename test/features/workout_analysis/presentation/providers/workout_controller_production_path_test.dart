import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  group('WorkoutController production pose pipeline', () {
    late _QueuedPoseDetector detector;
    late _FakeClock clock;
    late ProviderContainer container;
    late WorkoutController controller;
    late ProviderSubscription<WorkoutState> subscription;

    setUp(() {
      detector = _QueuedPoseDetector();
      clock = _FakeClock();
      container = ProviderContainer(
        overrides: <Override>[
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          poseDetectorProvider.overrideWith((ref) => detector),
          workoutClockProvider.overrideWithValue(clock.now),
        ],
      );
      addTearDown(container.dispose);
      subscription = container.listen<WorkoutState>(
        workoutControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      controller = container.read(workoutControllerProvider.notifier);
    });

    test(
      'rejected poses do not reach the engine and diagnostics stay in schema v2',
      () async {
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 170, defaultLikelihood: 0.40),
        ]);
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 170, defaultLikelihood: 0.40),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 0);
        expect(snapshot.schemaVersion, 2);
        expect(snapshot.acceptedPoseFrameCount, 0);
        expect(snapshot.rejectedPoseFrameCount, 2);
        expect(snapshot.lowConfidencePoseFrameCount, 2);
        expect(snapshot.lastPoseRejectionReason, 'low_landmark_likelihood');
        expect(snapshot.toJson()['schema_version'], 2);
      },
    );

    test('one hallucinated accepted frame does not recover tracking', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, const <Pose>[]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');
      expect(snapshot.briefOcclusionRecoveryCount, 0);
      expect(snapshot.currentVisibilityStatus, 'brief_freeze');
    });

    test(
      'brief PEAK occlusion recovers and preserves the visible rep',
      () async {
        await _armAndReachPeak(controller, detector, clock);

        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 1000));
        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        await _driveUntilPhase(
          controller,
          detector,
          clock,
          _squatPose(angle: 110),
          expectedPhase: 'ASCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          controller,
          detector,
          clock,
          _squatPose(angle: 170),
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 1);
        expect(snapshot.resyncCount, 0);
        expect(snapshot.briefOcclusionRecoveryCount, 1);
      },
    );

    test('phase-incompatible brief recovery aborts the half rep', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 1000));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
      expect(snapshot.briefOcclusionAbortCount, 1);
    });

    test('long occlusion triggers a hard resync exactly once', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 1500));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
      expect(snapshot.resyncCount, 1);
    });
  });

  test(
    'hold rejects low-confidence poses and does not start a false hold',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final container = ProviderContainer(
        overrides: <Override>[
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.plank),
          exerciseConfigProvider.overrideWith((ref) => _plankConfig()),
          poseDetectorProvider.overrideWith((ref) => detector),
          workoutClockProvider.overrideWithValue(clock.now),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<WorkoutState>(
        workoutControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(workoutControllerProvider.notifier);

      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(defaultLikelihood: 0.40),
      ]);
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(defaultLikelihood: 0.40),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.isHolding, isFalse);
      expect(state.currentHoldSeconds, 0);
      expect(snapshot.acceptedPoseFrameCount, 0);
      expect(snapshot.rejectedPoseFrameCount, 2);
    },
  );
}

Future<void> _armAndReachPeak(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _pumpAcceptedPose(
    controller,
    detector,
    clock,
    _squatPose(angle: 170),
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    _squatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    _squatPose(angle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );

  expect(controller.state.repCount, 0);
  expect(controller.state.currentPhase, 'PEAK');
}

Future<void> _driveUntilPhase(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
  Pose pose, {
  required String expectedPhase,
  required Duration spacing,
  int maxFrames = 12,
}) async {
  for (var index = 0; index < maxFrames; index++) {
    await _analyzeFrame(controller, detector, <Pose>[pose]);
    if (controller.state.currentPhase == expectedPhase) {
      return;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  throw TestFailure(
    'Expected phase $expectedPhase, got ${controller.state.currentPhase}',
  );
}

Future<void> _pumpAcceptedPose(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
  Pose pose, {
  required int count,
  required Duration spacing,
}) async {
  for (var index = 0; index < count; index++) {
    await _analyzeFrame(controller, detector, <Pose>[pose]);
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

Future<void> _analyzeFrame(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  List<Pose> poses,
) async {
  detector.enqueue(poses);
  await controller.processInputImageForAnalysis(_dummyInputImage());
}

InputImage _dummyInputImage() {
  return InputImage.fromBytes(
    bytes: Uint8List.fromList(<int>[0, 0, 0, 0]),
    metadata: InputImageMetadata(
      size: Size(1, 1),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: 1,
    ),
  );
}

class _QueuedPoseDetector implements PoseDetector {
  final List<List<Pose>> _queuedPoses = <List<Pose>>[];

  void enqueue(List<Pose> poses) {
    _queuedPoses.add(poses);
  }

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_queuedPoses.isEmpty) {
      throw StateError('No queued pose result for test detector.');
    }
    return _queuedPoses.removeAt(0);
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClock {
  DateTime _current = DateTime.utc(2030, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

ExerciseConfig _squatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 150,
    thresholdPeak: 95,
    formThreshold: 45,
    targetMinAngle: 70,
  );
}

ExerciseConfig _plankConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
  );
}

Pose _squatPose({required double angle, double defaultLikelihood = 0.95}) {
  final radians = angle * (3.1415926535897932 / 180.0);
  final ankleX = math.sin(radians);
  final ankleY = math.cos(radians);
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        -1,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        0,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        0,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        ankleX,
        ankleY,
        likelihood: defaultLikelihood,
      ),
    },
  );
}

Pose _plankPose({double defaultLikelihood = 0.95}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        1,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        2,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        2,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        3,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        4,
        1,
        likelihood: defaultLikelihood,
      ),
    },
  );
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}
