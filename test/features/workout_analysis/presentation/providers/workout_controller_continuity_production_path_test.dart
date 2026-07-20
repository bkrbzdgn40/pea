import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart'
    show PoseQualityAssessment;
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutController continuity production path', () {
    test('range-rep production path delegates through RangeRepCoordinator and '
        'keeps the real engine outcome', () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      late _SpyRangeRepCoordinator spyCoordinator;
      final harness = _createHarness(
        exerciseType: ExerciseType.squat,
        config: buildSquatConfig(),
        detector: detector,
        clock: clock,
        extraOverrides: <Override>[
          rangeRepCoordinatorFactoryProvider.overrideWithValue(({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
            required RangeRepValidationConfig rangeRepValidationConfig,
          }) {
            spyCoordinator = _SpyRangeRepCoordinator(
              inner: DefaultRangeRepCoordinator(
                engine: engine,
                config: config,
                rangeRepContract: rangeRepContract,
                rangeRepValidationConfig: rangeRepValidationConfig,
              ),
            );
            return spyCoordinator;
          }),
        ],
      );
      addTearDown(harness.dispose);

      await _pumpAcceptedPose(
        harness.controller,
        detector,
        clock,
        buildSquatPose(angle: 170),
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        buildSquatPose(angle: 140),
        expectedPhase: 'DESCENDING',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        buildSquatPose(angle: 90),
        expectedPhase: 'PEAK',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        buildSquatPose(angle: 110),
        expectedPhase: 'ASCENDING',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        buildSquatPose(angle: 170),
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      final state = harness.container.read(workoutControllerProvider);

      expect(spyCoordinator.processFrameCallCount, greaterThan(0));
      expect(
        spyCoordinator.lastProcessFrameResult?.stateSnapshot.repCount,
        equals(1),
      );
      expect(state.rangeRepAnalysis, isNotNull);
      expect(state.holdAnalysis, isNull);
      expect(state.repCount, 1);
      expect(
        state.calibrationMetrics.lastRangeRepValidationStatus,
        equals('valid'),
      );
      expect(
        state.calibrationMetrics.lastRangeRepSummaryCompletedPhaseSequence,
        isTrue,
      );
    });

    test('range-rep lifecycle interruption delegates to the coordinator and '
        'forces fresh neutral reacquisition', () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      late _SpyRangeRepCoordinator spyCoordinator;
      final harness = _createHarness(
        exerciseType: ExerciseType.squat,
        config: buildSquatConfig(),
        detector: detector,
        clock: clock,
        extraOverrides: <Override>[
          rangeRepCoordinatorFactoryProvider.overrideWithValue(({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
            required RangeRepValidationConfig rangeRepValidationConfig,
          }) {
            spyCoordinator = _SpyRangeRepCoordinator(
              inner: DefaultRangeRepCoordinator(
                engine: engine,
                config: config,
                rangeRepContract: rangeRepContract,
                rangeRepValidationConfig: rangeRepValidationConfig,
              ),
            );
            return spyCoordinator;
          }),
        ],
      );
      addTearDown(harness.dispose);

      await _establishActiveRepContext(harness.controller, detector, clock);

      harness.controller.handleLifecycleInterruption(reason: 'paused');

      var state = harness.container.read(workoutControllerProvider);

      expect(spyCoordinator.handleLifecycleInterruptionCallCount, 1);
      expect(spyCoordinator.diagnosticsState().selectedSideLabel, isNull);
      expect(spyCoordinator.diagnosticsState().hasActiveRepContext, isFalse);
      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');

      await _analyzeFrame(harness.controller, detector, <Pose>[
        buildSquatPose(angle: 90),
      ]);
      state = harness.container.read(workoutControllerProvider);

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(harness.controller, detector, <Pose>[
        buildSquatPose(angle: 90),
      ]);
      state = harness.container.read(workoutControllerProvider);

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
    });

    test('hold production path delegates through HoldCoordinator and keeps the '
        'real engine outcome', () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      late _SpyHoldCoordinator spyCoordinator;
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: buildPlankConfig(),
        detector: detector,
        clock: clock,
        extraOverrides: <Override>[
          holdCoordinatorFactoryProvider.overrideWithValue(({
            required HoldAnalysisEngine engine,
            required ExerciseConfig config,
            required HoldContract holdContract,
          }) {
            spyCoordinator = _SpyHoldCoordinator(
              inner: DefaultHoldCoordinator(
                engine: engine,
                config: config,
                holdContract: holdContract,
              ),
            );
            return spyCoordinator;
          }),
        ],
      );
      addTearDown(harness.dispose);

      await _establishVisibleHold(harness.controller, detector, clock);

      final state = harness.container.read(workoutControllerProvider);

      expect(
        spyCoordinator.selectHoldSideForAcceptedPoseCallCount,
        greaterThan(0),
      );
      expect(
        spyCoordinator.requiredHoldSideForAssessmentCallCount,
        greaterThan(0),
      );
      expect(spyCoordinator.processFrameCallCount, greaterThan(0));
      expect(spyCoordinator.lastSelectedHoldSide, HoldSide.left);
      expect(
        spyCoordinator.lastProcessFrameResult?.stateSnapshot.isHolding,
        isTrue,
      );
      expect(
        spyCoordinator.lastProcessFrameResult?.stateSnapshot.currentHoldSeconds,
        closeTo(5.0, 0.001),
      );
      expect(state.holdAnalysis, isNotNull);
      expect(state.rangeRepAnalysis, isNull);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
      expect(state.holdEnginePhase, HoldPhase.holding);
    });

    test(
      'hold lifecycle interruption ends the active hold and restarts from zero',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        late _SpyHoldCoordinator spyCoordinator;
        final harness = _createHarness(
          exerciseType: ExerciseType.plank,
          config: buildPlankConfig(),
          detector: detector,
          clock: clock,
          extraOverrides: <Override>[
            holdCoordinatorFactoryProvider.overrideWithValue(({
              required HoldAnalysisEngine engine,
              required ExerciseConfig config,
              required HoldContract holdContract,
            }) {
              spyCoordinator = _SpyHoldCoordinator(
                inner: DefaultHoldCoordinator(
                  engine: engine,
                  config: config,
                  holdContract: holdContract,
                ),
              );
              return spyCoordinator;
            }),
          ],
        );
        addTearDown(harness.dispose);
        final container = harness.container;
        final controller = harness.controller;

        await _establishVisibleHold(controller, detector, clock);

        controller.handleLifecycleInterruption(reason: 'paused');

        var state = container.read(workoutControllerProvider);
        expect(spyCoordinator.handleLifecycleInterruptionCallCount, 1);
        expect(state.currentHoldSeconds, 0);
        expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
        expect(state.isHolding, isFalse);
        expect(state.isHoldVisibilitySuspended, isFalse);
        expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
        expect(state.holdEnginePhase, HoldPhase.ready);
        expect(state.feedbackMessage, 'Pozisyonu Hazirla');
        expect(state.currentPhase, 'READY');
        expect(state.hadHoldFormBreak, isFalse);

        clock.advance(const Duration(seconds: 10));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        state = container.read(workoutControllerProvider);
        expect(state.isHolding, isFalse);
        expect(state.currentHoldSeconds, 0);

        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        state = container.read(workoutControllerProvider);
        expect(state.isHolding, isTrue);
        expect(state.currentHoldSeconds, 0);
        expect(state.bestHoldSeconds, closeTo(5.0, 0.001));

        clock.advance(const Duration(seconds: 1));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        state = container.read(workoutControllerProvider);
        expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
        expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
        expect(state.hadHoldFormBreak, isFalse);
      },
    );

    test(
      'hold lifecycle interruption during READY preserves the idle state',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        late _SpyHoldCoordinator spyCoordinator;
        final harness = _createHarness(
          exerciseType: ExerciseType.plank,
          config: buildPlankConfig(),
          detector: detector,
          clock: clock,
          extraOverrides: <Override>[
            holdCoordinatorFactoryProvider.overrideWithValue(({
              required HoldAnalysisEngine engine,
              required ExerciseConfig config,
              required HoldContract holdContract,
            }) {
              spyCoordinator = _SpyHoldCoordinator(
                inner: DefaultHoldCoordinator(
                  engine: engine,
                  config: config,
                  holdContract: holdContract,
                ),
              );
              return spyCoordinator;
            }),
          ],
        );
        addTearDown(harness.dispose);
        final container = harness.container;
        final controller = harness.controller;

        controller.handleLifecycleInterruption(reason: 'paused');

        final state = container.read(workoutControllerProvider);
        expect(spyCoordinator.handleLifecycleInterruptionCallCount, 1);
        expect(state.currentHoldSeconds, 0);
        expect(state.bestHoldSeconds, 0);
        expect(state.isHolding, isFalse);
        expect(state.isHoldVisibilitySuspended, isFalse);
        expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
        expect(state.holdEnginePhase, HoldPhase.ready);
        expect(state.feedbackMessage, 'Pozisyonu Hazirla');
        expect(state.currentPhase, 'READY');
        expect(state.hadHoldFormBreak, isFalse);
      },
    );

    test(
      'hold lifecycle interruption during visibility suspension clears the old '
      'hold',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        late _SpyHoldCoordinator spyCoordinator;
        final harness = _createHarness(
          exerciseType: ExerciseType.plank,
          config: buildPlankConfig(),
          detector: detector,
          clock: clock,
          extraOverrides: <Override>[
            holdCoordinatorFactoryProvider.overrideWithValue(({
              required HoldAnalysisEngine engine,
              required ExerciseConfig config,
              required HoldContract holdContract,
            }) {
              spyCoordinator = _SpyHoldCoordinator(
                inner: DefaultHoldCoordinator(
                  engine: engine,
                  config: config,
                  holdContract: holdContract,
                ),
              );
              return spyCoordinator;
            }),
          ],
        );
        addTearDown(harness.dispose);
        final container = harness.container;
        final controller = harness.controller;

        await _establishVisibleHold(controller, detector, clock);

        clock.advance(const Duration(milliseconds: 50));
        await _analyzeFrame(controller, detector, const <Pose>[]);

        var state = container.read(workoutControllerProvider);
        expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
        expect(state.isHoldVisibilitySuspended, isTrue);

        controller.handleLifecycleInterruption(reason: 'paused');

        state = container.read(workoutControllerProvider);
        expect(spyCoordinator.handleLifecycleInterruptionCallCount, 1);
        expect(state.currentHoldSeconds, 0);
        expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
        expect(state.isHolding, isFalse);
        expect(state.isHoldVisibilitySuspended, isFalse);
        expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
        expect(state.holdEnginePhase, HoldPhase.ready);
        expect(state.feedbackMessage, 'Pozisyonu Hazirla');
        expect(state.currentPhase, 'READY');

        clock.advance(const Duration(seconds: 10));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        state = container.read(workoutControllerProvider);
        expect(state.isHolding, isTrue);
        expect(state.currentHoldSeconds, 0);

        clock.advance(const Duration(seconds: 1));
        await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
        state = container.read(workoutControllerProvider);
        expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
        expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      },
    );
  });
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
  await analyzeFrame(controller, detector, poses);
}

Future<void> _establishVisibleHold(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
  clock.advance(const Duration(milliseconds: 100));
  await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
  clock.advance(const Duration(seconds: 5));
  await _analyzeFrame(controller, detector, <Pose>[buildPlankPose()]);
}

Future<void> _establishActiveRepContext(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _pumpAcceptedPose(
    controller,
    detector,
    clock,
    buildSquatPose(angle: 170),
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    buildSquatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
}

class _QueuedPoseDetector extends TestQueuedPoseDetector {}

class _FakeClock extends TestFakeClock {}

class _SpyRangeRepCoordinator implements RangeRepCoordinator {
  _SpyRangeRepCoordinator({required this.inner});

  final RangeRepCoordinator inner;

  int processFrameCallCount = 0;
  int handleLifecycleInterruptionCallCount = 0;
  RangeRepCoordinatorFrameResult? lastProcessFrameResult;

  @override
  RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    handleLifecycleInterruptionCallCount += 1;
    return inner.handleLifecycleInterruption(reason: reason);
  }

  @override
  RangeRepCoordinatorDiagnosticsState diagnosticsState() {
    return inner.diagnosticsState();
  }

  @override
  RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    processFrameCallCount += 1;
    lastProcessFrameResult = inner.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    return lastProcessFrameResult!;
  }
}

class _SpyHoldCoordinator implements HoldCoordinator {
  _SpyHoldCoordinator({required this.inner});

  final HoldCoordinator inner;

  int requiredHoldSideForAssessmentCallCount = 0;
  int selectHoldSideForAcceptedPoseCallCount = 0;
  int processFrameCallCount = 0;
  int handleLifecycleInterruptionCallCount = 0;
  HoldSide? lastSelectedHoldSide;
  HoldCoordinatorFrameResult? lastProcessFrameResult;

  @override
  HoldCoordinatorStateSnapshot currentStateSnapshot() {
    return inner.currentStateSnapshot();
  }

  @override
  HoldCoordinatorStateSnapshot handleLifecycleInterruption({String? reason}) {
    handleLifecycleInterruptionCallCount += 1;
    return inner.handleLifecycleInterruption(reason: reason);
  }

  @override
  HoldCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
  }) {
    processFrameCallCount += 1;
    lastProcessFrameResult = inner.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
    );
    return lastProcessFrameResult!;
  }

  @override
  HoldSide? requiredHoldSideForAssessment() {
    requiredHoldSideForAssessmentCallCount += 1;
    return inner.requiredHoldSideForAssessment();
  }

  @override
  HoldSide selectHoldSideForAcceptedPose(PoseQualityAssessment assessment) {
    selectHoldSideForAcceptedPoseCallCount += 1;
    lastSelectedHoldSide = inner.selectHoldSideForAcceptedPose(assessment);
    return lastSelectedHoldSide!;
  }

  @override
  HoldDiagnosticsSnapshot diagnosticsSnapshot() {
    return inner.diagnosticsSnapshot();
  }
}

class _ControllerHarness {
  const _ControllerHarness({
    required this.container,
    required this.subscription,
    required this.controller,
  });

  final ProviderContainer container;
  final ProviderSubscription<WorkoutState> subscription;
  final WorkoutController controller;

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

_ControllerHarness _createHarness({
  required ExerciseType exerciseType,
  required ExerciseConfig config,
  required _QueuedPoseDetector detector,
  required _FakeClock clock,
  List<Override> extraOverrides = const <Override>[],
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith((ref) => config),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
      ...extraOverrides,
    ],
  );
  final subscription = container.listen<WorkoutState>(
    workoutControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  final controller = container.read(workoutControllerProvider.notifier);
  return _ControllerHarness(
    container: container,
    subscription: subscription,
    controller: controller,
  );
}
