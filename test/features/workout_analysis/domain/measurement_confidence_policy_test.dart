import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/measurement_confidence_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';

void main() {
  const policy = MeasurementConfidencePolicy();

  group('MeasurementConfidencePolicy', () {
    test('produces high combined confidence from four clean components', () {
      final result = policy.evaluate(
        landmarkLikelihood: 0.98,
        signalAvailability: 1.0,
        geometryPlausibility: 1.0,
        temporalContinuity: 0.95,
      );

      expect(result.combined, isNotNull);
      expect(result.combined!, greaterThan(0.97));
      expect(result.combined!, lessThanOrEqualTo(1.0));
      expect(result.isKnown, isTrue);
    });

    test('low landmark likelihood limits the harmonic aggregate', () {
      final result = policy.evaluate(
        landmarkLikelihood: 0.10,
        signalAvailability: 1.0,
        geometryPlausibility: 1.0,
        temporalContinuity: 1.0,
      );

      expect(result.combined, closeTo(0.2173913043, 0.0000000001));
      expect(result.combined, lessThan(0.25));
    });

    test('zero signal availability makes combined confidence zero', () {
      final result = policy.evaluate(
        landmarkLikelihood: 1.0,
        signalAvailability: 0.0,
        geometryPlausibility: 1.0,
        temporalContinuity: 1.0,
      );

      expect(result.combined, 0.0);
    });

    test('degenerate geometry representation cannot remain high', () {
      final result = policy.evaluate(
        landmarkLikelihood: 1.0,
        signalAvailability: 1.0,
        geometryPlausibility: 0.0,
        temporalContinuity: 1.0,
        issues: const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.degenerateGeometry,
        ],
      );

      expect(result.combined, 0.0);
      expect(
        result.issues,
        contains(MeasurementConfidenceIssue.degenerateGeometry),
      );
    });

    test('any unknown component keeps combined confidence unknown', () {
      final result = policy.evaluate(
        landmarkLikelihood: 1.0,
        signalAvailability: 1.0,
        geometryPlausibility: 1.0,
        temporalContinuity: null,
        issues: const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.temporalHistoryUnavailable,
        ],
      );

      expect(result.temporalContinuity, isNull);
      expect(result.combined, isNull);
      expect(result.isKnown, isFalse);
    });

    test('rejects invalid inputs before calculating the aggregate', () {
      expect(
        () => policy.evaluate(
          landmarkLikelihood: double.nan,
          signalAvailability: 1.0,
          geometryPlausibility: 1.0,
          temporalContinuity: 1.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => policy.evaluate(
          landmarkLikelihood: 1.0,
          signalAvailability: double.infinity,
          geometryPlausibility: 1.0,
          temporalContinuity: 1.0,
        ),
        throwsArgumentError,
      );
    });

    test('uses the fixed roadmap weights', () {
      expect(MeasurementConfidencePolicy.landmarkLikelihoodWeight, 0.40);
      expect(MeasurementConfidencePolicy.signalAvailabilityWeight, 0.25);
      expect(MeasurementConfidencePolicy.geometryPlausibilityWeight, 0.20);
      expect(MeasurementConfidencePolicy.temporalContinuityWeight, 0.15);
    });

    test('accepts only measurement dimensions as policy inputs', () {
      final result = policy.evaluate(
        landmarkLikelihood: 0.8,
        signalAvailability: 0.9,
        geometryPlausibility: 1.0,
        temporalContinuity: 0.7,
      );

      expect(result.landmarkLikelihood, 0.8);
      expect(result.signalAvailability, 0.9);
      expect(result.geometryPlausibility, 1.0);
      expect(result.temporalContinuity, 0.7);
      expect(result.issues, isEmpty);
    });
  });
}
