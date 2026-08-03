import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/engine_kind.dart';
import '../models/live_tracking_state.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/live_tracking_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import 'planned_workout_hud_models.dart';
import 'planned_workout_hud_presenter.dart';
import 'planned_workout_live_hud_view.dart';

export 'planned_workout_hud_models.dart';
export 'planned_workout_live_hud_view.dart' show PlannedWorkoutLiveHudView;

class PlannedWorkoutLiveHud extends ConsumerWidget {
  const PlannedWorkoutLiveHud({
    super.key,
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    this.reserveLeadingDeveloperControl = false,
    this.sidePanel = false,
  });

  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool reserveLeadingDeveloperControl;
  final bool sidePanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(
      workoutPlanSessionProvider.select(
        (state) => (
          snapshot: state.snapshot,
          isWorkoutCompleted: state.isWorkoutCompleted,
        ),
      ),
    );
    final snapshot = planState.snapshot;
    final exercise = snapshot?.currentExercise;
    if (snapshot == null || exercise == null || planState.isWorkoutCompleted) {
      return const SizedBox.shrink();
    }

    final metric = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          bestHoldSeconds: displayWholeSeconds(state.bestHoldSeconds),
          lastRepScore: displayScore(state.lastRepScore),
          lastValidationStatus:
              state.calibrationMetrics.lastRangeRepValidationStatus,
          feedbackMessage: state.feedbackMessage,
          isFormBad: state.isFormBad,
          currentPhase: state.currentPhase,
          automaticSideSelectionEnabled:
              state.calibrationMetrics.rangeRepAutomaticSideSelectionEnabled,
          selectedSide: state.calibrationMetrics.rangeRepMovementSelectedSide,
        ),
      ),
    );
    final repOutcome = ref.watch(liveRangeRepOutcomeProvider);
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    final localizations = AppLocalizations.of(context);
    final isHoldAnalysis = snapshot.targetHoldDuration != null;
    final primaryValue = isHoldAnalysis
        ? '${formatDuration(snapshot.currentHoldDuration)} / '
              '${formatDuration(snapshot.targetHoldDuration!)}'
        : '${snapshot.currentRepetitions} / '
              '${snapshot.targetRepetitions ?? 0}';

    final isInvalidLastAttempt = metric.lastValidationStatus == 'invalid';
    final isLowConfidenceLastRep =
        metric.lastValidationStatus == 'low confidence' ||
        metric.lastValidationStatus == 'lowConfidence';
    final secondaryMetric = plannedSecondaryMetricPresentation(
      isHoldAnalysis: isHoldAnalysis,
      hasCurrentProgress: isHoldAnalysis
          ? snapshot.currentHoldDuration.compareTo(Duration.zero) > 0
          : snapshot.currentRepetitions > 0,
      bestHoldSeconds: metric.bestHoldSeconds,
      lastRepScore: metric.lastRepScore,
      isInvalidLastAttempt: isInvalidLastAttempt,
      isLowConfidenceLastRep: isLowConfidenceLastRep,
    );

    final feedback = trackingPhase == LiveTrackingPhase.tracking
        ? plannedFeedbackPresentation(
            message: metric.feedbackMessage,
            isFormBad: metric.isFormBad,
            currentPhase: metric.currentPhase,
            repOutcome: repOutcome,
            localizations: localizations,
          )
        : null;
    final sideLabel =
        metric.analysisKind == EngineKind.rangeRep &&
            metric.automaticSideSelectionEnabled
        ? metric.selectedSide == null
              ? localizations.automaticLegSelectionPrompt
              : localizations.trackedLeg(metric.selectedSide!)
        : null;

    final data = PlannedWorkoutLiveHudData(
      exerciseTitle: localizations.exerciseTitle(exercise.id),
      primaryLabel: sentenceCaseMetricLabel(
        isHoldAnalysis ? localizations.holdMetric : localizations.repMetric,
      ),
      primaryValue: primaryValue,
      primaryIcon: isHoldAnalysis ? Icons.timer_outlined : Icons.repeat_rounded,
      secondaryLabel: sentenceCaseMetricLabel(
        isHoldAnalysis
            ? localizations.bestMetric
            : localizations.formRangeScoreMetric,
      ),
      secondaryValue: secondaryMetric.value,
      secondaryTone: secondaryMetric.tone,
      progressLabel: localizations.plannedWorkoutProgress(
        round: snapshot.roundNumber,
        totalRounds: snapshot.totalRounds,
        set: snapshot.setNumber,
        totalSets: snapshot.setsInCurrentExercise,
      ),
      progressValue: isHoldAnalysis
          ? '${formatDuration(snapshot.currentHoldDuration)} / '
                '${formatDuration(snapshot.targetHoldDuration!)}'
          : localizations.repetitionProgress(
              snapshot.currentRepetitions,
              snapshot.targetRepetitions ?? 0,
            ),
      progress: snapshot.progress,
      sideLabel: sideLabel,
      feedbackTitle: feedback?.title,
      feedbackMessage: feedback?.message,
      feedbackMeasurementConfidenceLabel: feedback?.measurementConfidenceLabel,
      feedbackTone: feedback?.tone ?? PlannedWorkoutHudTone.positive,
      feedbackIcon: feedback?.icon ?? Icons.check_rounded,
    );

    return PlannedWorkoutLiveHudView(
      data: data,
      topInset: topInset,
      compact: compact,
      isFinishing: isFinishing,
      onPause: onPause,
      onFinish: onFinish,
      reserveLeadingDeveloperControl: reserveLeadingDeveloperControl,
      sidePanel: sidePanel,
    );
  }
}
