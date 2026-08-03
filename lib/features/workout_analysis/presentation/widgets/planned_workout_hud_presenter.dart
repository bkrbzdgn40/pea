import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../formatters/measurement_confidence_presentation_formatter.dart';
import '../models/range_rep_outcome_view_data.dart';
import 'planned_workout_hud_models.dart';

class PlannedFeedbackPresentation {
  const PlannedFeedbackPresentation({
    required this.measurementConfidenceLabel,
    required this.title,
    required this.message,
    required this.tone,
    required this.icon,
  });

  final String? measurementConfidenceLabel;
  final String title;
  final String message;
  final PlannedWorkoutHudTone tone;
  final IconData icon;
}

class PlannedSecondaryMetricPresentation {
  const PlannedSecondaryMetricPresentation({
    required this.value,
    required this.tone,
  });

  final String value;
  final PlannedWorkoutHudTone tone;
}

PlannedSecondaryMetricPresentation plannedSecondaryMetricPresentation({
  required bool isHoldAnalysis,
  required bool hasCurrentProgress,
  required int bestHoldSeconds,
  required int lastRepScore,
  required bool isInvalidLastAttempt,
  required bool isLowConfidenceLastRep,
}) {
  if (!hasCurrentProgress || (!isHoldAnalysis && isInvalidLastAttempt)) {
    return const PlannedSecondaryMetricPresentation(
      value: '—',
      tone: PlannedWorkoutHudTone.muted,
    );
  }
  if (isHoldAnalysis) {
    return PlannedSecondaryMetricPresentation(
      value: formatSeconds(bestHoldSeconds),
      tone: PlannedWorkoutHudTone.positive,
    );
  }
  return PlannedSecondaryMetricPresentation(
    value: lastRepScore.toString(),
    tone: isLowConfidenceLastRep
        ? PlannedWorkoutHudTone.caution
        : PlannedWorkoutHudTone.positive,
  );
}

PlannedFeedbackPresentation plannedFeedbackPresentation({
  required String message,
  required bool isFormBad,
  required String currentPhase,
  required RangeRepOutcomeViewData? repOutcome,
  required AppLocalizations localizations,
}) {
  if (repOutcome != null) {
    return switch (repOutcome.tone) {
      RangeRepOutcomeTone.positive => PlannedFeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.positive,
        icon: Icons.check_rounded,
      ),
      RangeRepOutcomeTone.caution => PlannedFeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.caution,
        icon: Icons.info_rounded,
      ),
      RangeRepOutcomeTone.invalid => PlannedFeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.invalid,
        icon: Icons.replay_rounded,
      ),
    };
  }

  return PlannedFeedbackPresentation(
    measurementConfidenceLabel: null,
    title: localizations.workoutPhaseLabel(currentPhase),
    message: message,
    tone: isFormBad
        ? PlannedWorkoutHudTone.caution
        : PlannedWorkoutHudTone.positive,
    icon: isFormBad ? Icons.tune_rounded : Icons.check_rounded,
  );
}

String sentenceCaseMetricLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final lower = value.toLowerCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}

int displayWholeSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  return Duration(milliseconds: (seconds * 1000).round()).inSeconds;
}

int displayScore(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.toInt();
}

String formatSeconds(int seconds) => formatDuration(Duration(seconds: seconds));

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
