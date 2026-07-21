import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/form_rule_engine.dart';

void main() {
  group('FormRuleEngine', () {
    const engine = FormRuleEngine();

    test('emits a structured violation below a dynamic minimum', () {
      final rule = _minimumRule();

      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(
          value: 44,
          minimum: 45,
          phase: 'descending',
        ),
        rules: <FormRule<_RuleContext>>[rule],
      );

      expect(evaluation.violations, hasLength(1));
      final violation = evaluation.violations.single;
      expect(violation.ruleId, 'minimum_form');
      expect(violation.code, 'minimum_form_violation');
      expect(violation.severity, FormRuleSeverity.warning);
      expect(violation.measuredValue, 44);
      expect(violation.expectedMinimum, 45);
      expect(violation.expectedMaximum, isNull);
      expect(violation.phase, 'descending');
      expect(violation.context, 'range_rep');
    });

    test('treats an inclusive minimum boundary as passing', () {
      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: 45, minimum: 45),
        rules: <FormRule<_RuleContext>>[_minimumRule()],
      );

      expect(evaluation.hasViolations, isFalse);
    });

    test('emits a violation above a dynamic maximum', () {
      final rule = FormRule<_RuleContext>(
        id: 'maximum_form',
        code: 'maximum_form_violation',
        severity: FormRuleSeverity.critical,
        valueOf: (context) => context.value,
        maximumOf: (context) => context.maximum,
      );

      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: 11, maximum: 10),
        rules: <FormRule<_RuleContext>>[rule],
      );

      expect(evaluation.violations.single.expectedMaximum, 10);
      expect(evaluation.violations.single.severity, FormRuleSeverity.critical);
    });

    test('supports an inclusive range rule', () {
      final rule = FormRule<_RuleContext>(
        id: 'bounded_form',
        code: 'bounded_form_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (context) => context.minimum,
        maximumOf: (context) => context.maximum,
      );

      final passing = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: 5, minimum: 0, maximum: 10),
        rules: <FormRule<_RuleContext>>[rule],
      );
      final failing = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: -1, minimum: 0, maximum: 10),
        rules: <FormRule<_RuleContext>>[rule],
      );

      expect(passing.violations, isEmpty);
      expect(failing.violations.single.expectedMinimum, 0);
      expect(failing.violations.single.expectedMaximum, 10);
    });

    test('does not convert a missing measurement into a form violation', () {
      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: null, minimum: 45),
        rules: <FormRule<_RuleContext>>[_minimumRule()],
      );

      expect(evaluation.violations, isEmpty);
    });

    test('skips a rule outside its declared applicability context', () {
      final rule = FormRule<_RuleContext>(
        id: 'active_only',
        code: 'active_only_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (context) => context.minimum,
        appliesWhen: (context) => context.isActive,
      );

      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: 1, minimum: 10, isActive: false),
        rules: <FormRule<_RuleContext>>[rule],
      );

      expect(evaluation.violations, isEmpty);
    });

    test('returns every violation in declaration order', () {
      final first = FormRule<_RuleContext>(
        id: 'first',
        code: 'first_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (_) => 10,
      );
      final second = FormRule<_RuleContext>(
        id: 'second',
        code: 'second_violation',
        severity: FormRuleSeverity.info,
        valueOf: (context) => context.value,
        minimumOf: (_) => 20,
      );

      final evaluation = engine.evaluate<_RuleContext>(
        context: const _RuleContext(value: 1),
        rules: <FormRule<_RuleContext>>[first, second],
      );

      expect(
        evaluation.violations.map((violation) => violation.ruleId),
        <String>['first', 'second'],
      );
    });

    test('rejects duplicate rule ids within one evaluation', () {
      final first = FormRule<_RuleContext>(
        id: 'duplicate',
        code: 'first_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (_) => 10,
      );
      final second = FormRule<_RuleContext>(
        id: 'duplicate',
        code: 'second_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (_) => 20,
      );

      expect(
        () => engine.evaluate<_RuleContext>(
          context: const _RuleContext(value: 1),
          rules: <FormRule<_RuleContext>>[first, second],
        ),
        throwsStateError,
      );
    });

    test('rejects a dynamically inverted range', () {
      final rule = FormRule<_RuleContext>(
        id: 'invalid_range',
        code: 'invalid_range_violation',
        severity: FormRuleSeverity.warning,
        valueOf: (context) => context.value,
        minimumOf: (context) => context.minimum,
        maximumOf: (context) => context.maximum,
      );

      expect(
        () => engine.evaluate<_RuleContext>(
          context: const _RuleContext(value: 5, minimum: 10, maximum: 0),
          rules: <FormRule<_RuleContext>>[rule],
        ),
        throwsStateError,
      );
    });
  });
}

FormRule<_RuleContext> _minimumRule() {
  return FormRule<_RuleContext>(
    id: 'minimum_form',
    code: 'minimum_form_violation',
    severity: FormRuleSeverity.warning,
    valueOf: (context) => context.value,
    minimumOf: (context) => context.minimum,
    phaseOf: (context) => context.phase,
    contextOf: (_) => 'range_rep',
  );
}

class _RuleContext {
  const _RuleContext({
    this.value,
    this.minimum,
    this.maximum,
    this.phase,
    this.isActive = true,
  });

  final double? value;
  final double? minimum;
  final double? maximum;
  final String? phase;
  final bool isActive;
}
