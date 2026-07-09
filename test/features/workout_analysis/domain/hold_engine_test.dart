import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
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

    test('breaks the hold after the grace window expires', () {
      final clock = _TestClock();
      final engine = HoldEngine(config: _plankConfig(), now: clock.now);

      engine.update(_validHoldFrame());
      _breakHoldAfterGraceWindow(clock, engine);

      expect(engine.phaseLabel, 'BROKEN');
      expect(engine.isFormBad, isTrue);
      expect(engine.feedback, 'Kalcayi Hizala');
      expect(engine.diagnosticsSnapshot.isHolding, isFalse);
      expect(engine.diagnosticsSnapshot.hadFormBreak, isTrue);
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
  return const AnalysisFrame(
    primaryMetric: 170.0,
    formMetric: 170.0,
    bodyLineAngle: 170.0,
    armSupportAngle: 90.0,
    legExtensionAngle: 170.0,
  );
}

AnalysisFrame _bodyMisalignedFrame() {
  return const AnalysisFrame(
    primaryMetric: 162.0,
    formMetric: 162.0,
    bodyLineAngle: 162.0,
    armSupportAngle: 90.0,
    legExtensionAngle: 170.0,
  );
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
