import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';

void main() {
  group('MeasurementConfidenceBreakdown', () {
    test('preserves explicit unknown component semantics', () {
      final breakdown = MeasurementConfidenceBreakdown(
        landmarkLikelihood: 0.95,
        signalAvailability: null,
        geometryPlausibility: 1.0,
        temporalContinuity: null,
        combined: null,
        issues: const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.missingRequiredSignal,
          MeasurementConfidenceIssue.temporalHistoryUnavailable,
        ],
      );

      expect(breakdown.landmarkLikelihood, 0.95);
      expect(breakdown.signalAvailability, isNull);
      expect(breakdown.temporalContinuity, isNull);
      expect(breakdown.combined, isNull);
      expect(breakdown.isKnown, isFalse);
    });

    test('rejects values outside the normalized range', () {
      MeasurementConfidenceBreakdown create(double value) {
        return MeasurementConfidenceBreakdown(
          landmarkLikelihood: value,
          signalAvailability: 1.0,
          geometryPlausibility: 1.0,
          temporalContinuity: 1.0,
          combined: 1.0,
          issues: const <MeasurementConfidenceIssue>[],
        );
      }

      expect(() => create(-0.01), throwsArgumentError);
      expect(() => create(1.01), throwsArgumentError);
    });

    test('rejects NaN and infinity', () {
      MeasurementConfidenceBreakdown create(double value) {
        return MeasurementConfidenceBreakdown(
          landmarkLikelihood: 1.0,
          signalAvailability: value,
          geometryPlausibility: 1.0,
          temporalContinuity: 1.0,
          combined: 1.0,
          issues: const <MeasurementConfidenceIssue>[],
        );
      }

      expect(() => create(double.nan), throwsArgumentError);
      expect(() => create(double.infinity), throwsArgumentError);
      expect(() => create(double.negativeInfinity), throwsArgumentError);
    });

    test('does not expose the caller-owned mutable issue list', () {
      final source = <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.lowLandmarkLikelihood,
      ];
      final breakdown = MeasurementConfidenceBreakdown(
        landmarkLikelihood: 0.5,
        signalAvailability: 1.0,
        geometryPlausibility: 1.0,
        temporalContinuity: 1.0,
        combined: 0.7,
        issues: source,
      );

      source.clear();

      expect(breakdown.issues, <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.lowLandmarkLikelihood,
      ]);
      expect(breakdown.issues.clear, throwsUnsupportedError);
    });

    test('deduplicates issues while preserving first-seen order', () {
      final breakdown = MeasurementConfidenceBreakdown(
        landmarkLikelihood: 0.5,
        signalAvailability: 0.5,
        geometryPlausibility: 0.5,
        temporalContinuity: 0.5,
        combined: 0.5,
        issues: const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.lowLandmarkLikelihood,
          MeasurementConfidenceIssue.missingRequiredSignal,
          MeasurementConfidenceIssue.lowLandmarkLikelihood,
        ],
      );

      expect(breakdown.issues, <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.lowLandmarkLikelihood,
        MeasurementConfidenceIssue.missingRequiredSignal,
      ]);
    });

    test('keeps stable machine-readable issue codes', () {
      expect(
        <MeasurementConfidenceIssue, String>{
          for (final issue in MeasurementConfidenceIssue.values)
            issue: issue.code,
        },
        <MeasurementConfidenceIssue, String>{
          MeasurementConfidenceIssue.missingRequiredLandmark:
              'missing_required_landmark',
          MeasurementConfidenceIssue.lowLandmarkLikelihood:
              'low_landmark_likelihood',
          MeasurementConfidenceIssue.lowMeanLikelihood: 'low_mean_likelihood',
          MeasurementConfidenceIssue.missingRequiredSignal:
              'missing_required_signal',
          MeasurementConfidenceIssue.nonFiniteGeometry: 'non_finite_geometry',
          MeasurementConfidenceIssue.degenerateGeometry: 'degenerate_geometry',
          MeasurementConfidenceIssue.temporalHistoryUnavailable:
              'temporal_history_unavailable',
          MeasurementConfidenceIssue.temporalDiscontinuity:
              'temporal_discontinuity',
          MeasurementConfidenceIssue.coverageInterruption:
              'coverage_interruption',
          MeasurementConfidenceIssue.sideSwitchDuringRep:
              'side_switch_during_rep',
          MeasurementConfidenceIssue.legacyScalarOnly: 'legacy_scalar_only',
        },
      );
    });
  });
}
