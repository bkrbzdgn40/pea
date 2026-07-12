import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  late ProviderContainer container;
  late WorkoutController controller;

  setUp(() {
    container = ProviderContainer(
      overrides: <Override>[
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
        exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
        poseDetectorProvider.overrideWith((ref) => _FakePoseDetector()),
      ],
    );
    addTearDown(container.dispose);
    container.read(workoutControllerProvider);
    controller = container.read(workoutControllerProvider.notifier);
  });

  test('controller exposes an initial diagnostics snapshot', () {
    final snapshot = controller.diagnosticsSnapshot();
    expect(snapshot.analysisKind, 'rangeRep');
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisAttemptCount, 0);
    expect(snapshot.analysisCompletedCount, 0);
  });

  test('synthetic metrics use production post-metrics path only', () {
    controller.processExerciseMetricsForTesting(
      metrics: _validMetrics(primaryAngle: 170),
      now: DateTime.utc(2030, 1, 1),
    );

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();
    expect(state.currentAngle, 170);
    expect(state.currentPhase, 'NEUTRAL');
    expect(snapshot.repCount, state.repCount);
    expect(snapshot.currentPhase, state.currentPhase);
    expect(snapshot.cameraFrameCount, 0);
    expect(snapshot.analysisAttemptCount, 0);
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
    expect(controller.diagnosticsSnapshot().resyncCount, 1);
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
}

ExerciseMetrics _validMetrics({required double primaryAngle}) {
  final left = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryAngle,
    formMetric: 170,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1,
    formSignals: RangeRepFormSignals(
      torsoAngle: 170,
      depthMetric: primaryAngle,
      alignmentMetric: 170,
      lockoutMetric: primaryAngle,
    ),
  );
  return ExerciseMetrics(
    primaryAngle: primaryAngle,
    formMetric: 170,
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
