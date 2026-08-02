import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_aborted_attempt_detection_data.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/rep_score_breakdown.dart';
import '../domain/models/rep_tempo_assessment.dart';
import '../domain/models/validated_rep_event.dart';
import '../domain/range_rep_diagnostics.dart';
import '../domain/range_rep_validation_policy.dart';
import 'engine_kind.dart';
import 'range_rep_rep_outcome_tracker.dart';
import 'range_rep_rep_scoring_service.dart';

class RangeRepAttemptProcessingResult {
  const RangeRepAttemptProcessingResult({
    required this.validatedRepEvent,
    required this.lastRepScore,
    required this.lastAcceptedRepRom,
    required this.lastRepScoreBreakdown,
    this.shouldClearTempoAssessment = false,
  });

  final ValidatedRepEvent validatedRepEvent;
  final double lastRepScore;
  final double lastAcceptedRepRom;
  final RepScoreBreakdown? lastRepScoreBreakdown;
  final bool shouldClearTempoAssessment;
}

/// Converts completed or shallow-aborted range-rep attempts into one immutable
/// outcome that the coordinator can apply to its live state.
///
/// The processor owns validation-event construction and completed-rep scoring.
/// It does not publish UI state, emit feedback, read providers, or mutate the
/// analysis engine. The supplied [RangeRepRepOutcomeTracker] remains the single
/// owner of attempt counters and validation history.
class RangeRepAttemptProcessor {
  const RangeRepAttemptProcessor({
    RangeRepRepScoringService scoringService =
        const RangeRepRepScoringService(),
  }) : _scoringService = scoringService;

  final RangeRepRepScoringService _scoringService;

  RangeRepAttemptProcessingResult? processCompleted({
    required RangeRepRepOutcomeTracker outcomeTracker,
    required RangeRepCompletedRepCoreData? completedRepCoreData,
    required RangeRepDiagnosticsSnapshot postUpdateDiagnostics,
    required RepTempoAssessment? tempoAssessment,
    required DateTime completedAt,
    required double engineLastRepRom,
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    required RangeRepValidationConfig rangeRepValidationConfig,
  }) {
    final validationOutcome = outcomeTracker.activateCompletedRepOutcomeIfAny(
      engineKind: EngineKind.rangeRep,
      analysisKindLabel: EngineKind.rangeRep.name,
      completedRepCoreData: completedRepCoreData,
    );
    if (completedRepCoreData == null || validationOutcome == null) {
      return null;
    }

    final validationResult = validationOutcome.result;
    final scoringResult = validationResult.shouldPublishScore
        ? _scoringService.score(
            RangeRepRepScoringRequest(
              completedRepCoreData: completedRepCoreData,
              postUpdateDiagnostics: postUpdateDiagnostics,
              validationResult: validationResult,
              tempoAssessment: tempoAssessment,
              config: config,
              rangeRepContract: rangeRepContract,
              rangeRepValidationConfig: rangeRepValidationConfig,
              measurementConfidenceCombined: outcomeTracker
                  .lastRangeRepRepSummaryCandidate
                  ?.measurementConfidence
                  ?.combined,
            ),
          )
        : null;
    final lastRepScore = scoringResult?.finalScore ?? 0.0;
    final lastAcceptedRepRom = validationResult.shouldPublishScore
        ? engineLastRepRom
        : 0.0;
    final scoreBreakdown = scoringResult?.breakdown;
    final summary = validationOutcome.summary;

    return RangeRepAttemptProcessingResult(
      validatedRepEvent: ValidatedRepEvent(
        attemptIndex: validationOutcome.attemptIndex,
        acceptedRepIndex: validationResult.countsTowardReps
            ? outcomeTracker.rangeRepAcceptedCount
            : null,
        exerciseType: 'unknown',
        analysisKind: EngineKind.rangeRep.name,
        validationStatus: validationResult.status,
        validationReasons: validationResult.reasons,
        tempoDiagnosticReasons: validationResult.tempoDiagnosticReasons,
        countsTowardReps: validationResult.countsTowardReps,
        side: _validatedRepSideFromLabel(summary.selectedSideLabel),
        minPrimaryMetric: summary.minAngle,
        primaryRom: summary.primaryRom,
        worstFormMetric: summary.worstFormMetric,
        descentDuration: summary.descentDuration,
        ascentDuration: summary.ascentDuration,
        hadFormViolation: summary.hadFormViolation,
        hadCoverageDrop: summary.hadCoverageDrop,
        switchedSideDuringRep: summary.switchedSideDuringRep,
        completedPhaseSequence: summary.completedPhaseSequence,
        measurementConfidence: summary.measurementConfidence,
        coverageQuality: summary.coverageQuality,
        finalScore: validationResult.shouldPublishScore ? lastRepScore : null,
        tempoAssessment: tempoAssessment,
        tempoIncludedInScore:
            scoreBreakdown?.tempoIncludedInFinalScore ?? false,
        completedAt: completedAt,
      ),
      lastRepScore: lastRepScore,
      lastAcceptedRepRom: lastAcceptedRepRom,
      lastRepScoreBreakdown: scoreBreakdown,
    );
  }

  RangeRepAttemptProcessingResult? processShallowAbort({
    required RangeRepRepOutcomeTracker outcomeTracker,
    required bool invalidateAbortToNeutralAsInsufficientRom,
    required RangeRepAbortedAttemptDetectionData? abortedAttemptData,
    required double currentFormMetric,
    required bool hadFormViolation,
    required DateTime completedAt,
  }) {
    if (!invalidateAbortToNeutralAsInsufficientRom ||
        abortedAttemptData == null) {
      return null;
    }

    final validationOutcome = outcomeTracker
        .activateShallowAbortedRepOutcomeIfAny(
          engineKind: EngineKind.rangeRep,
          analysisKindLabel: EngineKind.rangeRep.name,
          abortedAttemptData: abortedAttemptData,
          worstFormMetric: currentFormMetric,
          hadFormViolation: hadFormViolation,
        );
    if (validationOutcome == null) {
      return null;
    }

    final summary = validationOutcome.summary;
    return RangeRepAttemptProcessingResult(
      validatedRepEvent: ValidatedRepEvent(
        attemptIndex: validationOutcome.attemptIndex,
        acceptedRepIndex: null,
        exerciseType: 'unknown',
        analysisKind: EngineKind.rangeRep.name,
        validationStatus: validationOutcome.status,
        validationReasons: validationOutcome.reasons,
        tempoDiagnosticReasons: const <RangeRepValidationReason>[],
        countsTowardReps: false,
        side: _validatedRepSideFromLabel(summary.selectedSideLabel),
        minPrimaryMetric: summary.minAngle,
        primaryRom: summary.primaryRom,
        worstFormMetric: summary.worstFormMetric,
        descentDuration: summary.descentDuration,
        ascentDuration: summary.ascentDuration,
        hadFormViolation: summary.hadFormViolation,
        hadCoverageDrop: summary.hadCoverageDrop,
        switchedSideDuringRep: summary.switchedSideDuringRep,
        completedPhaseSequence: false,
        measurementConfidence: summary.measurementConfidence,
        coverageQuality: summary.coverageQuality,
        finalScore: null,
        tempoAssessment: null,
        tempoIncludedInScore: false,
        completedAt: completedAt,
      ),
      lastRepScore: 0.0,
      lastAcceptedRepRom: 0.0,
      lastRepScoreBreakdown: null,
      shouldClearTempoAssessment: true,
    );
  }

  ValidatedRepSide? _validatedRepSideFromLabel(String? label) {
    return switch (label) {
      'left' => ValidatedRepSide.left,
      'right' => ValidatedRepSide.right,
      _ => null,
    };
  }
}
