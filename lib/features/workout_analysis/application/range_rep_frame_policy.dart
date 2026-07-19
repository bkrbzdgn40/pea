import '../domain/models/range_rep_contract.dart';
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
    required this.analysisMetrics,
    required this.shouldUpdateEngine,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.feedbackMessage,
    this.invalidReason,
  });

  RangeRepFrameAssessment.valid({
    required RangeRepSideSelection selection,
    required RangeRepAnalysisMetrics? analysisMetrics,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
  }) : this._(
         selection: selection,
         analysisMetrics: analysisMetrics,
         shouldUpdateEngine: true,
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         feedbackMessage: '',
       );

  RangeRepFrameAssessment.invalid({
    required RangeRepSideSelection selection,
    required RangeRepAnalysisMetrics? analysisMetrics,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
    required RangeRepFrameInvalidReason invalidReason,
  }) : this._(
         selection: selection,
         analysisMetrics: analysisMetrics,
         shouldUpdateEngine: false,
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         feedbackMessage: invalidReason.feedbackMessage,
         invalidReason: invalidReason,
       );

  final RangeRepSideSelection selection;
  final RangeRepAnalysisMetrics? analysisMetrics;
  final bool shouldUpdateEngine;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final String feedbackMessage;
  final RangeRepFrameInvalidReason? invalidReason;

  bool get isValid => shouldUpdateEngine;
  RangeRepAnalysisMetrics? get selectedMetrics => analysisMetrics;
}

class RangeRepFramePolicy {
  const RangeRepFramePolicy();

  RangeRepFrameAssessment assessWithContract({
    required ExerciseMetrics metrics,
    required RangeRepSideSelection selection,
    required RangeRepContract contract,
  }) {
    final selectedMetrics = contract.sideMode == RangeRepSideMode.bilateral
        ? metrics.bilateralRangeRepMetrics
        : selection.selectedMetrics;
    final hasPrimaryAngle = selectedMetrics?.hasPrimaryAngle ?? false;
    final hasFormMetric = selectedMetrics?.hasFormMetric ?? false;
    final requiresPrimaryAngle = contract.supportsSignal(
      RangeRepSignal.primaryMetric,
    );
    final requiresFormMetric = contract.requiresPoseAcceptanceSignal(
      RangeRepSignal.formMetric,
    );
    final isMissingPrimaryAngle = requiresPrimaryAngle && !hasPrimaryAngle;
    final isMissingFormMetric = requiresFormMetric && !hasFormMetric;

    if (!metrics.hasPose) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        analysisMetrics: selectedMetrics,
        hasPrimaryAngle: hasPrimaryAngle,
        hasFormMetric: hasFormMetric,
        invalidReason: RangeRepFrameInvalidReason.noPose,
      );
    }

    if (isMissingPrimaryAngle && isMissingFormMetric) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        analysisMetrics: selectedMetrics,
        hasPrimaryAngle: false,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.missingPrimaryAndFormMetrics,
      );
    }

    if (isMissingPrimaryAngle) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        analysisMetrics: selectedMetrics,
        hasPrimaryAngle: false,
        hasFormMetric: hasFormMetric,
        invalidReason: RangeRepFrameInvalidReason.missingPrimaryAngle,
      );
    }

    if (isMissingFormMetric) {
      return RangeRepFrameAssessment.invalid(
        selection: selection,
        analysisMetrics: selectedMetrics,
        hasPrimaryAngle: hasPrimaryAngle,
        hasFormMetric: false,
        invalidReason: RangeRepFrameInvalidReason.missingFormMetric,
      );
    }

    return RangeRepFrameAssessment.valid(
      selection: selection,
      analysisMetrics: selectedMetrics,
      hasPrimaryAngle: hasPrimaryAngle,
      hasFormMetric: hasFormMetric,
    );
  }
}
