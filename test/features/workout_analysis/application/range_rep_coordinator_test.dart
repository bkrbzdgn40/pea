import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

void main() {
  group('DefaultRangeRepCoordinator', () {
    test('drives the real range-rep engine through a validated clean rep', () {
      final clock = _TestClock();
      final coordinator = _buildCoordinator(clock);

      _pumpAcceptedFrames(
        coordinator,
        clock,
        angle: 170,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      final descendingResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 140,
        expectedPhase: 'DESCENDING',
      );
      final peakResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 90,
        expectedPhase: 'PEAK',
      );
      final ascendingResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 110,
        expectedPhase: 'ASCENDING',
      );
      final completedResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 170,
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      expect(descendingResult.stateSnapshot.currentPhase, 'DESCENDING');
      expect(peakResult.stateSnapshot.currentPhase, 'PEAK');
      expect(ascendingResult.stateSnapshot.currentPhase, 'ASCENDING');
      expect(completedResult.stateSnapshot.repCount, 1);
      expect(completedResult.stateSnapshot.currentPhase, 'NEUTRAL');
      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        'valid',
      );
      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepSummaryCompletedPhaseSequence,
        isTrue,
      );
      expect(
        completedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
        'left',
      );
      expect(completedResult.diagnosticsUpdate.recordAcceptedPoseFrame, isTrue);
    });

    test(
      'lifecycle interruption clears coordinator-owned side state and forces '
      'fresh neutral reacquisition',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        final descendingResult = _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );
        final interrupted = coordinator.handleLifecycleInterruption(
          reason: 'paused',
        );

        expect(descendingResult.stateSnapshot.currentPhase, 'DESCENDING');
        expect(coordinator.diagnosticsState().selectedSideLabel, isNull);
        expect(coordinator.diagnosticsState().hasActiveRepContext, isFalse);
        expect(interrupted.currentPhase, rangeRepAwaitNeutralPhaseLabel);
        final postInterruptionResult = _processAcceptedFrame(
          coordinator,
          clock,
          angle: 90,
        );
        expect(
          postInterruptionResult.stateSnapshot.currentPhase,
          'AWAITING_NEUTRAL',
        );
        expect(postInterruptionResult.stateSnapshot.repCount, 0);
      },
    );

    test(
      'locks the previously selected side while an active rep context is in progress',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );

        final lockedResult = coordinator.processFrame(
          metrics: _sideFilteredMetrics(
            leftAngle: 140,
            rightAngle: 95,
            leftAvailable: false,
            rightAvailable: true,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          lockedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'left',
        );
        expect(lockedResult.stateSnapshot.currentPhase, 'WAITING');
        expect(lockedResult.diagnosticsUpdate.selectedSideLabel, 'left');
      },
    );

    test(
      'does not keep the previous side locked while only neutral acquisition is pending',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 2,
          spacing: const Duration(milliseconds: 120),
        );

        final switchedResult = coordinator.processFrame(
          metrics: _sideFilteredMetrics(
            leftAngle: 170,
            rightAngle: 95,
            leftAvailable: false,
            rightAvailable: true,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          switchedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'right',
        );
        expect(switchedResult.diagnosticsUpdate.selectedSideLabel, 'right');
      },
    );
  });
}

DefaultRangeRepCoordinator _buildCoordinator(_TestClock clock) {
  final config = _squatConfig();
  final engine = const AnalysisEngineFactory().create(
    engineKind: EngineKind.rangeRep,
    config: config,
    rangeRepContract: RangeRepContracts.squat,
    now: clock.now,
  );

  return DefaultRangeRepCoordinator(
    engine: engine,
    config: config,
    rangeRepContract: RangeRepContracts.squat,
  );
}

RangeRepCoordinatorFrameResult _driveUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  required String expectedPhase,
  Duration spacing = const Duration(milliseconds: 90),
  int maxFrames = 12,
}) {
  for (var index = 0; index < maxFrames; index++) {
    final result = _processAcceptedFrame(coordinator, clock, angle: angle);
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return result;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  final terminalResult = _processAcceptedFrame(
    coordinator,
    clock,
    angle: angle,
  );
  throw TestFailure(
    'Expected phase $expectedPhase, got '
    '${terminalResult.stateSnapshot.currentPhase}',
  );
}

void _pumpAcceptedFrames(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  required int count,
  required Duration spacing,
}) {
  for (var index = 0; index < count; index++) {
    _processAcceptedFrame(coordinator, clock, angle: angle);
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

RangeRepCoordinatorFrameResult _processAcceptedFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  double formMetric = 60.0,
}) {
  return coordinator.processFrame(
    metrics: _leftRangeRepMetrics(angle: angle, formMetric: formMetric),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
  );
}

ExerciseMetrics _leftRangeRepMetrics({
  required double angle,
  required double formMetric,
}) {
  return _sideFilteredMetrics(
    leftAngle: angle,
    rightAngle: 180.0,
    leftAvailable: true,
    rightAvailable: false,
    formMetric: formMetric,
  );
}

ExerciseMetrics _sideFilteredMetrics({
  required double leftAngle,
  required double rightAngle,
  required bool leftAvailable,
  required bool rightAvailable,
  double formMetric = 60.0,
}) {
  final leftMetrics = leftAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.left,
          primaryAngle: leftAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 1.0,
        )
      : const RangeRepSideMetrics.unavailable(RangeRepSide.left);
  final rightMetrics = rightAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.right,
          primaryAngle: rightAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 1.0,
        )
      : const RangeRepSideMetrics.unavailable(RangeRepSide.right);

  return ExerciseMetrics(
    primaryAngle: leftAvailable ? leftAngle : rightAngle,
    formMetric: formMetric,
    hasPrimaryAngle: leftAvailable || rightAvailable,
    hasFormMetric: leftAvailable || rightAvailable,
    hasPose: true,
    landmarks: const [],
    leftRangeRepMetrics: leftMetrics,
    rightRangeRepMetrics: rightMetrics,
  );
}

ExerciseConfig _squatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
    formThreshold: 45.0,
    targetMinAngle: 70.0,
    idealDescentSeconds: 1.5,
    idealAscentSeconds: 1.0,
    tempoPenaltyPerSecond: 20.0,
  );
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
