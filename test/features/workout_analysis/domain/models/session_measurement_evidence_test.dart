import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';

void main() {
  group('SessionMeasurementEvidence', () {
    test('unknown evidence keeps the preparation outcome', () {
      final evidence = SessionMeasurementEvidence.unknown(
        preparationOutcome: PreparationOutcome.overridden,
      );

      expect(evidence.preparationOutcome, PreparationOutcome.overridden);
      expect(evidence.measurementQuality, SessionMeasurementQuality.unknown);
      expect(evidence.averageMeasurementConfidence, isNull);
      expect(evidence.measurementSampleCount, 0);
    });

    test('rejects quality claims that contradict preparation evidence', () {
      expect(
        () => SessionMeasurementEvidence(
          preparationOutcome: PreparationOutcome.overridden,
          measurementQuality: SessionMeasurementQuality.high,
          averageMeasurementConfidence: 0.95,
          measurementSampleCount: 2,
        ),
        throwsAssertionError,
      );
    });

    test('unknown wire values fall back safely for forward compatibility', () {
      expect(
        PreparationOutcome.fromWireValue('future_outcome'),
        PreparationOutcome.legacyUnknown,
      );
      expect(
        SessionMeasurementQuality.fromWireValue('excellent'),
        SessionMeasurementQuality.unknown,
      );
    });
  });
}
