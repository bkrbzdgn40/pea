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

import '../../../../support/workout_analysis_test_support.dart';

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

  testWidgets(
    'finishing a completed range-rep session saves the production rep summary',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _completeCleanRangeRepOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.repCount, 1);
      expect(state.calibrationMetrics.lastRangeRepValidatedRepIndex, 1);
      expect(state.calibrationMetrics.lastRangeRepValidationStatus, 'valid');
      expect(find.text('Bitir'), findsOneWidget);

      await tester.tap(find.text('Bitir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;
      final rep = session.reps!.single;

      expect(session.ownerId, 'test-user');
      expect(session.exerciseType, ExerciseType.squat.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.totalReps, 1);
      expect(session.validReps, 1);
      expect(session.invalidReps, 0);
      expect(session.formWarningCount, 0);
      expect(session.reps, hasLength(1));
      expect(rep.repIndex, 1);
      expect(rep.validationStatus, 'valid');
      expect(rep.validationReasons, isEmpty);
      expect(rep.completedPhaseSequence, isTrue);
      expect(rep.selectedSideLabel, 'left');
    },
  );

  testWidgets(
    'finishing an active hold session saves the collected hold totals',
    (tester) async {
      final harness = await _pumpLiveAnalysisScreen(
        tester,
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        showFinishButton: true,
      );
      addTearDown(harness.dispose);

      await tester.runAsync(() async {
        await _establishVisibleHoldOnScreen(
          harness.controller,
          harness.detector,
          harness.clock,
        );
      });
      await tester.pump();

      final state = harness.container.read(workoutControllerProvider);
      expect(state.isHolding, isTrue);
      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(find.text('Bitir'), findsOneWidget);

      await tester.tap(find.text('Bitir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(harness.sessionRepository.savedSessions, hasLength(1));
      final session = harness.sessionRepository.savedSessions.single;

      expect(session.ownerId, 'test-user');
      expect(session.exerciseType, ExerciseType.plank.id);
      expect(session.analysisKind, EngineKind.hold.name);
      expect(session.totalReps, 0);
      expect(session.validReps, 0);
      expect(session.invalidReps, 0);
      expect(session.averageScore, 0);
      expect(session.bestScore, 0);
      expect(session.worstScore, 0);
      expect(session.totalHoldSeconds, closeTo(5.0, 0.001));
      expect(session.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(session.formBreakCount, 0);
      expect(session.reps, isNull);
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
  return buildSquatConfig();
}

ExerciseConfig _plankConfig() {
  return buildPlankConfig();
}

Pose _plankPose({double defaultLikelihood = 0.95}) {
  return buildPlankPose(defaultLikelihood: defaultLikelihood);
}

Pose _squatPose({required double angle, double defaultLikelihood = 0.95}) {
  return buildSquatPose(angle: angle, defaultLikelihood: defaultLikelihood);
}

class _LiveScreenHarness {
  const _LiveScreenHarness({
    required this.container,
    required this.controller,
    required this.detector,
    required this.clock,
    required this.sessionRepository,
    required this.cameraController,
  });

  final ProviderContainer container;
  final WorkoutController controller;
  final _QueuedPoseDetector detector;
  final _FakeClock clock;
  final _FakeSessionRepository sessionRepository;
  final _FakeCameraController? cameraController;

  Future<void> dispose() async {
    await cameraController?.dispose();
    container.dispose();
  }
}

Future<_LiveScreenHarness> _pumpLiveAnalysisScreen(
  WidgetTester tester, {
  required ExerciseType exerciseType,
  required ExerciseConfig config,
  bool showFinishButton = false,
}) async {
  final detector = _QueuedPoseDetector();
  final clock = _FakeClock();
  final sessionRepository = _FakeSessionRepository();
  final cameraController = showFinishButton ? _FakeCameraController() : null;
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
      cameraProvider.overrideWith((ref) async {
        if (cameraController != null) {
          return cameraController;
        }

        throw CameraException('test', 'camera unavailable');
      }),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LiveAnalysisScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();

  return _LiveScreenHarness(
    container: container,
    controller: container.read(workoutControllerProvider.notifier),
    detector: detector,
    clock: clock,
    sessionRepository: sessionRepository,
    cameraController: cameraController,
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
  await analyzeFrame(controller, detector, poses);
}

Future<void> _completeCleanRangeRepOnScreen(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  clock.advance(const Duration(milliseconds: 120));
  await _analyzePoseFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 110),
    expectedPhase: 'ASCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveRangeRepPoseUntilPhase(
    controller,
    detector,
    clock,
    pose: _squatPose(angle: 170),
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

Future<void> _driveRangeRepPoseUntilPhase(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock, {
  required Pose pose,
  required String expectedPhase,
  required Duration spacing,
  int maxFrames = 12,
}) async {
  for (var index = 0; index < maxFrames; index++) {
    await _analyzePoseFrame(controller, detector, <Pose>[pose]);
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

class _QueuedPoseDetector extends TestQueuedPoseDetector {}

class _FakeClock extends TestFakeClock {}

class _FakeCameraController extends CameraController {
  _FakeCameraController()
    : super(
        const CameraDescription(
          name: 'fake-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
      isStreamingImages: true,
    );
  }

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<void> stopImageStream() async {
    value = value.copyWith(isStreamingImages: false);
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
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
