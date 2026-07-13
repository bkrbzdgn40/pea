import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/camera_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
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
