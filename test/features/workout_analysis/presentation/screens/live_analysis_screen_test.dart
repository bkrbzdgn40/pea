import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/auth/application/repositories/auth_repository.dart';
import 'package:pose_estimation_app/features/auth/domain/models/auth_user.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_session_metrics_collector.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/camera_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/live_analysis_screen.dart';

void main() {
  testWidgets('pause lifecycle disarms a PEAK recovery before neutral return', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
        poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        cameraProvider.overrideWith(
          (ref) async => throw CameraException('test', 'camera unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LiveAnalysisScreen()),
      ),
    );
    await tester.pump();

    final controller = container.read(workoutControllerProvider.notifier);
    final timeline = _ControllerTimeline();

    await tester.runAsync(() async {
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 170,
        expectedPhase: 'NEUTRAL',
      );
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 140,
        expectedPhase: 'DESCENDING',
      );
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 90,
        expectedPhase: 'PEAK',
      );
    });

    expect(container.read(workoutControllerProvider).currentPhase, 'PEAK');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    var state = container.read(workoutControllerProvider);
    expect(state.currentPhase, rangeRepAwaitNeutralPhaseLabel);
    expect(state.repCount, 0);

    await tester.runAsync(() async {
      await _pumpFrames(controller, timeline, primaryAngle: 90);
      await _driveUntilPhase(
        container,
        controller,
        timeline,
        primaryAngle: 170,
        expectedPhase: 'NEUTRAL',
      );
    });
    await tester.pump();

    state = container.read(workoutControllerProvider);
    expect(state.repCount, 0);
    expect(state.currentPhase, 'NEUTRAL');
  });

  testWidgets(
    'pause lifecycle on plank reaches the controller interruption path',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _establishVisibleHoldOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      var state = harness.container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isFalse);
      expect(state.currentPhase, 'READY');

      await tester.runAsync(() async {
        harness.clock.advance(const Duration(seconds: 10));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
        harness.clock.advance(const Duration(milliseconds: 100));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
        harness.clock.advance(const Duration(seconds: 1));
        await _analyzePoseFrame(harness.controller, harness.detector, <Pose>[
          _plankPose(),
        ]);
      });
      await tester.pump();

      state = harness.container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
    },
  );

  test(
    'hold session collector excludes hidden and duplicate time across a brief '
    'suspension',
    () {
      final collector = HoldSessionMetricsCollector();

      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: false,
          isHoldVisibilitySuspended: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 6,
          bestHoldSeconds: 6,
          isHolding: true,
        ),
      );

      expect(collector.totalHoldSeconds, closeTo(6.0, 0.001));
      expect(collector.totalHoldSeconds, isNot(closeTo(11.0, 0.001)));
      expect(collector.bestHoldSeconds, closeTo(6.0, 0.001));
    },
  );

  test(
    'hold session collector resets the old hold after a long gap before a new '
    '2 second hold',
    () {
      final collector = HoldSessionMetricsCollector();

      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: false,
          isHoldVisibilitySuspended: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 0,
          bestHoldSeconds: 5,
          isHolding: false,
          isHoldVisibilitySuspended: false,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 0,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 1,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );
      collector.collect(
        WorkoutState(
          analysisKind: EngineKind.hold,
          currentHoldSeconds: 2,
          bestHoldSeconds: 5,
          isHolding: true,
        ),
      );

      expect(collector.totalHoldSeconds, closeTo(7.0, 0.001));
      expect(collector.bestHoldSeconds, closeTo(5.0, 0.001));
    },
  );
}

class _FakePoseDetector implements PoseDetector {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllerTimeline {
  DateTime current = DateTime.utc(2030, 1, 1);

  DateTime advance(Duration duration) {
    current = current.add(duration);
    return current;
  }
}

Future<void> _driveUntilPhase(
  ProviderContainer container,
  WorkoutController controller,
  _ControllerTimeline timeline, {
  required double primaryAngle,
  required String expectedPhase,
  double formMetric = 170,
  int maxFrames = 12,
  Duration frameSpacing = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < maxFrames; index++) {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      now: timeline.current,
    );
    if (container.read(workoutControllerProvider).currentPhase ==
        expectedPhase) {
      return;
    }
    if (index == maxFrames - 1) {
      break;
    }
    await Future<void>.delayed(frameSpacing);
    timeline.advance(frameSpacing);
  }

  throw TestFailure(
    'Expected phase $expectedPhase for primaryAngle $primaryAngle',
  );
}

Future<void> _pumpFrames(
  WorkoutController controller,
  _ControllerTimeline timeline, {
  required double primaryAngle,
  double formMetric = 170,
  int frameCount = 6,
  Duration frameSpacing = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < frameCount; index++) {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      now: timeline.current,
    );
    if (index == frameCount - 1) {
      break;
    }
    await Future<void>.delayed(frameSpacing);
    timeline.advance(frameSpacing);
  }
}

ExerciseMetrics _validMetrics({
  required double primaryAngle,
  double formMetric = 170,
}) {
  final left = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryAngle,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1,
    formSignals: RangeRepFormSignals(
      torsoAngle: formMetric,
      depthMetric: primaryAngle,
      alignmentMetric: formMetric,
      lockoutMetric: primaryAngle,
    ),
  );
  return ExerciseMetrics(
    primaryAngle: primaryAngle,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: const <PoseLandmark>[],
    leftRangeRepMetrics: left,
    rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.right,
    ),
  );
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
    holdSignals: const HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

Pose _plankPose({double defaultLikelihood = 0.95}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        -1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        -0.5,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        -0.5,
        -1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        0,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        0.2,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        1,
        0.2,
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

class _LiveScreenHarness {
  const _LiveScreenHarness({
    required this.container,
    required this.controller,
    required this.detector,
    required this.clock,
    required this.sessionRepository,
  });

  final ProviderContainer container;
  final WorkoutController controller;
  final _QueuedPoseDetector detector;
  final _FakeClock clock;
  final _FakeSessionRepository sessionRepository;

  void dispose() {
    container.dispose();
  }
}

Future<_LiveScreenHarness> _pumpLiveAnalysisScreen(
  WidgetTester tester, {
  required ExerciseType exerciseType,
  required ExerciseConfig config,
}) async {
  final detector = _QueuedPoseDetector();
  final clock = _FakeClock();
  final sessionRepository = _FakeSessionRepository();
  final container = ProviderContainer(
    overrides: <Override>[
      selectedExerciseProvider.overrideWith((ref) => exerciseType),
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith((ref) => config),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
      authRepositoryProvider.overrideWithValue(
        const _FakeAuthRepository(currentUserId: 'test-user'),
      ),
      sessionRepositoryProvider.overrideWithValue(sessionRepository),
      cameraProvider.overrideWith(
        (ref) async => throw CameraException('test', 'camera unavailable'),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LiveAnalysisScreen()),
    ),
  );
  await tester.pump();

  return _LiveScreenHarness(
    container: container,
    controller: container.read(workoutControllerProvider.notifier),
    detector: detector,
    clock: clock,
    sessionRepository: sessionRepository,
  );
}

Future<void> _establishVisibleHoldOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
  clock.advance(const Duration(milliseconds: 100));
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
  clock.advance(const Duration(seconds: 5));
  await _analyzePoseFrame(controller, detector, <Pose>[_plankPose()]);
}

Future<void> _analyzePoseFrame(
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

class _FakeSessionRepository implements SessionRepository {
  final List<WorkoutSession> savedSessions = <WorkoutSession>[];

  @override
  Future<void> saveSession(WorkoutSession session) async {
    savedSessions.add(session);
  }

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async {
    return const <WorkoutRep>[];
  }

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async {
    return List<WorkoutSession>.unmodifiable(savedSessions);
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({required this.currentUserId});

  @override
  final String? currentUserId;

  @override
  AuthUser? get currentUser => currentUserId == null
      ? null
      : AuthUser(
          uid: currentUserId!,
          email: null,
          displayName: null,
          isAnonymous: true,
        );

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(currentUser);

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signOut() async {}
}
