import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_frame_processor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/workout_analysis_health_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/feedback_delivery_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_analysis_health_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'transient failure clears stale output and recovers on success',
    () async {
      final detector = _ControlledPoseDetector();
      final clock = TestFakeClock();
      final feedbackDelivery = _RecordingFeedbackDelivery();
      final harness = _buildHarness(
        detector: detector,
        clock: clock,
        feedbackDelivery: feedbackDelivery,
      );
      addTearDown(harness.dispose);

      final pose = buildSquatPose(angle: 170);
      detector.enqueuePoses(<Pose>[pose]);
      await harness.controller.processInputImageForAnalysis(dummyInputImage());
      clock.advance(const Duration(milliseconds: 100));
      detector.enqueuePoses(<Pose>[pose]);
      await harness.controller.processInputImageForAnalysis(dummyInputImage());

      final beforeFailure = harness.container.read(workoutControllerProvider);
      expect(beforeFailure.landmarks, isNotEmpty);
      expect(beforeFailure.feedbackMessage, isNotEmpty);

      final deliveredBeforeFailure = feedbackDelivery.deliveredCount;
      final failureStates = <WorkoutState>[];
      final failureStateSubscription = harness.container.listen<WorkoutState>(
        workoutControllerProvider,
        (previous, next) => failureStates.add(next),
      );
      addTearDown(failureStateSubscription.close);
      detector.enqueueError(StateError('temporary detector failure'));
      await expectLater(
        harness.controller.processInputImageForAnalysis(dummyInputImage()),
        throwsA(isA<StateError>()),
      );

      final failedState = harness.container.read(workoutControllerProvider);
      final recovering = harness.container.read(
        workoutAnalysisHealthControllerProvider,
      );
      expect(failedState.landmarks, isNull);
      expect(failedState.feedbackMessage, isEmpty);
      expect(recovering.status, WorkoutAnalysisHealthStatus.recovering);
      expect(recovering.consecutiveFailureCount, 1);
      expect(feedbackDelivery.stopCount, 1);
      expect(failureStates, isNotEmpty);
      expect(
        failureStates.every((emittedState) => emittedState.landmarks == null),
        isTrue,
      );

      detector.enqueuePoses(const <Pose>[]);
      await harness.controller.processInputImageForAnalysis(dummyInputImage());

      expect(
        harness.container.read(workoutAnalysisHealthControllerProvider).status,
        WorkoutAnalysisHealthStatus.healthy,
      );
      expect(feedbackDelivery.deliveredCount, deliveredBeforeFailure);
    },
  );

  test(
    'hold failure interrupts the active hold and clears stale output',
    () async {
      final detector = _ControlledPoseDetector();
      final clock = TestFakeClock();
      final harness = _buildHarness(
        detector: detector,
        clock: clock,
        exerciseType: ExerciseType.plank,
      );
      addTearDown(harness.dispose);

      final pose = buildPlankPose();
      detector.enqueuePoses(<Pose>[pose]);
      await harness.controller.processInputImageForAnalysis(dummyInputImage());
      clock.advance(const Duration(milliseconds: 100));
      detector.enqueuePoses(<Pose>[pose]);
      await harness.controller.processInputImageForAnalysis(dummyInputImage());

      final beforeFailure = harness.container.read(workoutControllerProvider);
      expect(beforeFailure.landmarks, isNotEmpty);

      detector.enqueueError(StateError('hold detector failure'));
      await expectLater(
        harness.controller.processInputImageForAnalysis(dummyInputImage()),
        throwsA(isA<StateError>()),
      );

      final failedState = harness.container.read(workoutControllerProvider);
      expect(failedState.landmarks, isNull);
      expect(failedState.feedbackMessage, isEmpty);
      expect(failedState.isHolding, isFalse);
      expect(failedState.currentHoldSeconds, 0);
      expect(
        harness.container.read(workoutAnalysisHealthControllerProvider).status,
        WorkoutAnalysisHealthStatus.recovering,
      );
    },
  );

  test('three consecutive exceptions block analysis until retry', () async {
    final detector = _ControlledPoseDetector();
    final harness = _buildHarness(detector: detector, clock: TestFakeClock());
    addTearDown(harness.dispose);

    for (var index = 0; index < 3; index++) {
      detector.enqueueError(StateError('failure-$index'));
      await expectLater(
        harness.controller.processInputImageForAnalysis(dummyInputImage()),
        throwsA(isA<StateError>()),
      );
    }

    final blocked = harness.container.read(
      workoutAnalysisHealthControllerProvider,
    );
    expect(blocked.status, WorkoutAnalysisHealthStatus.blocked);
    expect(blocked.consecutiveFailureCount, 3);
    expect(detector.processCallCount, 3);

    await expectLater(
      harness.controller.processInputImageForAnalysis(dummyInputImage()),
      throwsA(isA<StateError>()),
    );
    expect(detector.processCallCount, 3);

    harness.controller.retryAnalysis();
    expect(
      harness.container.read(workoutAnalysisHealthControllerProvider).status,
      WorkoutAnalysisHealthStatus.healthy,
    );
  });

  test('detector timeout blocks immediately and requires retry', () async {
    final detector = _ControlledPoseDetector();
    final pending = Completer<List<Pose>>();
    detector.enqueueFuture(pending.future);
    final harness = _buildHarness(
      detector: detector,
      clock: TestFakeClock(),
      poseDetectionTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(harness.dispose);

    await expectLater(
      harness.controller.processInputImageForAnalysis(dummyInputImage()),
      throwsA(isA<WorkoutPoseDetectionTimeoutException>()),
    );

    final blocked = harness.container.read(
      workoutAnalysisHealthControllerProvider,
    );
    expect(blocked.status, WorkoutAnalysisHealthStatus.blocked);
    expect(blocked.failureKind?.name, 'poseDetectionTimeout');
    expect(detector.processCallCount, 1);

    harness.controller.retryAnalysis();
    expect(
      harness.container.read(workoutAnalysisHealthControllerProvider).status,
      WorkoutAnalysisHealthStatus.healthy,
    );
    pending.complete(const <Pose>[]);
  });
}

_Harness _buildHarness({
  required _ControlledPoseDetector detector,
  required TestFakeClock clock,
  ExerciseType exerciseType = ExerciseType.squat,
  Duration poseDetectionTimeout = defaultWorkoutPoseDetectionTimeout,
  FeedbackDeliveryPort? feedbackDelivery,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith(
        (ref) => exerciseType == ExerciseType.plank
            ? buildPlankConfig()
            : buildSquatConfig(),
      ),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
      workoutPoseDetectionTimeoutProvider.overrideWithValue(
        poseDetectionTimeout,
      ),
      feedbackDeliveryProvider.overrideWithValue(
        feedbackDelivery ?? const _NoopFeedbackDelivery(),
      ),
    ],
  );
  final subscription = container.listen<WorkoutState>(
    workoutControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  return _Harness(
    container: container,
    subscription: subscription,
    controller: container.read(workoutControllerProvider.notifier),
  );
}

class _Harness {
  const _Harness({
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

class _ControlledPoseDetector implements PoseDetector {
  final Queue<Future<List<Pose>> Function()> _outcomes =
      Queue<Future<List<Pose>> Function()>();
  int processCallCount = 0;

  void enqueuePoses(List<Pose> poses) {
    _outcomes.add(() => Future<List<Pose>>.value(poses));
  }

  void enqueueError(Object error) {
    _outcomes.add(() => Future<List<Pose>>.error(error, StackTrace.current));
  }

  void enqueueFuture(Future<List<Pose>> outcome) {
    _outcomes.add(() => outcome);
  }

  @override
  Future<List<Pose>> processImage(InputImage inputImage) {
    processCallCount++;
    if (_outcomes.isEmpty) {
      throw StateError('No queued detector outcome.');
    }
    return _outcomes.removeFirst()();
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingFeedbackDelivery implements FeedbackDeliveryPort {
  int deliveredCount = 0;
  int stopCount = 0;

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    deliveredCount++;
    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
    );
  }

  @override
  void reset() {}

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _NoopFeedbackDelivery implements FeedbackDeliveryPort {
  const _NoopFeedbackDelivery();

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
    );
  }

  @override
  void reset() {}

  @override
  Future<void> stop() async {}
}
