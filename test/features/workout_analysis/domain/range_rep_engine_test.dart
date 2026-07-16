import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('RangeRepEngine squat state machine', () {
    test('starts disarmed and awaits a neutral acquisition gate', () {
      final engine = RangeRepEngine(
        config: _squatConfig(),
        now: _TestClock().now,
      );

      expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
      expect(engine.repCount, 0);
      expect(engine.feedbackCode, RangeRepFeedbackCode.awaitNeutral);
      expect(engine.diagnosticsSnapshot.hasActiveRepPhase, isFalse);
    });

    test('starting in PEAK does not count only the rise', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _confirmTransition(clock, engine, angle: 90);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNull);
    });

    test('starting in DESCENDING does not count the neutral return', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('neutral acquisition then a full rep counts exactly once', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _completeSquatRepAfterArming(clock, engine);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNotNull);
    });

    test('neutral acquisition does not itself create a rep', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test(
      'clearActiveRepContext clears active rep state, keeps history, and disarms',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

        _completeSquatRep(clock, engine);
        final completedScore = engine.lastRepScore;

        _acquireNeutral(clock, engine);
        _confirmTransition(clock, engine, angle: 140);
        expect(engine.phaseLabel, 'DESCENDING');

        engine.clearActiveRepContext(reason: 'side switch');

        expect(engine.repCount, 1);
        expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
        expect(engine.feedbackCode, RangeRepFeedbackCode.awaitNeutral);
        expect(engine.lastRepScore, completedScore);
        expect(engine.lastRepScoreBreakdown, isNotNull);
        expect(
          engine.diagnosticsSnapshot.currentRepWorstBackAngle,
          equals(180.0),
        );
      },
    );

    test('resync from PEAK cancels the half rep', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(clock, engine, angle: 90);

      engine.clearActiveRepContext(reason: 'visibility resync');

      _confirmTransition(clock, engine, angle: 90);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('a full rep after resync still works', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(clock, engine, angle: 90);

      engine.clearActiveRepContext(reason: 'visibility resync');

      _confirmTransition(clock, engine, angle: 90);
      _acquireNeutral(clock, engine);
      _completeSquatRepAfterArming(clock, engine);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('reset returns to the disarmed start behavior', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _completeSquatRep(clock, engine);

      engine.reset();

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
      expect(engine.feedbackCode, RangeRepFeedbackCode.awaitNeutral);

      _confirmTransition(clock, engine, angle: 90);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('pending neutral arming confirmation resets when neutral is lost', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      engine.update(_frame(170, 60));
      clock.advance(const Duration(milliseconds: 50));
      engine.update(_frame(170, 60));

      expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
      expect(engine.diagnosticsSnapshot.hasPendingTransition, isTrue);
      expect(
        engine.diagnosticsSnapshot.pendingTransitionLabel,
        rangeRepAwaitNeutralPendingTransitionLabel,
      );

      engine.update(_frame(140, 60));
      expect(engine.diagnosticsSnapshot.hasPendingTransition, isFalse);

      engine.update(_frame(170, 60));
      clock.advance(const Duration(milliseconds: 50));
      engine.update(_frame(170, 60));

      expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);

      clock.advance(const Duration(milliseconds: 60));
      engine.update(_frame(170, 60));

      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 0);
    });

    test('completed rep exposes core data exactly once', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _completeSquatRep(clock, engine);

      final diagnosticsCoreData =
          engine.diagnosticsSnapshot.lastCompletedRepCoreData;
      final consumedCoreData = engine.consumeCompletedRepCoreData();

      expect(engine.repCount, 1);
      expect(engine.lastRepScoreBreakdown, isNotNull);
      expect(diagnosticsCoreData, isNotNull);
      expect(consumedCoreData, isNotNull);
      expect(consumedCoreData?.repIndex, 1);
      expect(consumedCoreData?.repIndex, diagnosticsCoreData?.repIndex);
      expect(engine.consumeCompletedRepCoreData(), isNull);
    });

    test(
      'applies phase-aware penalty and feedback when descent quality is flagged',
      () {
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
      },
    );

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
      expect(violatedEngine.lastRepScoreBreakdown?.hadFormViolation, isTrue);
    });
  });

  group('RangeRepEngine push-up state machine', () {
    test('starting at the bottom does not count only the rise', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _pushUpConfig(), now: clock.now);

      _confirmTransition(clock, engine, angle: 90, backAngle: 170);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        backAngle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('neutral acquisition then a full push-up counts once', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _pushUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 170, backAngle: 170);
      _confirmTransition(clock, engine, angle: 130, backAngle: 170);
      _confirmTransition(clock, engine, angle: 90, backAngle: 170);
      _confirmTransition(clock, engine, angle: 110, backAngle: 170);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        backAngle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNotNull);
      expect(engine.lastRepScore, greaterThanOrEqualTo(0.0));
    });
  });

  group('RangeRepEngine sit-up state machine', () {
    test('real sit-up config characterizes the new threshold gates', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
      expect(engine.phaseLabel, 'NEUTRAL');

      _confirmTransition(clock, engine, angle: 115, backAngle: 90);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 0);

      _confirmTransition(clock, engine, angle: 108, backAngle: 90);
      expect(engine.phaseLabel, 'DESCENDING');

      _confirmTransition(clock, engine, angle: 75, backAngle: 90);
      expect(engine.phaseLabel, 'DESCENDING');

      _confirmTransition(clock, engine, angle: 68, backAngle: 90);
      expect(engine.phaseLabel, 'PEAK');

      _confirmTransition(clock, engine, angle: 82, backAngle: 90);
      expect(engine.phaseLabel, 'ASCENDING');

      _confirmTransition(
        clock,
        engine,
        angle: 121,
        backAngle: 90,
        confirmationWindow: _neutralConfirmationWindow,
      );
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 1);
    });

    test(
      'real sit-up config full rep counts once and produces a finite score',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

        _completeSitUpRep(clock, engine);

        expect(engine.repCount, 1);
        expect(engine.phaseLabel, 'NEUTRAL');
        expect(engine.lastRepScoreBreakdown, isNotNull);
        expect(engine.lastRepScore, inInclusiveRange(0.0, 100.0));
        expect(engine.lastRepRom, closeTo(68.0, 0.001));
        expect(engine.consumeCompletedRepCoreData()?.repIndex, 1);
      },
    );

    test('real sit-up config does not count a partial return before peak', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
      _confirmTransition(clock, engine, angle: 108, backAngle: 90);
      _confirmTransition(
        clock,
        engine,
        angle: 121,
        backAngle: 90,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNull);
    });

    test('two real sit-up cycles count twice without double counting', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _completeSitUpRep(clock, engine);
      _completeSitUpRep(clock, engine);

      expect(engine.repCount, 2);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.lastRepScoreBreakdown, isNotNull);
    });

    test(
      'peak hip flexion stays form-good when the independent knee metric stays healthy',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

        _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
        _confirmTransition(clock, engine, angle: 108, backAngle: 90);
        _confirmTransition(clock, engine, angle: 68, backAngle: 90);

        expect(engine.phaseLabel, 'PEAK');
        expect(engine.isFormBad, isFalse);
        expect(
          engine.feedbackCode,
          isNot(RangeRepFeedbackCode.keepBodyUpright),
        );
      },
    );

    test('low knee-angle form metric still triggers a real form violation', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 125, backAngle: 65);
      _confirmTransition(clock, engine, angle: 108, backAngle: 65);
      _confirmTransition(clock, engine, angle: 68, backAngle: 65);

      expect(engine.isFormBad, isTrue);
      expect(engine.diagnosticsSnapshot.currentRepHadFormViolation, isTrue);

      _confirmTransition(clock, engine, angle: 82, backAngle: 65);
      _confirmTransition(
        clock,
        engine,
        angle: 121,
        backAngle: 65,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(engine.repCount, 1);
      expect(engine.lastRepScoreBreakdown?.hadFormViolation, isTrue);
    });
  });

  group('RangeRepEngine brief visibility gap control', () {
    test('1000 ms PEAK gap resumes safely and preserves the rep', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(clock, engine, angle: 90);

      engine.beginBriefVisibilityGap();
      clock.advance(const Duration(milliseconds: 1000));

      final resume = engine.resumeAfterBriefVisibilityGap(_frame(90, 60));
      engine.update(_frame(90, 60));

      _confirmTransition(clock, engine, angle: 110);
      _confirmTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: _neutralConfirmationWindow,
      );

      expect(resume.isCompatible, isTrue);
      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('1000 ms unseen neutral return is incompatible', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      _confirmTransition(clock, engine, angle: 140);
      _confirmTransition(clock, engine, angle: 90);

      engine.beginBriefVisibilityGap();
      clock.advance(const Duration(milliseconds: 1000));

      final resume = engine.resumeAfterBriefVisibilityGap(_frame(170, 60));

      expect(resume.isCompatible, isFalse);
    });

    test('beginBriefVisibilityGap clears a pending transition', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _squatConfig(), now: clock.now);

      _acquireNeutral(clock, engine);
      engine.update(_frame(140, 60));

      expect(engine.diagnosticsSnapshot.hasPendingTransition, isTrue);

      engine.beginBriefVisibilityGap();

      expect(engine.diagnosticsSnapshot.hasPendingTransition, isFalse);
    });

    test('brief gap duration is excluded from active phase timing', () {
      final gapClock = _TestClock();
      final gapEngine = RangeRepEngine(
        config: _squatConfig(),
        now: gapClock.now,
      );
      _completeRepWithBriefDescendingGap(gapClock, gapEngine);

      expect(gapEngine.repCount, 1);
      expect(
        gapEngine.lastDescentTime.inMilliseconds,
        inInclusiveRange(400, 700),
      );
    });
  });
}

const Duration _transitionConfirmationWindow = Duration(milliseconds: 81);
const Duration _neutralConfirmationWindow = Duration(milliseconds: 101);

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
  _acquireNeutral(clock, engine, backAngle: repBackAngle);
  _completeSquatRepAfterArming(clock, engine, repBackAngle: repBackAngle);
}

void _completeSquatRepAfterArming(
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
    confirmationWindow: _neutralConfirmationWindow,
  );
}

void _completeRepWithBriefDescendingGap(
  _TestClock clock,
  RangeRepEngine engine,
) {
  _acquireNeutral(clock, engine);
  engine.update(_frame(140, 60));
  clock.advance(_transitionConfirmationWindow);
  engine.update(_frame(140, 60));
  clock.advance(const Duration(milliseconds: 200));
  engine.update(_frame(120, 60));
  engine.beginBriefVisibilityGap();
  clock.advance(const Duration(milliseconds: 1000));
  final resume = engine.resumeAfterBriefVisibilityGap(_frame(120, 60));
  expect(resume.isCompatible, isTrue);
  engine.update(_frame(120, 60));
  clock.advance(const Duration(milliseconds: 200));
  engine.update(_frame(90, 60));
  clock.advance(_transitionConfirmationWindow);
  engine.update(_frame(90, 60));
  _confirmTransition(clock, engine, angle: 110);
  _confirmTransition(
    clock,
    engine,
    angle: 170,
    confirmationWindow: _neutralConfirmationWindow,
  );
}

void _acquireNeutral(
  _TestClock clock,
  RangeRepEngine engine, {
  double angle = 170,
  double backAngle = 60,
}) {
  _confirmTransition(
    clock,
    engine,
    angle: angle,
    backAngle: backAngle,
    confirmationWindow: _neutralConfirmationWindow,
  );
}

void _confirmTransition(
  _TestClock clock,
  RangeRepEngine engine, {
  required double angle,
  double backAngle = 60,
  Duration confirmationWindow = _transitionConfirmationWindow,
}) {
  engine.update(_frame(angle, backAngle));
  clock.advance(confirmationWindow);
  engine.update(_frame(angle, backAngle));
}

AnalysisFrame _frame(double angle, double backAngle) {
  return AnalysisFrame(primaryMetric: angle, formMetric: backAngle);
}

ExerciseConfig _squatConfig({RangeRepPhaseQualityConfig? phaseQuality}) {
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

ExerciseConfig _pushUpConfig() {
  return ExerciseConfig(
    name: 'Push-Up',
    primaryJoint: PoseLandmarkType.leftElbow,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftWrist,
    thresholdNeutral: 165.0,
    thresholdActive: 135.0,
    thresholdPeak: 95.0,
    idealDescentSeconds: 1.2,
    idealAscentSeconds: 1.0,
    formThreshold: 150.0,
    targetMinAngle: 85.0,
    tempoPenaltyPerSecond: 20.0,
    rangeRepPhaseQuality: const RangeRepPhaseQualityConfig(
      minDescendingMillis: 250,
      minAscendingMillis: 250,
    ),
  );
}

ExerciseConfig _sitUpConfig() {
  return loadExerciseConfig('assets/config/exercises/sit_up.json');
}

void _completeSitUpRep(_TestClock clock, RangeRepEngine engine) {
  _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
  _confirmTransition(clock, engine, angle: 108, backAngle: 90);
  _confirmTransition(clock, engine, angle: 68, backAngle: 90);
  _confirmTransition(clock, engine, angle: 82, backAngle: 90);
  _confirmTransition(
    clock,
    engine,
    angle: 121,
    backAngle: 90,
    confirmationWindow: _neutralConfirmationWindow,
  );
}
