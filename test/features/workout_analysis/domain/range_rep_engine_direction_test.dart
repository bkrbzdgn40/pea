import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';

void main() {
  test('increasing-to-peak direction completes one full rep', () {
    final clock = _Clock();
    final engine = RangeRepEngine(
      config: ExerciseConfig(
        name: 'Lateral Raise Test',
        primaryJoint: PoseLandmarkType.leftShoulder,
        joint1: PoseLandmarkType.leftElbow,
        joint2: PoseLandmarkType.leftHip,
        thresholdNeutral: 20,
        thresholdActive: 35,
        thresholdPeak: 80,
        targetMaxAngle: 90,
      ),
      primaryMetricDirection: RangeRepPrimaryMetricDirection.increasingToPeak,
      now: clock.now,
    );

    _confirm(clock, engine, 10, 120);
    expect(engine.phaseLabel, 'NEUTRAL');

    _confirm(clock, engine, 45, 100);
    expect(engine.phaseLabel, 'DESCENDING');

    _confirm(clock, engine, 90, 100);
    expect(engine.phaseLabel, 'PEAK');

    _confirm(clock, engine, 65, 100);
    expect(engine.phaseLabel, 'ASCENDING');

    final completionResult = _confirm(clock, engine, 10, 120);
    expect(engine.phaseLabel, 'NEUTRAL');
    expect(engine.repCount, 1);
    expect(completionResult.completedRepDetectionData, isNotNull);
    expect(completionResult.completedRepDetectionData!.startAngle, 45);
    expect(
      completionResult.completedRepDetectionData!.primaryRom,
      closeTo(45, 0.001),
    );
  });

  test(
    'lateral raise accepts a natural 29-degree neutral and completes the rep',
    () {
      final clock = _Clock();
      final engine = RangeRepEngine(
        config: ExerciseConfig(
          name: 'Lateral Raise Natural Neutral Test',
          primaryJoint: PoseLandmarkType.leftShoulder,
          joint1: PoseLandmarkType.leftElbow,
          joint2: PoseLandmarkType.leftHip,
          thresholdNeutral: 32,
          thresholdActive: 35,
          thresholdPeak: 80,
          targetMaxAngle: 90,
        ),
        primaryMetricDirection: RangeRepPrimaryMetricDirection.increasingToPeak,
        now: clock.now,
      );

      _confirm(clock, engine, 29, 120);
      expect(engine.phaseLabel, 'NEUTRAL');

      _confirm(clock, engine, 45, 100);
      expect(engine.phaseLabel, 'DESCENDING');

      _confirm(clock, engine, 90, 100);
      expect(engine.phaseLabel, 'PEAK');

      _confirm(clock, engine, 65, 100);
      expect(engine.phaseLabel, 'ASCENDING');

      final completionResult = _confirm(clock, engine, 29, 120);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 1);
      expect(completionResult.completedRepDetectionData, isNotNull);
    },
  );

  test('publishes centralized tempo facts and session summary', () {
    final clock = _Clock();
    final engine = RangeRepEngine(
      config: ExerciseConfig(
        name: 'Shoulder Press Tempo Test',
        primaryJoint: PoseLandmarkType.leftElbow,
        joint1: PoseLandmarkType.leftShoulder,
        joint2: PoseLandmarkType.leftWrist,
        thresholdNeutral: 70,
        thresholdActive: 100,
        thresholdPeak: 150,
        targetMaxAngle: 165,
      ),
      primaryMetricDirection: RangeRepPrimaryMetricDirection.increasingToPeak,
      towardPeakMuscleAction: RangeRepTowardPeakMuscleAction.concentric,
      now: clock.now,
    );

    _confirm(clock, engine, 60, 120);
    _confirm(clock, engine, 110, 100);
    _confirm(clock, engine, 160, 100);
    _confirm(clock, engine, 130, 100);
    final completionResult = _confirm(clock, engine, 60, 120);

    final tempo = completionResult.completedTempo;
    expect(tempo, isNotNull);
    expect(tempo!.concentricDuration.inMilliseconds, 100);
    expect(tempo.bottomPauseDuration.inMilliseconds, 100);
    expect(tempo.eccentricDuration.inMilliseconds, 100);
    expect(tempo.topPauseDuration.inMilliseconds, 120);
    expect(tempo.totalRepDuration.inMilliseconds, 300);

    final sessionTempo = engine.tempoSessionSummary;
    expect(sessionTempo.repCount, 1);
    expect(sessionTempo.averageRepDuration.inMilliseconds, 300);
    expect(sessionTempo.fastestRepDuration.inMilliseconds, 300);
    expect(sessionTempo.slowestRepDuration.inMilliseconds, 300);
    expect(sessionTempo.consistencyScore, 100);
  });
}

RangeRepEngineFrameResult _confirm(
  _Clock clock,
  RangeRepEngine engine,
  double metric,
  int milliseconds,
) {
  engine.updateDetectionFrame(primaryMetric: metric);
  clock.advance(Duration(milliseconds: milliseconds));
  return engine.updateDetectionFrame(primaryMetric: metric);
}

class _Clock {
  DateTime value = DateTime(2026, 1, 1);

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
