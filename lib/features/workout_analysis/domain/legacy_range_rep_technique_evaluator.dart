import 'models/range_rep_technique_assessment.dart';

class LegacyRangeRepTechniqueEvaluator {
  const LegacyRangeRepTechniqueEvaluator();

  static final RangeRepTechniqueAssessment _violationAssessment =
      RangeRepTechniqueAssessment(
        observations: const <RangeRepTechniqueObservation>[
          RangeRepTechniqueObservation(
            type: RangeRepTechniqueObservationType.legacyFormThresholdViolation,
            code: 'legacy_form_threshold_violation',
            severity: RangeRepTechniqueSeverity.warning,
          ),
        ],
      );

  RangeRepTechniqueAssessment evaluate({
    required double formMetric,
    required double formThreshold,
  }) {
    if (formMetric < formThreshold) {
      return _violationAssessment;
    }

    return RangeRepTechniqueAssessment.empty;
  }
}
