import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/exercise_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';

void main() {
  group('ExerciseEngine squat state machine', () {
    test('counts a completed squat rep', () {
      fakeAsync((async) {
        final engine = ExerciseEngine(config: _squatConfig());

        _confirmTransition(async, engine, angle: 140);
        _confirmTransition(async, engine, angle: 90);
        _confirmTransition(async, engine, angle: 110);
        _confirmTransition(
          async,
          engine,
          angle: 170,
          confirmationWindow: const Duration(milliseconds: 101),
        );

        expect(engine.repCount, 1);
        expect(engine.phaseLabel, 'NEUTRAL');
        expect(engine.lastRepScoreBreakdown, isNotNull);
      });
    });

    test('does not count an aborted descent', () {
      fakeAsync((async) {
        final engine = ExerciseEngine(config: _squatConfig());

        _confirmTransition(async, engine, angle: 140);
        _confirmTransition(
          async,
          engine,
          angle: 170,
          confirmationWindow: const Duration(milliseconds: 101),
        );

        expect(engine.repCount, 0);
        expect(engine.phaseLabel, 'NEUTRAL');
        expect(engine.lastRepScoreBreakdown, isNull);
      });
    });

    test('penalizes the final score when form breaks during the rep', () {
      fakeAsync((async) {
        final cleanEngine = ExerciseEngine(config: _squatConfig());
        _completeSquatRep(async, cleanEngine);

        final violatedEngine = ExerciseEngine(config: _squatConfig());
        _completeSquatRep(async, violatedEngine, repBackAngle: 40);

        expect(cleanEngine.repCount, 1);
        expect(violatedEngine.repCount, 1);
        expect(violatedEngine.lastRepScore, lessThan(cleanEngine.lastRepScore));
        expect(
          violatedEngine.lastRepScoreBreakdown?.hadFormViolation,
          isTrue,
        );
      });
    });

    test(
      'clearActiveRepContext clears active rep state but keeps session rep history',
      () {
        fakeAsync((async) {
          final engine = ExerciseEngine(config: _squatConfig());
          _completeSquatRep(async, engine);
          final completedScore = engine.lastRepScore;

          _confirmTransition(async, engine, angle: 140);
          expect(engine.phaseLabel, 'DESCENDING');

          engine.clearActiveRepContext(reason: 'side switch');

          expect(engine.repCount, 1);
          expect(engine.phaseLabel, 'NEUTRAL');
          expect(engine.lastRepScore, completedScore);
          expect(engine.lastRepScoreBreakdown, isNotNull);
          expect(
            engine.diagnosticsSnapshot.currentRepWorstBackAngle,
            equals(180.0),
          );
        });
      },
    );
  });
}

void _completeSquatRep(
  FakeAsync async,
  ExerciseEngine engine, {
  double repBackAngle = 60,
}) {
  _confirmTransition(async, engine, angle: 140, backAngle: repBackAngle);
  _confirmTransition(async, engine, angle: 90, backAngle: repBackAngle);
  _confirmTransition(async, engine, angle: 110, backAngle: repBackAngle);
  _confirmTransition(
    async,
    engine,
    angle: 170,
    backAngle: repBackAngle,
    confirmationWindow: const Duration(milliseconds: 101),
  );
}

void _confirmTransition(
  FakeAsync async,
  ExerciseEngine engine, {
  required double angle,
  double backAngle = 60,
  Duration confirmationWindow = const Duration(milliseconds: 81),
}) {
  engine.update(_frame(angle, backAngle));
  async.elapse(confirmationWindow);
  engine.update(_frame(angle, backAngle));
}

AnalysisFrame _frame(double angle, double backAngle) {
  return AnalysisFrame(primaryMetric: angle, formMetric: backAngle);
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
    idealDescentSeconds: 1.5,
    idealAscentSeconds: 1.0,
    formThreshold: 45.0,
    targetMinAngle: 70.0,
    tempoPenaltyPerSecond: 20.0,
  );
}
