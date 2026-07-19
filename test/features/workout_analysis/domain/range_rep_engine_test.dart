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

      final breakdown = engine.lastRepScoreBreakdown;

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(breakdown, isNotNull);
      expect(breakdown?.romScore, 80);
      expect(breakdown?.descentScore, closeTo(71.62, 0.001));
      expect(breakdown?.ascentScore, closeTo(81.62, 0.001));
      expect(breakdown?.weightedBaseScore, isNull);
      expect(breakdown?.runtimeBaseScore, closeTo(78.31, 0.001));
      expect(breakdown?.phaseQualityPenalty, isNull);
      expect(breakdown?.phaseAdjustedScore, isNull);
      expect(breakdown?.finalScore, breakdown?.runtimeBaseScore);
      expect(engine.lastRepScore, breakdown?.finalScore);
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
          closeTo(breakdown.runtimeBaseScore - 5.0, 0.001),
        );
        expect(breakdown.finalScore, breakdown.phaseAdjustedScore);
        expect(engine.lastRepScore, breakdown.finalScore);
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

      final violatedBreakdown = violatedEngine.lastRepScoreBreakdown!;
      final violatedTempoScore =
          (violatedBreakdown.descentScore + violatedBreakdown.ascentScore) / 2;
      final expectedViolatedBaseScore =
          (violatedBreakdown.romScore + violatedTempoScore) / 4;

      expect(cleanEngine.repCount, 1);
      expect(violatedEngine.repCount, 1);
      expect(violatedBreakdown.hadFormViolation, isTrue);
      expect(violatedBreakdown.weightedBaseScore, isNull);
      expect(
        violatedBreakdown.runtimeBaseScore,
        closeTo(expectedViolatedBaseScore, 0.001),
      );
      expect(violatedBreakdown.phaseQualityPenalty, 10.0);
      expect(
        violatedBreakdown.phaseAdjustedScore,
        closeTo(violatedBreakdown.runtimeBaseScore - 10.0, 0.001),
      );
      expect(
        violatedBreakdown.finalScore,
        violatedBreakdown.phaseAdjustedScore,
      );
      expect(violatedEngine.lastRepScore, violatedBreakdown.finalScore);
      expect(violatedEngine.lastRepScore, lessThan(cleanEngine.lastRepScore));
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

    test('push-up form threshold behavior stays unchanged', () {
      final cleanClock = _TestClock();
      final cleanEngine = RangeRepEngine(
        config: _pushUpConfig(),
        now: cleanClock.now,
      );
      _completePushUpRep(cleanClock, cleanEngine, bodyLineAngle: 170);

      final violatedClock = _TestClock();
      final violatedEngine = RangeRepEngine(
        config: _pushUpConfig(),
        now: violatedClock.now,
      );
      _completePushUpRep(violatedClock, violatedEngine, bodyLineAngle: 140);

      expect(cleanEngine.repCount, 1);
      expect(violatedEngine.repCount, 1);
      expect(violatedEngine.lastRepScore, lessThan(cleanEngine.lastRepScore));
      expect(violatedEngine.lastRepScoreBreakdown?.hadFormViolation, isTrue);
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

      _confirmTransition(clock, engine, angle: 82, backAngle: 90);
      expect(engine.phaseLabel, 'DESCENDING');

      _confirmTransition(clock, engine, angle: 79, backAngle: 90);
      expect(engine.phaseLabel, 'PEAK');

      _confirmTransition(clock, engine, angle: 90, backAngle: 90);
      expect(engine.phaseLabel, 'PEAK');

      _confirmTransition(clock, engine, angle: 92, backAngle: 90);
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

        final breakdown = engine.lastRepScoreBreakdown;
        final expectedWeightedBaseScore =
            (breakdown!.depthScore! +
                breakdown.descentControlScore! +
                breakdown.ascentControlScore!) /
            3;

        expect(engine.repCount, 1);
        expect(engine.phaseLabel, 'NEUTRAL');
        expect(
          breakdown.weightedBaseScore,
          closeTo(expectedWeightedBaseScore, 0.001),
        );
        expect(
          breakdown.runtimeBaseScore,
          closeTo(expectedWeightedBaseScore, 0.001),
        );
        expect(engine.lastRepScore, inInclusiveRange(0.0, 100.0));
        expect(engine.lastRepRom, closeTo(68.0, 0.001));
        expect(breakdown.hadFormViolation, isFalse);
        expect(engine.consumeCompletedRepCoreData()?.repIndex, 1);
      },
    );

    test(
      'real sit-up config does not count a return from 82 degrees without reaching peak',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

        _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
        _confirmTransition(clock, engine, angle: 108, backAngle: 90);
        _confirmTransition(clock, engine, angle: 82, backAngle: 90);
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
      },
    );

    test(
      'real sit-up config counts a full cycle that bottoms out at 79 degrees',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

        _completeSitUpRep(clock, engine, peakAngle: 79);

        expect(engine.repCount, 1);
        expect(engine.phaseLabel, 'NEUTRAL');
        expect(engine.lastRepScoreBreakdown, isNotNull);
      },
    );

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
      'normal peak hip flexion stays form-good at a 68.4 degree sit-up form metric',
      () {
        final clock = _TestClock();
        final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

        _acquireNeutral(clock, engine, angle: 125, backAngle: 120);
        _confirmTransition(clock, engine, angle: 108, backAngle: 68.4);
        _confirmTransition(clock, engine, angle: 52.7, backAngle: 68.4);

        expect(engine.phaseLabel, 'PEAK');
        expect(engine.isFormBad, isFalse);
        expect(
          engine.feedbackCode,
          isNot(RangeRepFeedbackCode.keepBodyUpright),
        );
      },
    );

    test('sit-up form metric stays form-good at the 60 degree boundary', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 125, backAngle: 120);
      _confirmTransition(clock, engine, angle: 108, backAngle: 60);
      _confirmTransition(clock, engine, angle: 52.7, backAngle: 60);

      final diagnostics = engine.diagnosticsSnapshot;

      expect(engine.phaseLabel, 'PEAK');
      expect(engine.isFormBad, isFalse);
      expect(engine.feedbackCode, isNot(RangeRepFeedbackCode.keepBodyUpright));
      expect(diagnostics.currentRepHadFormViolation, isFalse);
      expect(diagnostics.descendingPhaseQuality.hadFormViolation, isFalse);
      expect(diagnostics.peakPhaseQuality.hadFormViolation, isFalse);
      expect(
        diagnostics.descendingPhaseAssessment.issues,
        isNot(contains(RangeRepPhaseQualityIssue.formViolation)),
      );
      expect(
        diagnostics.peakPhaseAssessment.issues,
        isNot(contains(RangeRepPhaseQualityIssue.formViolation)),
      );
    });

    test('low knee-angle form metric still triggers a real form violation', () {
      final clock = _TestClock();
      final engine = RangeRepEngine(config: _sitUpConfig(), now: clock.now);

      _acquireNeutral(clock, engine, angle: 125, backAngle: 120);
      _confirmTransition(clock, engine, angle: 108, backAngle: 55);
      _confirmTransition(clock, engine, angle: 52.7, backAngle: 55);
      engine.update(_frame(52.7, 55));

      expect(engine.isFormBad, isTrue);
      expect(engine.feedbackCode, RangeRepFeedbackCode.keepBodyUpright);
      final diagnostics = engine.diagnosticsSnapshot;
      expect(diagnostics.currentRepHadFormViolation, isTrue);
      expect(diagnostics.descendingPhaseQuality.hadFormViolation, isTrue);
      expect(diagnostics.peakPhaseQuality.hadFormViolation, isTrue);
      expect(
        diagnostics.descendingPhaseAssessment.issues,
        contains(RangeRepPhaseQualityIssue.formViolation),
      );
      expect(
        diagnostics.peakPhaseAssessment.issues,
        contains(RangeRepPhaseQualityIssue.formViolation),
      );

      _confirmTransition(clock, engine, angle: 92, backAngle: 60);
      _confirmTransition(
        clock,
        engine,
        angle: 121,
        backAngle: 60,
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

    test('brief gap duration is excluded from phase-quality timing', () {
      final gapClock = _TestClock();
      final gapEngine = RangeRepEngine(
        config: _squatConfig(),
        now: gapClock.now,
      );

      _completeRepWithBriefDescendingGap(gapClock, gapEngine);

      expect(gapEngine.repCount, 1);
      expect(
        gapEngine.diagnosticsSnapshot.descendingPhaseQuality.durationMs,
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

void _completePushUpRep(
  _TestClock clock,
  RangeRepEngine engine, {
  double bodyLineAngle = 170,
}) {
  _acquireNeutral(clock, engine, angle: 170, backAngle: bodyLineAngle);
  _confirmTransition(clock, engine, angle: 130, backAngle: bodyLineAngle);
  _confirmTransition(clock, engine, angle: 90, backAngle: bodyLineAngle);
  _confirmTransition(clock, engine, angle: 110, backAngle: bodyLineAngle);
  _confirmTransition(
    clock,
    engine,
    angle: 170,
    backAngle: bodyLineAngle,
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

void _completeSitUpRep(
  _TestClock clock,
  RangeRepEngine engine, {
  double peakAngle = 68,
}) {
  _acquireNeutral(clock, engine, angle: 125, backAngle: 90);
  _confirmTransition(clock, engine, angle: 108, backAngle: 90);
  _confirmTransition(clock, engine, angle: peakAngle, backAngle: 90);
  _confirmTransition(clock, engine, angle: 92, backAngle: 90);
  _confirmTransition(
    clock,
    engine,
    angle: 121,
    backAngle: 90,
    confirmationWindow: _neutralConfirmationWindow,
  );
}
