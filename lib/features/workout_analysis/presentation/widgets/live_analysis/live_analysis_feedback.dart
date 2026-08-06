import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_motion.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/formatters/measurement_confidence_presentation_formatter.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_tracking_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_range_rep_outcome_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_tracking_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_plan_session_provider.dart';

import 'live_analysis_theme.dart';

class WorkoutSetCompletedSection extends ConsumerWidget {
  const WorkoutSetCompletedSection({
    super.key,
    required this.compact,
    required this.showNonFinal,
    required this.onAdvance,
  });

  final bool compact;
  final bool showNonFinal;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(
      workoutPlanSessionProvider.select(
        (state) =>
            (isSetCompleted: state.isSetCompleted, snapshot: state.snapshot),
      ),
    );
    final snapshot = plan.snapshot;
    if (!plan.isSetCompleted || snapshot == null) {
      return const SizedBox.shrink();
    }

    final isFinalSet = snapshot.completedSets >= snapshot.totalSets;
    if (!isFinalSet && !showNonFinal) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _WorkoutSetCompletedCard(
          key: ValueKey<String>(
            'planned-set-${snapshot.roundNumber}-${snapshot.exerciseIndex}-${snapshot.setNumber}-${snapshot.completedSets}',
          ),
          isFinalSet: isFinalSet,
          compact: compact,
          onAdvance: onAdvance,
        ),
        SizedBox(height: compact ? 6 : 10),
      ],
    );
  }
}

class RangeRepSideTrackingIndicator extends ConsumerWidget {
  const RangeRepSideTrackingIndicator({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sideState = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          enabled:
              state.calibrationMetrics.rangeRepAutomaticSideSelectionEnabled,
          movementSelectedSide:
              state.calibrationMetrics.rangeRepMovementSelectedSide,
        ),
      ),
    );
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (sideState.analysisKind != EngineKind.rangeRep ||
        !sideState.enabled ||
        trackingPhase != LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final selectedSide = sideState.movementSelectedSide;
    final hasSelectedSide = selectedSide != null;
    final accentColor = hasSelectedSide
        ? const Color(0xFF65D8FF)
        : Colors.white70;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 9),
      child: AnimatedContainer(
        key: const ValueKey<String>('live-range-rep-side-indicator'),
        duration: AppMotion.resolveDuration(context, AppMotionDurations.fast),
        curve: AppMotion.resolveCurve(context, Curves.easeOut),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 7 : 9,
        ),
        decoration: liveHudSurfaceDecoration(
          accentColor: accentColor,
          radius: compact ? 17 : 21,
          glow: hasSelectedSide,
          surfaceColor: liveHudSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: compact ? 32 : 38,
              height: compact ? 32 : 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.55)),
              ),
              child: Icon(
                hasSelectedSide
                    ? Icons.directions_walk_rounded
                    : Icons.swap_horiz_rounded,
                size: compact ? 18 : 22,
                color: accentColor,
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Flexible(
              child: Text(
                hasSelectedSide
                    ? localizations.trackedLeg(selectedSide)
                    : localizations.automaticLegSelectionPrompt,
                key: const ValueKey<String>(
                  'live-range-rep-side-indicator-text',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _WorkoutFeedbackKind { coaching, repOutcome }

class WorkoutFeedbackStatus extends StatelessWidget {
  const WorkoutFeedbackStatus({
    super.key,
    required this.compact,
    this.sidePanel = false,
    this.showMeasurementConfidence = false,
  });

  final bool compact;
  final bool sidePanel;
  final bool showMeasurementConfidence;

  @override
  Widget build(BuildContext context) {
    return _WorkoutFeedbackMessage(
      compact: compact,
      sidePanel: sidePanel,
      showMeasurementConfidence: showMeasurementConfidence,
    );
  }
}

class _WorkoutFeedbackMessage extends ConsumerWidget {
  const _WorkoutFeedbackMessage({
    required this.compact,
    required this.showMeasurementConfidence,
    this.sidePanel = false,
  });

  final bool compact;
  final bool sidePanel;
  final bool showMeasurementConfidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          message: state.feedbackMessage,
          isFormBad: state.isFormBad,
          currentPhase: state.currentPhase,
        ),
      ),
    );
    final repOutcome = ref.watch(liveRangeRepOutcomeProvider);
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (trackingPhase != LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final presentation = _feedbackPresentation(
      feedback: feedback,
      repOutcome: repOutcome,
      localizations: localizations,
    );
    final accentColor = presentation.accentColor;
    final isRepOutcome = presentation.kind == _WorkoutFeedbackKind.repOutcome;

    return Semantics(
      container: true,
      liveRegion: true,
      label: <String>[
        presentation.title,
        presentation.message,
        if (showMeasurementConfidence &&
            presentation.measurementConfidenceLabel != null)
          presentation.measurementConfidenceLabel!,
      ].join('. '),
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const ValueKey<String>('live-feedback-message-card'),
        duration: AppMotion.resolveDuration(
          context,
          AppMotionDurations.standard,
        ),
        curve: AppMotion.resolveCurve(context, Curves.easeOut),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 14,
        ),
        decoration: liveHudSurfaceDecoration(
          accentColor: accentColor,
          strong: isRepOutcome,
          glow: isRepOutcome,
          radius: compact ? 18 : 24,
          surfaceColor: isRepOutcome ? liveHudSurfaceStrong : liveHudSurface,
        ),
        child: sidePanel
            ? Column(
                key: const ValueKey<String>('live-feedback-side-panel-content'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        key: ValueKey<String>(
                          'live-feedback-kind-${presentation.kind.name}',
                        ),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isRepOutcome ? 0.85 : 0.62,
                            ),
                            width: isRepOutcome ? 1.5 : 1.2,
                          ),
                        ),
                        child: Icon(
                          presentation.icon,
                          color: accentColor,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          presentation.title,
                          key: const ValueKey<String>(
                            'live-analysis-status-line',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  AnimatedSwitcher(
                    duration: AppMotion.resolveDuration(
                      context,
                      AppMotionDurations.fast,
                    ),
                    child: Text(
                      presentation.message,
                      key: ValueKey<String>(presentation.message),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (showMeasurementConfidence &&
                      presentation.measurementConfidenceLabel !=
                          null) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      presentation.measurementConfidenceLabel!,
                      key: const ValueKey<String>(
                        'live-measurement-confidence',
                      ),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    key: ValueKey<String>(
                      'live-feedback-kind-${presentation.kind.name}',
                    ),
                    width: compact ? 40 : 50,
                    height: compact ? 40 : 50,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: isRepOutcome ? 0.85 : 0.62,
                        ),
                        width: isRepOutcome ? 1.5 : 1.2,
                      ),
                    ),
                    child: Icon(
                      presentation.icon,
                      color: accentColor,
                      size: compact ? 23 : 30,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          presentation.title,
                          key: const ValueKey<String>(
                            'live-analysis-status-line',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.92),
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.05,
                          ),
                        ),
                        SizedBox(height: compact ? 3 : 5),
                        AnimatedSwitcher(
                          duration: AppMotion.resolveDuration(
                            context,
                            AppMotionDurations.fast,
                          ),
                          child: Text(
                            presentation.message,
                            key: ValueKey<String>(presentation.message),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 18 : 22,
                              height: 1.16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (showMeasurementConfidence &&
                            presentation.measurementConfidenceLabel !=
                                null) ...<Widget>[
                          SizedBox(height: compact ? 3 : 5),
                          Text(
                            presentation.measurementConfidenceLabel!,
                            key: const ValueKey<String>(
                              'live-measurement-confidence',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: compact ? 10 : 12,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

_FeedbackPresentation _feedbackPresentation({
  required ({String message, bool isFormBad, String currentPhase}) feedback,
  required RangeRepOutcomeViewData? repOutcome,
  required AppLocalizations localizations,
}) {
  if (repOutcome != null) {
    return switch (repOutcome.tone) {
      RangeRepOutcomeTone.positive => _FeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: liveHudAccent,
        icon: Icons.check_circle_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
      RangeRepOutcomeTone.caution => _FeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.amberAccent,
        icon: Icons.info_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
      RangeRepOutcomeTone.invalid => _FeedbackPresentation(
        measurementConfidenceLabel:
            MeasurementConfidencePresentationFormatter.liveLabel(
              localizations,
              repOutcome.measurementConfidenceScore,
            ),
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.orangeAccent,
        icon: Icons.replay_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
    };
  }

  return _FeedbackPresentation(
    measurementConfidenceLabel: null,
    title: localizations.workoutPhaseLabel(feedback.currentPhase),
    message: feedback.message,
    accentColor: feedback.isFormBad ? Colors.amberAccent : liveHudAccent,
    icon: feedback.isFormBad ? Icons.tune_rounded : Icons.check_rounded,
    kind: _WorkoutFeedbackKind.coaching,
  );
}

class _FeedbackPresentation {
  const _FeedbackPresentation({
    required this.measurementConfidenceLabel,
    required this.title,
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.kind,
  });

  final String? measurementConfidenceLabel;
  final String title;
  final String message;
  final Color accentColor;
  final IconData icon;
  final _WorkoutFeedbackKind kind;
}

class _WorkoutSetCompletedCard extends StatelessWidget {
  const _WorkoutSetCompletedCard({
    super.key,
    required this.isFinalSet,
    required this.compact,
    required this.onAdvance,
  });

  final bool isFinalSet;
  final bool compact;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: liveHudSurfaceDecoration(
        accentColor: AppColors.success,
        radius: 15,
        strong: true,
        glow: true,
        surfaceColor: const Color(0xE6112A20),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: compact ? 20 : 24,
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              isFinalSet
                  ? localizations.finalSetCompleted
                  : localizations.setCompletedContinue,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          ElevatedButton(
            onPressed: onAdvance,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              isFinalSet ? localizations.finish : localizations.continueLabel,
              style: TextStyle(fontSize: compact ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }
}
