import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_session_measurement_evidence_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';

void main() {
  const policy = HoldSessionMeasurementEvidencePolicy();

  group('HoldSessionMeasurementEvidencePolicy', () {
    test('classifies stable high-confidence hold evidence as high', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        totalHoldSeconds: 20,
        averageMeasurementConfidence: 0.95,
        measurementSampleCount: 20,
        observedHoldFrameCount: 20,
        visibilityInterruptedFrameCount: 0,
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.high);
      expect(evidence.measurementSampleCount, 20);
      expect(evidence.averageMeasurementConfidence, 0.95);
    });

    test('allows bounded visibility interruption only at moderate quality', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        totalHoldSeconds: 20,
        averageMeasurementConfidence: 0.95,
        measurementSampleCount: 10,
        observedHoldFrameCount: 12,
        visibilityInterruptedFrameCount: 2,
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.moderate);
    });

    test('limits short holds even when individual frames are excellent', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        totalHoldSeconds: 4.9,
        averageMeasurementConfidence: 0.98,
        measurementSampleCount: 20,
        observedHoldFrameCount: 20,
        visibilityInterruptedFrameCount: 0,
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.limited);
    });

    test('limits sessions when preparation was not passed', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.overridden,
        totalHoldSeconds: 30,
        averageMeasurementConfidence: 0.98,
        measurementSampleCount: 20,
        observedHoldFrameCount: 20,
        visibilityInterruptedFrameCount: 0,
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.limited);
    });

    test('returns unknown with no measurable hold frames', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        totalHoldSeconds: 0,
        averageMeasurementConfidence: null,
        measurementSampleCount: 0,
        observedHoldFrameCount: 0,
        visibilityInterruptedFrameCount: 0,
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.unknown);
      expect(evidence.averageMeasurementConfidence, isNull);
      expect(evidence.measurementSampleCount, 0);
    });

    test('uses insufficient only for a single measurable frame', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        totalHoldSeconds: 1,
        averageMeasurementConfidence: 0.95,
        measurementSampleCount: 1,
        observedHoldFrameCount: 1,
        visibilityInterruptedFrameCount: 0,
      );

      expect(
        evidence.measurementQuality,
        SessionMeasurementQuality.insufficient,
      );
    });
  });
}
