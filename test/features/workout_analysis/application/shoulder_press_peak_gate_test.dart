import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('Shoulder Press peak entry gate', () {
    test('bilateral overhead lockout still completes a clean rep', () {
      final clock = _TestClock();
      final coordinator = _buildShoulderPressCoordinator(clock);

      _pumpFrames(
        coordinator,
        clock,
        leftAngle: 90,
        rightAngle: 90,
        leftWristAboveShoulder: false,
        rightWristAboveShoulder: false,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      _driveUntilPhase(
        coordinator,
        clock,
        leftAngle: 135,
        rightAngle: 135,
        leftWristAboveShoulder: true,
        rightWristAboveShoulder: true,
        expectedPhase: 'DESCENDING',
      );
      _driveUntilPhase(
        coordinator,
        clock,
        leftAngle: 165,
        rightAngle: 165,
        leftWristAboveShoulder: true,
        rightWristAboveShoulder: true,
        expectedPhase: 'PEAK',
      );
      _driveUntilPhase(
        coordinator,
        clock,
        leftAngle: 135,
        rightAngle: 135,
        leftWristAboveShoulder: true,
        rightWristAboveShoulder: true,
        expectedPhase: 'ASCENDING',
      );
      final completed = _driveUntilPhase(
        coordinator,
        clock,
        leftAngle: 90,
        rightAngle: 90,
        leftWristAboveShoulder: false,
        rightWristAboveShoulder: false,
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      expect(completed.stateSnapshot.repCount, 1);
    });

    test(
      'alternating single-arm lockouts with zero overhead overlap never complete a bilateral rep',
      () {
        final clock = _TestClock();
        final coordinator = _buildShoulderPressCoordinator(clock);

        _pumpFrames(
          coordinator,
          clock,
          leftAngle: 90,
          rightAngle: 90,
          leftWristAboveShoulder: false,
          rightWristAboveShoulder: false,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );

        for (var cycle = 0; cycle < 3; cycle++) {
          _driveUntilPhase(
            coordinator,
            clock,
            leftAngle: 135,
            rightAngle: 175,
            leftWristAboveShoulder: true,
            rightWristAboveShoulder: false,
            expectedPhase: 'DESCENDING',
          );
          final leftOnlyPeak = _holdFramesExpectingPhase(
            coordinator,
            clock,
            leftAngle: 165,
            rightAngle: 175,
            leftWristAboveShoulder: true,
            rightWristAboveShoulder: false,
            expectedPhase: 'DESCENDING',
          );
          expect(leftOnlyPeak.stateSnapshot.repCount, 0);

          _driveUntilPhase(
            coordinator,
            clock,
            leftAngle: 90,
            rightAngle: 90,
            leftWristAboveShoulder: false,
            rightWristAboveShoulder: false,
            expectedPhase: 'NEUTRAL',
            spacing: const Duration(milliseconds: 120),
          );

          _driveUntilPhase(
            coordinator,
            clock,
            leftAngle: 175,
            rightAngle: 135,
            leftWristAboveShoulder: false,
            rightWristAboveShoulder: true,
            expectedPhase: 'DESCENDING',
          );
          final rightOnlyPeak = _holdFramesExpectingPhase(
            coordinator,
            clock,
            leftAngle: 175,
            rightAngle: 165,
            leftWristAboveShoulder: false,
            rightWristAboveShoulder: true,
            expectedPhase: 'DESCENDING',
          );
          expect(rightOnlyPeak.stateSnapshot.repCount, 0);

          final recovered = _driveUntilPhase(
            coordinator,
            clock,
            leftAngle: 90,
            rightAngle: 90,
            leftWristAboveShoulder: false,
            rightWristAboveShoulder: false,
            expectedPhase: 'NEUTRAL',
            spacing: const Duration(milliseconds: 120),
          );
          expect(recovered.stateSnapshot.repCount, 0);
        }
      },
    );
  });
}

DefaultRangeRepCoordinator _buildShoulderPressCoordinator(_TestClock clock) {
  final config = loadExerciseConfig(
    'assets/config/exercises/shoulder_press.json',
  );
  final engine = const AnalysisEngineFactory().createRangeRep(
    config: config,
    rangeRepContract: RangeRepContracts.shoulderPress,
    now: clock.now,
  );

  return DefaultRangeRepCoordinator(
    engine: engine,
    config: config,
    rangeRepContract: RangeRepContracts.shoulderPress,
    rangeRepValidationConfig: const RangeRepValidationConfig(
      minAcceptableRomDelta: 25,
      minDescentMillis: 250,
      minAscentMillis: 300,
      allowLowConfidenceOnCoverageLoss: true,
    ),
  );
}

RangeRepCoordinatorFrameResult _driveUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  required bool leftWristAboveShoulder,
  required bool rightWristAboveShoulder,
  required String expectedPhase,
  Duration spacing = const Duration(milliseconds: 90),
  int maxFrames = 12,
}) {
  for (var index = 0; index < maxFrames; index++) {
    final result = _processFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftWristAboveShoulder: leftWristAboveShoulder,
      rightWristAboveShoulder: rightWristAboveShoulder,
    );
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return result;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  final terminal = _processFrame(
    coordinator,
    clock,
    leftAngle: leftAngle,
    rightAngle: rightAngle,
    leftWristAboveShoulder: leftWristAboveShoulder,
    rightWristAboveShoulder: rightWristAboveShoulder,
  );
  throw TestFailure(
    'Expected phase $expectedPhase, got ${terminal.stateSnapshot.currentPhase}',
  );
}

RangeRepCoordinatorFrameResult _holdFramesExpectingPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  required bool leftWristAboveShoulder,
  required bool rightWristAboveShoulder,
  required String expectedPhase,
  int count = 5,
  Duration spacing = const Duration(milliseconds: 90),
}) {
  late RangeRepCoordinatorFrameResult result;
  for (var index = 0; index < count; index++) {
    result = _processFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftWristAboveShoulder: leftWristAboveShoulder,
      rightWristAboveShoulder: rightWristAboveShoulder,
    );
    expect(result.stateSnapshot.currentPhase, expectedPhase);
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
  return result;
}

void _pumpFrames(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  required bool leftWristAboveShoulder,
  required bool rightWristAboveShoulder,
  required int count,
  required Duration spacing,
}) {
  for (var index = 0; index < count; index++) {
    _processFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftWristAboveShoulder: leftWristAboveShoulder,
      rightWristAboveShoulder: rightWristAboveShoulder,
    );
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

RangeRepCoordinatorFrameResult _processFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  required bool leftWristAboveShoulder,
  required bool rightWristAboveShoulder,
}) {
  return coordinator.processFrame(
    metrics: _shoulderPressMetrics(
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftWristAboveShoulder: leftWristAboveShoulder,
      rightWristAboveShoulder: rightWristAboveShoulder,
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{
      RangeRepSide.left,
      RangeRepSide.right,
    },
    preferredRangeRepSide: null,
  );
}

ExerciseMetrics _shoulderPressMetrics({
  required double leftAngle,
  required double rightAngle,
  required bool leftWristAboveShoulder,
  required bool rightWristAboveShoulder,
}) {
  final primaryAngle = leftAngle < rightAngle ? leftAngle : rightAngle;
  final syncScore = 180 - (leftAngle - rightAngle).abs();
  final landmarks = <PoseLandmark>[
    buildLandmark(PoseLandmarkType.leftShoulder, -1, 0),
    buildLandmark(PoseLandmarkType.leftElbow, -1, 1),
    buildLandmark(
      PoseLandmarkType.leftWrist,
      -1,
      leftWristAboveShoulder ? -2 : 2,
    ),
    buildLandmark(PoseLandmarkType.rightShoulder, 1, 0),
    buildLandmark(PoseLandmarkType.rightElbow, 1, 1),
    buildLandmark(
      PoseLandmarkType.rightWrist,
      1,
      rightWristAboveShoulder ? -2 : 2,
    ),
  ];

  return ExerciseMetrics(
    primaryAngle: primaryAngle,
    formMetric: 90,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: landmarks,
    leftRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.left,
      primaryAngle: leftAngle,
      formMetric: 90,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      sideConfidence: 0.95,
    ),
    rightRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.right,
      primaryAngle: rightAngle,
      formMetric: 90,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      sideConfidence: 0.95,
    ),
    bilateralRangeRepMetrics: RangeRepBilateralMetrics(
      primaryAngle: primaryAngle,
      formMetric: 90,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      leftPrimaryAngle: leftAngle,
      rightPrimaryAngle: rightAngle,
      leftFormScore: 90,
      rightFormScore: 90,
      syncScore: syncScore,
    ),
  );
}

class _TestClock {
  DateTime _current = DateTime.utc(2030, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
