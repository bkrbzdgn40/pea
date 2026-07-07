import 'exercise_metrics.dart';
import 'range_rep_side_policy.dart';

enum RangeRepFrameInvalidReason {
  noPose,
  missingPrimaryAngle,
  missingFormMetric,
  missingPrimaryAndFormMetrics,
}

extension RangeRepFrameInvalidReasonX on RangeRepFrameInvalidReason {
  String get debugLabel {
    switch (this) {
      case RangeRepFrameInvalidReason.noPose:
        return 'pose missing';
      case RangeRepFrameInvalidReason.missingPrimaryAngle:
        return 'primary joints missing';
      case RangeRepFrameInvalidReason.missingFormMetric:
        return 'form joints missing';
      case RangeRepFrameInvalidReason.missingPrimaryAndFormMetrics:
        return 'primary + form joints missing';
    }
  }

  String get feedbackMessage {
    switch (this) {
      case RangeRepFrameInvalidReason.noPose:
        return 'Vucut Bekleniyor...';
      case RangeRepFrameInvalidReason.missingPrimaryAngle:
      case RangeRepFrameInvalidReason.missingFormMetric:
      case RangeRepFrameInvalidReason.missingPrimaryAndFormMetrics:
        return 'Tum eklemleri kadraja al.';
    }
  }
}

class RangeRepFrameAssessment {
  const RangeRepFrameAssessment._({
    required this.selection,
    required this.shouldUpdateEngine,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.feedbackMessage,
    this.invalidReason,
  });

  RangeRepFrameAssessment.valid({
    required RangeRepSideSelection selection,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
  }) : this._(
         selection: selection,
         shouldUpdateEngine: true,
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         feedbackMessage: '',
       );

  RangeRepFrameAssessment.invalid({
    required RangeRepSideSelection selection,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
    required RangeRepFrameInvalidReason invalidReason,
  }) : this._(
         selection: selection,
         shouldUpdateEngine: false,
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         feedbackMessage: invalidReason.feedbackMessage,
         invalidReason: invalidReason,
       );

  final RangeRepSideSelection selection;
  final bool shouldUpdateEngine;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final String feedbackMessage;
  final RangeRepFrameInvalidReason? invalidReason;

  bool get isValid => shouldUpdateEngine;
  RangeRepSideMetrics? get selectedMetrics => selection.selectedMetrics;
}

class RangeRepFramePolicy {
  const RangeRepFramePolicy();

  RangeRepFrameAssessment assess({
    required ExerciseMetrics metrics,
    required RangeRepSideSelection selection,
  }) {
    final selectedMetrics = selection.selectedMetrics;
    final hasPrimaryAngle = selectedMetrics?.hasPrimaryAngle ?? false;
    final hasFormMetric = selectedMetrics?.hasFormMetric ?? false;

    if (!metrics.hasPose) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        hasPrimaryAngle: hasPrimaryAngle,
        hasFormMetric: hasFormMetric,
        invalidReason: RangeRepFrameInvalidReason.noPose,
      );
    }

    if (!hasPrimaryAngle && !hasFormMetric) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        hasPrimaryAngle: false,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.missingPrimaryAndFormMetrics,
      );
    }

    if (!hasPrimaryAngle) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        hasPrimaryAngle: false,
        hasFormMetric: hasFormMetric,
        invalidReason: RangeRepFrameInvalidReason.missingPrimaryAngle,
      );
    }

    if (!hasFormMetric) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        hasPrimaryAngle: true,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.missingFormMetric,
      );
    }

    return RangeRepFrameAssessment.valid(
      selection: selection,
      hasPrimaryAngle: true,
      hasFormMetric: true,
    );
  }
}
