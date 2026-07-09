import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';

void main() {
  group('RangeRepEngine squat state machine', () {
    test('counts a completed squat rep', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(
        config: _squatConfig(),
        now: clock.now,
      );

      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(clock, engine, angle: 90);
      _confirmTransition(clock, engine, angle: 110);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: const Duration(milliseconds: 101),
      );

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNotNull);
    });

    test('does not count an aborted descent', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(
        config: _squatConfig(),
        now: clock.now,
      );

      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: const Duration(milliseconds: 101),
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNull);
    });

    test('penalizes the final score when form breaks during the rep', () {
      final cleanClock = _TestClock();
      final cleanEngine = RangeRepEngine(
        config: _squatConfig(),
        now: cleanClock.now,
      );
      _completeSquatRep(cleanClock, cleanEngine);

      final violatedClock = _TestClock();
      final violatedEngine = RangeRepEngine(
        config: _squatConfig(),
        now: violatedClock.now,
      );
      _completeSquatRep(violatedClock, violatedEngine, repBackAngle: 40);

      expect(cleanEngine.repCount, 1);
      expect(violatedEngine.repCount, 1);
      expect(violatedEngine.lastRepScore, lessThan(cleanEngine.lastRepScore));
      expect(
        violatedEngine.lastRepScoreBreakdown?.hadFormViolation,
        isTrue,
      );
    });

    test(
      'clearActiveRepContext clears active rep state but keeps session rep history',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(
          config: _squatConfig(),
          now: clock.now,
        );

        _completeSquatRep(clock, engine);
        final completedScore = engine.lastRepScore;

        _confirmTransition(clock, engine, angle: 140);
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
      },
    );

    test('completed rep exposes core data exactly once', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(
        config: _squatConfig(),
        now: clock.now,
      );

      _completeSquatRep(clock, engine);

      final diagnosticsCoreData = engine.diagnosticsSnapshot.lastCompletedRepCoreData;
      final consumedCoreData = engine.consumeCompletedRepCoreData();

      expect(engine.repCount, 1);
      expect(engine.lastRepScoreBreakdown, isNotNull);
      expect(diagnosticsCoreData, isNotNull);
      expect(consumedCoreData, isNotNull);
      expect(consumedCoreData?.repIndex, 1);
      expect(consumedCoreData?.repIndex, diagnosticsCoreData?.repIndex);
      expect(engine.consumeCompletedRepCoreData(), isNull);
    });

    test('applies phase-aware penalty and feedback when descent quality is flagged', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(
        config: _squatConfig(
          phaseQuality: const RangeRepPhaseQualityConfig(
            minDescendingMillis: 1000,
          ),
        ),
        now: clock.now,
      );

      _completeSquatRep(clock, engine);

      final breakdown = engine.lastRepScoreBreakdown;
      final diagnostics = engine.diagnosticsSnapshot;

      expect(engine.repCount, 1);
      expect(breakdown, isNotNull);
      expect(breakdown?.phaseQualityPenalty, 5.0);
      expect(breakdown?.phaseAdjustedScore, isNotNull);
      expect(
        breakdown!.phaseAdjustedScore!,
        lessThan(breakdown.runtimeBaseScore),
      );
      expect(engine.feedbackCode, RangeRepFeedbackCode.controlDescent);
      expect(
        diagnostics.phaseFeedbackCandidate,
        RangeRepFeedbackCode.controlDescent.code,
      );
    });
  });
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

void _completeSquatRep(
  _TestClock clock,
  RangeRepEngine engine, {
  double repBackAngle = 60,
}) {
  _confirmTransition(clock, engine, angle: 140, backAngle: repBackAngle);
  _confirmTransition(clock, engine, angle: 90, backAngle: repBackAngle);
  _confirmTransition(clock, engine, angle: 110, backAngle: repBackAngle);
  _confirmTransition(
    clock,
    engine,
    angle: 170,
    backAngle: repBackAngle,
    confirmationWindow: const Duration(milliseconds: 101),
  );
}

void _confirmTransition(
  _TestClock clock,
  RangeRepEngine engine, {
  required double angle,
  double backAngle = 60,
  Duration confirmationWindow = const Duration(milliseconds: 81),
}) {
  engine.update(_frame(angle, backAngle));
  clock.advance(confirmationWindow);
  engine.update(_frame(angle, backAngle));
}

AnalysisFrame _frame(double angle, double backAngle) {
  return AnalysisFrame(primaryMetric: angle, formMetric: backAngle);
}

ExerciseConfig _squatConfig({
  RangeRepPhaseQualityConfig? phaseQuality,
}) {
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
    rangeRepPhaseQuality: phaseQuality,
  );
}
