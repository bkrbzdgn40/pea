import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/feedback_delivery_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  late ProviderContainer container;
  late WorkoutController controller;
  late ProviderSubscription<WorkoutState> controllerSubscription;
  late _RecordingFeedbackDelivery feedbackDelivery;

  setUp(() {
    feedbackDelivery = _RecordingFeedbackDelivery();
    container = ProviderContainer(
      overrides: <Override>[
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
        poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
        feedbackDeliveryProvider.overrideWithValue(feedbackDelivery),
      ],
    );
    addTearDown(container.dispose);
    controllerSubscription = container.listen<WorkoutState>(
      workoutControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(controllerSubscription.close);
    controller = container.read(workoutControllerProvider.notifier);
  });

  test('controller exposes an initial diagnostics snapshot', () {
    final snapshot = controller.diagnosticsSnapshot();
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisAttemptCount, 0);
    expect(snapshot.analysisCompletedCount, 0);
    expect(snapshot.currentPhase, rangeRepAwaitNeutralPhaseLabel);
  });

  test('synthetic metrics use production post-metrics path only', () {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(primaryAngle: 170),
      now: DateTime.utc(2030, 1, 1),
    );

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();
    expect(state.currentAngle, 170);
    expect(state.currentPhase, rangeRepAwaitNeutralPhaseLabel);
    expect(snapshot.repCount, state.repCount);
    expect(snapshot.currentPhase, state.currentPhase);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisAttemptCount, 0);
  });

  test('published range-rep feedback is forwarded to the delivery port', () {
    controller.processExerciseMetricsForTesting(
      metrics: const ExerciseMetrics.noPose(),
      now: DateTime.utc(2030, 1, 1),
    );

    expect(feedbackDelivery.cues, hasLength(1));
    expect(feedbackDelivery.cues.single.id, startsWith('range:'));
    expect(feedbackDelivery.cues.single.message, isNotEmpty);
    expect(feedbackDelivery.cues.single.kind, FeedbackDeliveryKind.blocking);
  });

  test('no-pose metrics preserve the existing waiting state behavior', () {
    controller.processExerciseMetricsForTesting(
      metrics: const ExerciseMetrics.noPose(),
      now: DateTime.utc(2030, 1, 1),
    );

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();
    expect(state.repCount, 0);
    expect(state.currentHoldSeconds, 0);
    expect(state.isHolding, isFalse);
    expect(state.currentPhase, 'WAITING');
    expect(snapshot.repCount, 0);
    expect(snapshot.currentPhase, 'WAITING');
    expect(snapshot.cameraFrameCount, 0);
  });

  test('reset clears diagnostics only and keeps controller state', () {
    final base = DateTime.utc(2030, 1, 1);
    for (var index = 0; index < 4; index++) {
      controller.processExerciseMetricsForTesting(
        metrics: const ExerciseMetrics.noPose(),
        now: base.add(Duration(milliseconds: index * 200)),
      );
    }
    expect(controller.diagnosticsSnapshot().resyncCount, 0);
    final stateBeforeReset = container.read(workoutControllerProvider);

    final resetAt = DateTime.utc(2030, 1, 2);
    controller.resetDiagnostics(now: resetAt);
    final stateAfterReset = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot(
      now: resetAt.add(const Duration(seconds: 2)),
    );

    expect(identical(stateAfterReset, stateBeforeReset), isTrue);
    expect(snapshot.sessionStartedAt, resetAt);
    expect(snapshot.elapsedMs, 2000);
    expect(snapshot.resyncCount, 0);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.repCount, stateBeforeReset.repCount);
    expect(snapshot.currentPhase, stateBeforeReset.currentPhase);
  });

  test('invalid frames cannot finish neutral arming confirmation', () async {
    final timeline = _ControllerTimeline();

    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(primaryAngle: 170),
      now: timeline.current,
    );
    controller.processExerciseMetricsForTesting(
      metrics: const ExerciseMetrics.noPose(),
      now: timeline.advance(const Duration(milliseconds: 10)),
    );

    await Future<void>.delayed(const Duration(milliseconds: 130));

    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(primaryAngle: 170),
      now: timeline.advance(const Duration(milliseconds: 130)),
    );

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();

    expect(state.repCount, 0);
    expect(state.currentPhase, rangeRepAwaitNeutralPhaseLabel);
    expect(snapshot.currentPhase, rangeRepAwaitNeutralPhaseLabel);
  });

  testWidgets(
    'long visibility gap disarms a PEAK recovery and preserves 0 rep',
    (tester) async {
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

        controller.processExerciseMetricsForTesting(
          metrics: const ExerciseMetrics.noPose(),
          now: timeline.advance(const Duration(milliseconds: 500)),
        );
        controller.processExerciseMetricsForTesting(
          metrics: const ExerciseMetrics.noPose(),
          now: timeline.advance(const Duration(milliseconds: 500)),
        );
        controller.processExerciseMetricsForTesting(
          metrics: const ExerciseMetrics.noPose(),
          now: timeline.advance(const Duration(milliseconds: 500)),
        );
        controller.processExerciseMetricsForTesting(
          metrics: const ExerciseMetrics.noPose(),
          now: timeline.advance(const Duration(milliseconds: 500)),
        );

        await _pumpFrames(controller, timeline, primaryAngle: 90);
      });

      final resyncedSnapshot = controller.diagnosticsSnapshot();
      expect(resyncedSnapshot.resyncCount, 1);
      expect(resyncedSnapshot.analysisExceptionCount, 0);

      var state = container.read(workoutControllerProvider);
      expect(state.currentPhase, rangeRepAwaitNeutralPhaseLabel);
      expect(state.repCount, 0);

      await tester.runAsync(() async {
        await _pumpFrames(controller, timeline, primaryAngle: 170);
      });

      state = container.read(workoutControllerProvider);
      expect(state.repCount, 0);
    },
  );
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

class _RecordingFeedbackDelivery implements FeedbackDeliveryPort {
  final List<FeedbackDeliveryCue> cues = <FeedbackDeliveryCue>[];

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    cues.add(cue);
    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
      hapticPattern: FeedbackHapticPattern.none,
    );
  }

  @override
  void reset() {
    cues.clear();
  }

  @override
  Future<void> stop() async {}
}
