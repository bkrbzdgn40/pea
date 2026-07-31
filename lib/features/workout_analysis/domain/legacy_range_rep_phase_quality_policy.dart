import 'feedback_arbitration_engine.dart';
import 'models/exercise_config.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_feedback_code.dart';
import 'range_rep_diagnostics.dart';

class LegacyRangeRepPhaseQualityPolicy {
  const LegacyRangeRepPhaseQualityPolicy({
    FeedbackArbitrationEngine feedbackArbitrationEngine =
        const FeedbackArbitrationEngine(),
  }) : _feedbackArbitrationEngine = feedbackArbitrationEngine;

  final FeedbackArbitrationEngine _feedbackArbitrationEngine;

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
    final candidates = <FeedbackCandidate<RangeRepFeedbackCode>>[
      // P0.2 tempo quarantine: durationTooShort remains in diagnostics, but it
      // must not produce live visual or spoken coaching until the timing signal
      // is rebuilt and validated. Form-derived feedback remains active.
      if (peak.issues.contains(RangeRepPhaseQualityIssue.formViolation))
        const FeedbackCandidate<RangeRepFeedbackCode>(
          id: 'phase_stabilize_transition',
          value: RangeRepFeedbackCode.stabilizeTransition,
          priority: FeedbackPriority.corrective,
        ),
      if (descending.issues.contains(RangeRepPhaseQualityIssue.formViolation) ||
          ascending.issues.contains(RangeRepPhaseQualityIssue.formViolation))
        const FeedbackCandidate<RangeRepFeedbackCode>(
          id: 'phase_maintain_form',
          value: RangeRepFeedbackCode.maintainForm,
          priority: FeedbackPriority.corrective,
        ),
    ];

    return _feedbackArbitrationEngine
        .arbitrate<RangeRepFeedbackCode>(candidates: candidates)
        .selectedValue;
  }
}
