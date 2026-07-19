import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_technique_evaluator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';

void main() {
  group('LegacyRangeRepTechniqueEvaluator', () {
    const evaluator = LegacyRangeRepTechniqueEvaluator();

    test('returns the legacy warning below the form threshold', () {
      final assessment = evaluator.evaluate(formMetric: 59, formThreshold: 60);

      expect(assessment.observations, hasLength(1));
      expect(
        assessment.observations.single.type,
        RangeRepTechniqueObservationType.legacyFormThresholdViolation,
      );
      expect(
        assessment.observations.single.code,
        'legacy_form_threshold_violation',
      );
      expect(
        assessment.observations.single.severity,
        RangeRepTechniqueSeverity.warning,
      );
      expect(assessment.observations.single.phase, isNull);
    });

    test('returns an empty assessment at the form threshold', () {
      final assessment = evaluator.evaluate(formMetric: 60, formThreshold: 60);

      expect(assessment.observations, isEmpty);
    });

    test('returns an empty assessment above the form threshold', () {
      final assessment = evaluator.evaluate(formMetric: 61, formThreshold: 60);

      expect(assessment.observations, isEmpty);
    });
  });
}
