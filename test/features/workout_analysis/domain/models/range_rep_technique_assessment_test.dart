import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';

void main() {
  group('RangeRepTechniqueAssessment', () {
    test('empty has no observations', () {
      expect(RangeRepTechniqueAssessment.empty.observations, isEmpty);
      expect(RangeRepTechniqueAssessment.empty.hasObservations, isFalse);
    });

    test('hasObservations is true when an observation exists', () {
      final assessment = RangeRepTechniqueAssessment(
        observations: const <RangeRepTechniqueObservation>[
          RangeRepTechniqueObservation(
            code: 'test_observation',
            severity: RangeRepTechniqueSeverity.info,
          ),
        ],
      );

      expect(assessment.hasObservations, isTrue);
    });

    test('observation preserves its code and severity', () {
      const observation = RangeRepTechniqueObservation(
        code: 'test_observation',
        severity: RangeRepTechniqueSeverity.warning,
      );

      expect(observation.code, 'test_observation');
      expect(observation.severity, RangeRepTechniqueSeverity.warning);
    });

    test('does not expose the caller-owned mutable list', () {
      const observation = RangeRepTechniqueObservation(
        code: 'test_observation',
        severity: RangeRepTechniqueSeverity.critical,
      );
      final source = <RangeRepTechniqueObservation>[observation];
      final assessment = RangeRepTechniqueAssessment(observations: source);

      source.clear();

      expect(assessment.observations, <RangeRepTechniqueObservation>[
        observation,
      ]);
      expect(assessment.observations.clear, throwsUnsupportedError);
    });
  });
}
