import 'form_rule_engine.dart';
import 'models/range_rep_technique_assessment.dart';

class LegacyRangeRepTechniqueEvaluator {
  const LegacyRangeRepTechniqueEvaluator({
    FormRuleEngine formRuleEngine = const FormRuleEngine(),
  }) : _formRuleEngine = formRuleEngine;

  final FormRuleEngine _formRuleEngine;

  static final FormRule<_LegacyRangeRepFormContext> _formThresholdRule =
      FormRule<_LegacyRangeRepFormContext>(
        id: 'legacy_form_threshold',
        code: 'legacy_form_threshold_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.formMetric,
        minimumOf: (context) => context.formThreshold,
        contextOf: (_) => 'range_rep',
      );

  RangeRepTechniqueAssessment evaluate({
    required double formMetric,
    required double formThreshold,
  }) {
    final evaluation = _formRuleEngine.evaluate<_LegacyRangeRepFormContext>(
      context: _LegacyRangeRepFormContext(
        formMetric: formMetric,
        formThreshold: formThreshold,
      ),
      rules: <FormRule<_LegacyRangeRepFormContext>>[_formThresholdRule],
    );

    if (!evaluation.hasViolations) {
      return RangeRepTechniqueAssessment.empty;
    }

    return RangeRepTechniqueAssessment(
      observations: evaluation.violations
          .map(_toTechniqueObservation)
          .toList(growable: false),
    );
  }

  RangeRepTechniqueObservation _toTechniqueObservation(
    FormRuleViolation violation,
  ) {
    return RangeRepTechniqueObservation(
      type: RangeRepTechniqueObservationType.legacyFormThresholdViolation,
      code: violation.code,
      severity: _toTechniqueSeverity(violation.severity),
      measuredValue: violation.measuredValue,
      referenceValue: violation.expectedMinimum ?? violation.expectedMaximum,
    );
  }

  RangeRepTechniqueSeverity _toTechniqueSeverity(FormRuleSeverity severity) {
    switch (severity) {
      case FormRuleSeverity.info:
        return RangeRepTechniqueSeverity.info;
      case FormRuleSeverity.warning:
        return RangeRepTechniqueSeverity.warning;
      case FormRuleSeverity.critical:
        return RangeRepTechniqueSeverity.critical;
    }
  }
}

class _LegacyRangeRepFormContext {
  const _LegacyRangeRepFormContext({
    required this.formMetric,
    required this.formThreshold,
  });

  final double formMetric;
  final double formThreshold;
}
