import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';

void main() {
  group('HoldEngine', () {
    test(
      'starts holding when body line, arm support, and leg extension are valid',
      () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());

        expect(engine.phaseLabel, 'HOLDING');
        expect(engine.feedback, 'Pozisyonu Koru');
        expect(engine.diagnosticsSnapshot.isHolding, isTrue);
        expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      },
    );

    test('accumulates current hold seconds over time', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 2));
      engine.update(_validHoldFrame());

      expect(engine.diagnosticsSnapshot.isHolding, isTrue);
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(2.0, 0.001),
      );
    });

    test('short visibility gap excludes hidden hold time', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      gapControl.beginVisibilityGap();
      expect(engine.diagnosticsSnapshot.isVisibilitySuspended, isTrue);
      clock.advance(const Duration(milliseconds: 200));

      final result = gapControl.resumeAfterVisibilityGap();
      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 1));
      engine.update(_validHoldFrame());

      expect(result.disposition, HoldVisibilityResumeDisposition.resumed);
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(6.0, 0.001),
      );
    });

    test('one-second visibility gap resumes without counting hidden time', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      gapControl.beginVisibilityGap();
      clock.advance(const Duration(seconds: 1));

      final result = gapControl.resumeAfterVisibilityGap();
      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 1));
      engine.update(_validHoldFrame());

      expect(result.disposition, HoldVisibilityResumeDisposition.resumed);
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(6.0, 0.001),
      );
    });

    test('visibility gap at the freeze boundary ends the hold without a '
        'form-break penalty', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      gapControl.beginVisibilityGap();
      clock.advance(const Duration(milliseconds: 1200));

      final result = gapControl.resumeAfterVisibilityGap();

      expect(result.disposition, HoldVisibilityResumeDisposition.ended);
      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(engine.diagnosticsSnapshot.isHolding, isFalse);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);

      engine.update(_validHoldFrame());
      expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.isHolding, isTrue);

      clock.advance(const Duration(seconds: 1));
      engine.update(_validHoldFrame());
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(1.0, 0.001),
      );
    });

    test('updates best hold seconds across multiple hold attempts', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 2));
      engine.update(_validHoldFrame());
      _breakHoldAfterGraceWindow(clock, engine);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 1));
      engine.update(_validHoldFrame());

      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(2.0, 0.001));
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(1.0, 0.001),
      );
    });

    test('uses the grace window before breaking a temporary misalignment', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(milliseconds: 150));
      engine.update(_bodyMisalignedFrame());

      expect(engine.phaseLabel, 'HOLDING');
      expect(engine.diagnosticsSnapshot.isHolding, isTrue);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    });

    for (final scenario
        in <
          ({
            int elapsedMillis,
            String expectedPhase,
            bool expectedHolding,
            bool expectedFormBreak,
          })
        >[
          (
            elapsedMillis: 299,
            expectedPhase: 'HOLDING',
            expectedHolding: true,
            expectedFormBreak: false,
          ),
          (
            elapsedMillis: 300,
            expectedPhase: 'BROKEN',
            expectedHolding: false,
            expectedFormBreak: true,
          ),
          (
            elapsedMillis: 301,
            expectedPhase: 'BROKEN',
            expectedHolding: false,
            expectedFormBreak: true,
          ),
        ]) {
      test('form-break grace boundary at ${scenario.elapsedMillis} ms '
          'keeps the current production outcome', () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());
        engine.update(_bodyMisalignedFrame());
        clock.advance(Duration(milliseconds: scenario.elapsedMillis));
        engine.update(_bodyMisalignedFrame());

        expect(engine.phaseLabel, scenario.expectedPhase);
        expect(engine.diagnosticsSnapshot.isHolding, scenario.expectedHolding);
        expect(
          engine.diagnosticsSnapshot.hadFormBreak,
          scenario.expectedFormBreak,
        );
      });
    }

    test(
      'body misalignment breaks the hold after the grace window expires',
      () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());
        _breakHoldAfterGraceWindow(clock, engine);

        expect(engine.phaseLabel, 'BROKEN');
        expect(engine.isFormBad, isTrue);
        expect(engine.feedback, 'Kalcayi Hizala');
        expect(engine.diagnosticsSnapshot.isHolding, isFalse);
        expect(engine.diagnosticsSnapshot.hadFormBreak, isTrue);
      },
    );

    test(
      'missing body-line metric ends the hold without grace or form-break',
      () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());
        clock.advance(const Duration(milliseconds: 100));
        engine.update(_missingBodyMetricFrame());

        expect(engine.phaseLabel, 'READY');
        expect(engine.feedback, 'Pozisyonu Hazirla');
        expect(engine.diagnosticsSnapshot.isHolding, isFalse);
        expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
        expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
      },
    );

    for (final scenario
        in <({String name, AnalysisFrame frame, String expectedFeedback})>[
          (
            name:
                'missing arm-support metric immediately breaks and reports body feedback',
            frame: _missingArmMetricFrame(),
            expectedFeedback: 'Kalcayi Hizala',
          ),
          (
            name:
                'missing leg-extension metric immediately breaks and reports body feedback',
            frame: _missingLegMetricFrame(),
            expectedFeedback: 'Kalcayi Hizala',
          ),
          (
            name: 'arm support failure breaks with arm-priority feedback',
            frame: _armUnsupportedFrame(),
            expectedFeedback: 'Dirsek Destegini Duzelt',
          ),
          (
            name: 'leg extension failure breaks with leg-priority feedback',
            frame: _legsNotExtendedFrame(),
            expectedFeedback: 'Dizleri Kaldir',
          ),
        ]) {
      test(scenario.name, () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());
        clock.advance(const Duration(milliseconds: 100));
        engine.update(scenario.frame);

        expect(engine.phaseLabel, 'BROKEN');
        expect(engine.feedback, scenario.expectedFeedback);
        expect(engine.diagnosticsSnapshot.isHolding, isFalse);
        expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
        expect(engine.diagnosticsSnapshot.hadFormBreak, isTrue);
      });
    }

    test('continuous valid plank still accumulates over 30 seconds', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 30));
      engine.update(_validHoldFrame());

      expect(engine.phaseLabel, 'HOLDING');
      expect(engine.diagnosticsSnapshot.isHolding, isTrue);
      expect(
        engine.diagnosticsSnapshot.currentHoldSeconds,
        closeTo(30.0, 0.001),
      );
    });

    test('reset clears the active and best hold state', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 2));
      engine.update(_validHoldFrame());
      _breakHoldAfterGraceWindow(clock, engine);

      engine.reset();

      expect(engine.phaseLabel, 'READY');
      expect(engine.isFormBad, isFalse);
      expect(engine.feedback, 'Pozisyonu Hazirla');
      expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.isHolding, isFalse);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    });

    test('lifecycle interruption hard-ends the active hold', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final interruptionControl = engine as HoldInterruptionControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      interruptionControl.endActiveHoldForInterruption();

      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(engine.diagnosticsSnapshot.isHolding, isFalse);
      expect(engine.diagnosticsSnapshot.isVisibilitySuspended, isFalse);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    });

    test('lifecycle interruption clears an active visibility suspension', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;
      final interruptionControl = engine as HoldInterruptionControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());
      gapControl.beginVisibilityGap();

      expect(engine.diagnosticsSnapshot.isVisibilitySuspended, isTrue);

      interruptionControl.endActiveHoldForInterruption();

      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(engine.diagnosticsSnapshot.isHolding, isFalse);
      expect(engine.diagnosticsSnapshot.isVisibilitySuspended, isFalse);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    });

    test(
      'visibility gap at 1199 ms resumes and keeps hidden time excluded',
      () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);
        final gapControl = engine as HoldVisibilityGapControl;

        engine.update(_validHoldFrame());
        clock.advance(const Duration(seconds: 5));
        engine.update(_validHoldFrame());

        gapControl.beginVisibilityGap();
        clock.advance(const Duration(milliseconds: 1199));

        final result = gapControl.resumeAfterVisibilityGap();
        engine.update(_validHoldFrame());
        clock.advance(const Duration(seconds: 1));
        engine.update(_validHoldFrame());

        expect(result.disposition, HoldVisibilityResumeDisposition.resumed);
        expect(
          engine.diagnosticsSnapshot.currentHoldSeconds,
          closeTo(6.0, 0.001),
        );
      },
    );

    test('visibility gap at 1201 ms ends the hold', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      gapControl.beginVisibilityGap();
      clock.advance(const Duration(milliseconds: 1201));

      final result = gapControl.resumeAfterVisibilityGap();

      expect(result.disposition, HoldVisibilityResumeDisposition.ended);
      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    });

    test('beginning a visibility gap while not holding remains a no-op', () {
      final engine = HoldEngine(config: _plankConfig());
      final gapControl = engine as HoldVisibilityGapControl;

      gapControl.beginVisibilityGap();
      final result = gapControl.resumeAfterVisibilityGap();

      expect(result.disposition, HoldVisibilityResumeDisposition.noGap);
      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.isVisibilitySuspended, isFalse);
    });

    test('repeated beginVisibilityGap calls keep the original gap start', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);
      final gapControl = engine as HoldVisibilityGapControl;

      engine.update(_validHoldFrame());
      clock.advance(const Duration(seconds: 5));
      engine.update(_validHoldFrame());

      gapControl.beginVisibilityGap();
      clock.advance(const Duration(milliseconds: 1000));
      gapControl.beginVisibilityGap();
      clock.advance(const Duration(milliseconds: 250));

      final result = gapControl.resumeAfterVisibilityGap();

      expect(result.disposition, HoldVisibilityResumeDisposition.ended);
      expect(engine.phaseLabel, 'READY');
      expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
    });

    test(
      'resumeAfterVisibilityGap without a gap leaves an active hold unchanged',
      () {
        final engine = HoldEngine(config: _plankConfig());
        final gapControl = engine as HoldVisibilityGapControl;

        engine.update(_validHoldFrame());
        final result = gapControl.resumeAfterVisibilityGap();

        expect(result.disposition, HoldVisibilityResumeDisposition.noGap);
        expect(engine.phaseLabel, 'HOLDING');
        expect(engine.diagnosticsSnapshot.isHolding, isTrue);
        expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
      },
    );

    test(
      'a new valid attempt clears hadFormBreak and preserves the best hold',
      () {
        final clock = _TestClock();
        final engine = HoldEngine(config: _plankConfig(), now: clock.now);

        engine.update(_validHoldFrame());
        clock.advance(const Duration(seconds: 2));
        engine.update(_validHoldFrame());
        _breakHoldAfterGraceWindow(clock, engine);

        expect(engine.diagnosticsSnapshot.hadFormBreak, isTrue);
        expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(2.0, 0.001));

        engine.update(_validHoldFrame());

        expect(engine.phaseLabel, 'HOLDING');
        expect(engine.diagnosticsSnapshot.currentHoldSeconds, 0.0);
        expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
        expect(engine.diagnosticsSnapshot.bestHoldSeconds, closeTo(2.0, 0.001));
      },
    );
  });
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

void _breakHoldAfterGraceWindow(_TestClock clock, HoldEngine engine) {
  engine.update(_bodyMisalignedFrame());
  clock.advance(const Duration(milliseconds: 301));
  engine.update(_bodyMisalignedFrame());
}

AnalysisFrame _validHoldFrame() {
  return _holdFrame();
}

AnalysisFrame _armUnsupportedFrame() {
  return _holdFrame(armSupportAngle: 59.0);
}

AnalysisFrame _legsNotExtendedFrame() {
  return _holdFrame(legExtensionAngle: 164.0);
}

AnalysisFrame _missingBodyMetricFrame() {
  return _holdFrame(bodyLineAngle: null);
}

AnalysisFrame _missingArmMetricFrame() {
  return _holdFrame(armSupportAngle: null);
}

AnalysisFrame _missingLegMetricFrame() {
  return _holdFrame(legExtensionAngle: null);
}

AnalysisFrame _holdFrame({
  double? bodyLineAngle = 170.0,
  double? armSupportAngle = 90.0,
  double? legExtensionAngle = 170.0,
}) {
  return AnalysisFrame(
    primaryMetric: bodyLineAngle ?? 170.0,
    formMetric: bodyLineAngle ?? 170.0,
    bodyLineAngle: bodyLineAngle,
    armSupportAngle: armSupportAngle,
    legExtensionAngle: legExtensionAngle,
  );
}

AnalysisFrame _bodyMisalignedFrame() {
  return _holdFrame(bodyLineAngle: 162.0);
}

ExerciseConfig _plankConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
  );
}
