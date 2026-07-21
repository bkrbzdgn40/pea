typedef FormRuleValueReader<TContext> = double? Function(TContext context);
typedef FormRuleApplicability<TContext> = bool Function(TContext context);
typedef FormRuleLabelReader<TContext> = String? Function(TContext context);

enum FormRuleSeverity { info, warning, critical }

/// Structured evidence emitted when a form rule is violated.
///
/// Missing measurements do not become violations here. Pose acceptance and
/// signal availability remain owned by their existing layers.
class FormRuleViolation {
  const FormRuleViolation({
    required this.ruleId,
    required this.code,
    required this.severity,
    required this.measuredValue,
    this.expectedMinimum,
    this.expectedMaximum,
    this.phase,
    this.context,
  });

  final String ruleId;
  final String code;
  final FormRuleSeverity severity;
  final double measuredValue;
  final double? expectedMinimum;
  final double? expectedMaximum;
  final String? phase;
  final String? context;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'ruleId': ruleId,
      'code': code,
      'severity': severity.name,
      'measuredValue': measuredValue,
      'expectedMinimum': expectedMinimum,
      'expectedMaximum': expectedMaximum,
      'phase': phase,
      'context': context,
    };
  }
}

/// One numeric form constraint evaluated against a typed analysis context.
///
/// Bounds are resolved from the context so exercise/config-specific thresholds
/// do not need to be copied into the engine. A rule may provide a minimum, a
/// maximum, or both. Bounds are inclusive.
class FormRule<TContext> {
  FormRule({
    required this.id,
    required this.code,
    required this.severity,
    required this.valueOf,
    this.minimumOf,
    this.maximumOf,
    this.appliesWhen,
    this.phaseOf,
    this.contextOf,
  }) : assert(minimumOf != null || maximumOf != null);

  final String id;
  final String code;
  final FormRuleSeverity severity;
  final FormRuleValueReader<TContext> valueOf;
  final FormRuleValueReader<TContext>? minimumOf;
  final FormRuleValueReader<TContext>? maximumOf;
  final FormRuleApplicability<TContext>? appliesWhen;
  final FormRuleLabelReader<TContext>? phaseOf;
  final FormRuleLabelReader<TContext>? contextOf;

  FormRuleViolation? evaluate(TContext context) {
    final appliesWhen = this.appliesWhen;
    if (appliesWhen != null && !appliesWhen(context)) {
      return null;
    }

    final minimum = minimumOf?.call(context);
    final maximum = maximumOf?.call(context);
    if (minimum != null && maximum != null && minimum > maximum) {
      throw StateError(
        'Form rule $id resolved an invalid range: $minimum > $maximum.',
      );
    }

    final measuredValue = valueOf(context);
    if (measuredValue == null) {
      return null;
    }

    final violatesMinimum = minimum != null && measuredValue < minimum;
    final violatesMaximum = maximum != null && measuredValue > maximum;
    if (!violatesMinimum && !violatesMaximum) {
      return null;
    }

    return FormRuleViolation(
      ruleId: id,
      code: code,
      severity: severity,
      measuredValue: measuredValue,
      expectedMinimum: minimum,
      expectedMaximum: maximum,
      phase: phaseOf?.call(context),
      context: contextOf?.call(context),
    );
  }
}

class FormRuleEvaluation {
  FormRuleEvaluation({required List<FormRuleViolation> violations})
    : violations = List<FormRuleViolation>.unmodifiable(violations);

  final List<FormRuleViolation> violations;

  bool get hasViolations => violations.isNotEmpty;
}

/// Evaluates all applicable form rules without selecting user-facing feedback.
///
/// The engine deliberately returns every violation in declaration order. Rule
/// prioritization, suppression, cooldown, voice, and haptics belong to later
/// feedback layers.
class FormRuleEngine {
  const FormRuleEngine();

  FormRuleEvaluation evaluate<TContext>({
    required TContext context,
    required Iterable<FormRule<TContext>> rules,
  }) {
    final seenRuleIds = <String>{};
    final violations = <FormRuleViolation>[];

    for (final rule in rules) {
      if (!seenRuleIds.add(rule.id)) {
        throw StateError('Duplicate form rule id: ${rule.id}.');
      }

      final violation = rule.evaluate(context);
      if (violation != null) {
        violations.add(violation);
      }
    }

    return FormRuleEvaluation(violations: violations);
  }
}
