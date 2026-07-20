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
