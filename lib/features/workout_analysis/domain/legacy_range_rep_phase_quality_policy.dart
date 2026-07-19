import 'models/exercise_config.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_feedback_code.dart';
import 'range_rep_diagnostics.dart';

class LegacyRangeRepPhaseQualityPolicy {
  const LegacyRangeRepPhaseQualityPolicy();

  RangeRepPhaseQualityAssessment assess({
    required RangeRepPhase phase,
    required RangeRepPhaseQualitySnapshot phaseQuality,
    required bool isActivePhase,
    required RangeRepPhaseQualityConfig? config,
  }) {
    if (!phaseQuality.hasData) {
      return const RangeRepPhaseQualityAssessment();
    }

    final issues = <RangeRepPhaseQualityIssue>[];
    if (!isActivePhase) {
      final minDurationMillis = switch (phase) {
        RangeRepPhase.descending => config?.minDescendingMillis,
        RangeRepPhase.peak => null,
        RangeRepPhase.ascending => config?.minAscendingMillis,
      };
      if (minDurationMillis != null &&
          phaseQuality.durationMs < minDurationMillis) {
        issues.add(RangeRepPhaseQualityIssue.durationTooShort);
      }
    }

    if (phaseQuality.hadFormViolation) {
      issues.add(RangeRepPhaseQualityIssue.formViolation);
    }

    return RangeRepPhaseQualityAssessment(
      status: issues.isEmpty
          ? RangeRepPhaseQualityStatus.observed
          : RangeRepPhaseQualityStatus.flagged,
      issues: issues,
    );
  }

  RangeRepFeedbackCode? feedbackCandidate({
    required RangeRepPhaseQualityAssessment descending,
    required RangeRepPhaseQualityAssessment peak,
    required RangeRepPhaseQualityAssessment ascending,
  }) {
    if (descending.issues.contains(
      RangeRepPhaseQualityIssue.durationTooShort,
    )) {
      return RangeRepFeedbackCode.controlDescent;
    }
    if (ascending.issues.contains(RangeRepPhaseQualityIssue.durationTooShort)) {
      return RangeRepFeedbackCode.controlAscent;
    }
    if (peak.issues.contains(RangeRepPhaseQualityIssue.formViolation)) {
      return RangeRepFeedbackCode.stabilizeTransition;
    }
    if (descending.issues.contains(RangeRepPhaseQualityIssue.formViolation) ||
        ascending.issues.contains(RangeRepPhaseQualityIssue.formViolation)) {
      return RangeRepFeedbackCode.maintainForm;
    }

    return null;
  }
}
