import 'exercise_metrics.dart';

enum RangeRepFrameInvalidReason {
  poseMissing('pose missing', 'Tum vucudunu kamerada tut'),
  primaryJointsMissing(
    'primary joints missing',
    'Kalca, diz ve ayak bilegini goster',
  ),
  formJointsMissing('form joints missing', 'Omuz, kalca ve dizi goster'),
  primaryAndFormJointsMissing(
    'primary + form joints missing',
    'Squat eklemlerini kamerada tut',
  );

  const RangeRepFrameInvalidReason(this.debugLabel, this.feedbackMessage);

  final String debugLabel;
  final String feedbackMessage;
}

class RangeRepFrameAssessment {
  const RangeRepFrameAssessment._({
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.invalidReason,
  });

  const RangeRepFrameAssessment.valid()
    : this._(
        hasPrimaryAngle: true,
        hasFormMetric: true,
        invalidReason: null,
      );

  const RangeRepFrameAssessment.invalid({
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
    required RangeRepFrameInvalidReason invalidReason,
  }) : this._(
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         invalidReason: invalidReason,
       );

  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final RangeRepFrameInvalidReason? invalidReason;

  bool get isValid => invalidReason == null;
  bool get shouldUpdateEngine => isValid;

  String get invalidReasonLabel => invalidReason?.debugLabel ?? '--';
  String get feedbackMessage =>
      invalidReason?.feedbackMessage ?? 'Hazir!';
}

class RangeRepFramePolicy {
  const RangeRepFramePolicy();

  RangeRepFrameAssessment evaluate(ExerciseMetrics metrics) {
    if (!metrics.hasPose) {
      return const RangeRepFrameAssessment.invalid(
        hasPrimaryAngle: false,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.poseMissing,
      );
    }

    if (!metrics.hasPrimaryAngle && !metrics.hasFormMetric) {
      return const RangeRepFrameAssessment.invalid(
        hasPrimaryAngle: false,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.primaryAndFormJointsMissing,
      );
    }

    if (!metrics.hasPrimaryAngle) {
      return const RangeRepFrameAssessment.invalid(
        hasPrimaryAngle: false,
        hasFormMetric: true,
        invalidReason: RangeRepFrameInvalidReason.primaryJointsMissing,
      );
    }

    if (!metrics.hasFormMetric) {
      return const RangeRepFrameAssessment.invalid(
        hasPrimaryAngle: true,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.formJointsMissing,
      );
    }

    return const RangeRepFrameAssessment.valid();
  }
}
