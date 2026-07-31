import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/engine_kind.dart';
import '../models/live_tracking_state.dart';
import '../models/range_rep_outcome_view_data.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/live_tracking_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';

const Color _plannedHudAccent = Color(0xFF61E6BE);
const Color _plannedHudSurface = Color(0xD91A2026);
const Color _plannedHudSurfaceStrong = Color(0xE6171D23);
const Color _plannedHudMetricSurface = Color(0x8F1A2026);
const Color _plannedHudMetricSurfaceStrong = Color(0xA6171D23);

enum PlannedWorkoutHudTone { positive, caution, invalid, muted }

class PlannedWorkoutLiveHudData {
  const PlannedWorkoutLiveHudData({
    required this.exerciseTitle,
    required this.primaryLabel,
    required this.primaryValue,
    required this.primaryIcon,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.secondaryTone,
    required this.progressLabel,
    required this.progressValue,
    required this.progress,
    this.sideLabel,
    this.feedbackTitle,
    this.feedbackMessage,
    this.feedbackTone = PlannedWorkoutHudTone.positive,
    this.feedbackIcon = Icons.check_rounded,
  });

  final String exerciseTitle;
  final String primaryLabel;
  final String primaryValue;
  final IconData primaryIcon;
  final String secondaryLabel;
  final String secondaryValue;
  final PlannedWorkoutHudTone secondaryTone;
  final String progressLabel;
  final String progressValue;
  final double progress;
  final String? sideLabel;
  final String? feedbackTitle;
  final String? feedbackMessage;
  final PlannedWorkoutHudTone feedbackTone;
  final IconData feedbackIcon;

  bool get hasFeedback =>
      feedbackTitle != null &&
      feedbackTitle!.isNotEmpty &&
      feedbackMessage != null &&
      feedbackMessage!.isNotEmpty;
}

class PlannedWorkoutLiveHud extends ConsumerWidget {
  const PlannedWorkoutLiveHud({
    super.key,
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    this.reserveLeadingDeveloperControl = false,
  });

  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool reserveLeadingDeveloperControl;

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
          bestHoldSeconds: _displayWholeSeconds(state.bestHoldSeconds),
          lastRepScore: _displayScore(state.lastRepScore),
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
        ? '${_formatDuration(snapshot.currentHoldDuration)} / '
              '${_formatDuration(snapshot.targetHoldDuration!)}'
        : '${snapshot.currentRepetitions} / '
              '${snapshot.targetRepetitions ?? 0}';

    final isInvalidLastAttempt = metric.lastValidationStatus == 'invalid';
    final isLowConfidenceLastRep =
        metric.lastValidationStatus == 'low confidence' ||
        metric.lastValidationStatus == 'lowConfidence';
    final hasRepScore = metric.repCount > 0 && !isInvalidLastAttempt;
    final String secondaryValue;
    final PlannedWorkoutHudTone secondaryTone;
    if (isHoldAnalysis) {
      secondaryValue = _formatSeconds(metric.bestHoldSeconds);
      secondaryTone = PlannedWorkoutHudTone.positive;
    } else if (hasRepScore) {
      secondaryValue = metric.lastRepScore.toString();
      secondaryTone = isLowConfidenceLastRep
          ? PlannedWorkoutHudTone.caution
          : PlannedWorkoutHudTone.positive;
    } else {
      secondaryValue = '—';
      secondaryTone = PlannedWorkoutHudTone.muted;
    }

    final feedback = trackingPhase == LiveTrackingPhase.tracking
        ? _plannedFeedbackPresentation(
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
      primaryLabel: _sentenceCaseMetricLabel(
        isHoldAnalysis ? localizations.holdMetric : localizations.repMetric,
      ),
      primaryValue: primaryValue,
      primaryIcon: isHoldAnalysis ? Icons.timer_outlined : Icons.repeat_rounded,
      secondaryLabel: _sentenceCaseMetricLabel(
        isHoldAnalysis
            ? localizations.bestMetric
            : localizations.formRangeScoreMetric,
      ),
      secondaryValue: secondaryValue,
      secondaryTone: secondaryTone,
      progressLabel: localizations.plannedWorkoutProgress(
        round: snapshot.roundNumber,
        totalRounds: snapshot.totalRounds,
        set: snapshot.setNumber,
        totalSets: snapshot.setsInCurrentExercise,
      ),
      progressValue: isHoldAnalysis
          ? '${_formatDuration(snapshot.currentHoldDuration)} / '
                '${_formatDuration(snapshot.targetHoldDuration!)}'
          : localizations.repetitionProgress(
              snapshot.currentRepetitions,
              snapshot.targetRepetitions ?? 0,
            ),
      progress: snapshot.progress,
      sideLabel: sideLabel,
      feedbackTitle: feedback?.title,
      feedbackMessage: feedback?.message,
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
    );
  }
}

class PlannedWorkoutLiveHudView extends StatelessWidget {
  const PlannedWorkoutLiveHudView({
    super.key,
    required this.data,
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    this.reserveLeadingDeveloperControl = false,
  });

  final PlannedWorkoutLiveHudData data;
  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool reserveLeadingDeveloperControl;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final horizontalInset = compact ? 12.0 : 16.0;
    final bottomHorizontalInset = compact
        ? 12.0
        : MediaQuery.sizeOf(context).width < 360
        ? 16.0
        : 36.0;
    final topBarLeft = reserveLeadingDeveloperControl
        ? (compact ? 58.0 : 68.0)
        : horizontalInset;

    return Stack(
      key: const ValueKey<String>('planned-workout-live-hud'),
      children: <Widget>[
        Positioned(
          top: topInset + (compact ? 8 : 12),
          left: topBarLeft,
          right: horizontalInset,
          child: _PlannedWorkoutTopBar(
            compact: compact,
            exerciseTitle: data.exerciseTitle,
            pauseLabel: localizations.pauseWorkout,
            finishLabel: localizations.endWorkout,
            isFinishing: isFinishing,
            onPause: onPause,
            onFinish: onFinish,
          ),
        ),
        Positioned(
          top: topInset + (compact ? 58 : 82),
          left: horizontalInset,
          right: horizontalInset,
          child: SizedBox(
            height: compact ? 72 : 104,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desiredCardWidth = compact
                    ? (constraints.maxWidth * 0.24).clamp(150.0, 210.0)
                    : (constraints.maxWidth * 0.44).clamp(140.0, 184.0);
                final maximumCardWidth =
                    (constraints.maxWidth - (compact ? 12.0 : 16.0)) / 2;
                final cardWidth =
                    (desiredCardWidth > maximumCardWidth
                            ? maximumCardWidth
                            : desiredCardWidth)
                        .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _PlannedWorkoutMetricCard(
                        key: const ValueKey<String>(
                          'planned-workout-primary-metric',
                        ),
                        compact: compact,
                        label: data.primaryLabel,
                        value: data.primaryValue,
                        icon: data.primaryIcon,
                        tone: PlannedWorkoutHudTone.positive,
                        emphasize: true,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _PlannedWorkoutMetricCard(
                        key: const ValueKey<String>(
                          'planned-workout-secondary-metric',
                        ),
                        compact: compact,
                        label: data.secondaryLabel,
                        value: data.secondaryValue,
                        icon: Icons.star_rounded,
                        tone: data.secondaryTone,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          left: bottomHorizontalInset,
          right: bottomHorizontalInset,
          bottom: bottomInset + (compact ? 10 : 18),
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      flex: data.hasFeedback ? 5 : 1,
                      child: _PlannedWorkoutProgressCard(
                        data: data,
                        compact: true,
                      ),
                    ),
                    if (data.hasFeedback) ...<Widget>[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: _PlannedWorkoutFeedbackCard(
                          data: data,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _PlannedWorkoutProgressCard(data: data, compact: false),
                    if (data.hasFeedback) ...<Widget>[
                      const SizedBox(height: 10),
                      _PlannedWorkoutFeedbackCard(data: data, compact: false),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PlannedWorkoutTopBar extends StatelessWidget {
  const _PlannedWorkoutTopBar({
    required this.compact,
    required this.exerciseTitle,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final bool compact;
  final String exerciseTitle;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 42 : 54,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _PlannedWorkoutActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: compact,
                label: pauseLabel,
                icon: Icons.pause_rounded,
                accentColor: _plannedHudAccent,
                onPressed: onPause,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            flex: 3,
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  exerciseTitle,
                  key: const ValueKey<String>('planned-workout-exercise-title'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: _PlannedWorkoutActionButton(
                key: const ValueKey<String>('planned-workout-finish-button'),
                compact: compact,
                label: finishLabel,
                icon: Icons.stop_rounded,
                accentColor: Colors.white70,
                onPressed: isFinishing ? null : onFinish,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedWorkoutActionButton extends StatelessWidget {
  const _PlannedWorkoutActionButton({
    super.key,
    required this.compact,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final bool compact;
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: _plannedHudSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accentColor.withValues(
                  alpha: onPressed == null ? 0.18 : 0.48,
                ),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: compact ? 24 : 30,
                  height: compact ? 24 : 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: onPressed == null ? Colors.white30 : accentColor,
                    size: compact ? 15 : 18,
                  ),
                ),
                SizedBox(width: compact ? 7 : 9),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: onPressed == null
                            ? Colors.white38
                            : Colors.white,
                        fontSize: compact ? 12 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedWorkoutMetricCard extends StatelessWidget {
  const _PlannedWorkoutMetricCard({
    super.key,
    required this.compact,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.emphasize = false,
  });

  final bool compact;
  final String label;
  final String value;
  final IconData icon;
  final PlannedWorkoutHudTone tone;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accentColor = _toneColor(tone);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: compact ? 8 : 12,
        ),
        decoration: _plannedSurfaceDecoration(
          accentColor: accentColor,
          strong: emphasize,
          radius: compact ? 18 : 25,
          surfaceColor: emphasize
              ? _plannedHudMetricSurfaceStrong
              : _plannedHudMetricSurface,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 28 : 34,
              height: compact ? 28 : 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: compact ? 16 : 20),
            ),
            SizedBox(width: compact ? 6 : 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            value,
                            key: ValueKey<String>(value),
                            maxLines: 1,
                            style: TextStyle(
                              color: tone == PlannedWorkoutHudTone.muted
                                  ? Colors.white54
                                  : Colors.white,
                              fontSize: compact ? 25 : 36,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tone == PlannedWorkoutHudTone.muted
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: compact ? 10 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedWorkoutProgressCard extends StatelessWidget {
  const _PlannedWorkoutProgressCard({
    required this.data,
    required this.compact,
  });

  final PlannedWorkoutLiveHudData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('planned-workout-progress-card'),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 9 : 12,
        compact ? 12 : 16,
        compact ? 9 : 12,
      ),
      decoration: _plannedSurfaceDecoration(
        accentColor: _plannedHudAccent,
        radius: compact ? 18 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.bar_chart_rounded,
                color: _plannedHudAccent,
                size: compact ? 18 : 22,
              ),
              SizedBox(width: compact ? 7 : 9),
              Expanded(
                child: Text(
                  data.progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.progressValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _plannedHudAccent,
                  fontSize: compact ? 10 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: compact ? 5 : 7,
              color: _plannedHudAccent,
              backgroundColor: Colors.white12,
            ),
          ),
          if (data.sideLabel != null) ...<Widget>[
            SizedBox(height: compact ? 6 : 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.directions_walk_rounded,
                  color: Colors.white.withValues(alpha: 0.60),
                  size: compact ? 14 : 17,
                ),
                SizedBox(width: compact ? 5 : 7),
                Expanded(
                  child: Text(
                    data.sideLabel!,
                    key: const ValueKey<String>(
                      'planned-workout-side-indicator',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlannedWorkoutFeedbackCard extends StatelessWidget {
  const _PlannedWorkoutFeedbackCard({
    required this.data,
    required this.compact,
  });

  final PlannedWorkoutLiveHudData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accentColor = _toneColor(data.feedbackTone);
    return AnimatedContainer(
      key: const ValueKey<String>('planned-workout-feedback-card'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 13,
      ),
      decoration: _plannedSurfaceDecoration(
        accentColor: accentColor,
        strong: true,
        radius: compact ? 18 : 24,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 38 : 50,
            height: compact ? 38 : 50,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: compact ? 1.2 : 1.5,
              ),
            ),
            child: Icon(
              data.feedbackIcon,
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
                  data.feedbackTitle!,
                  key: const ValueKey<String>('live-analysis-status-line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 21,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  data.feedbackMessage!,
                  key: const ValueKey<String>(
                    'planned-workout-feedback-message',
                  ),
                  maxLines: compact ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: compact ? 11 : 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedFeedbackPresentation {
  const _PlannedFeedbackPresentation({
    required this.title,
    required this.message,
    required this.tone,
    required this.icon,
  });

  final String title;
  final String message;
  final PlannedWorkoutHudTone tone;
  final IconData icon;
}

_PlannedFeedbackPresentation _plannedFeedbackPresentation({
  required String message,
  required bool isFormBad,
  required String currentPhase,
  required RangeRepOutcomeViewData? repOutcome,
  required AppLocalizations localizations,
}) {
  if (repOutcome != null) {
    return switch (repOutcome.tone) {
      RangeRepOutcomeTone.positive => _PlannedFeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.positive,
        icon: Icons.check_rounded,
      ),
      RangeRepOutcomeTone.caution => _PlannedFeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.caution,
        icon: Icons.info_rounded,
      ),
      RangeRepOutcomeTone.invalid => _PlannedFeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        tone: PlannedWorkoutHudTone.invalid,
        icon: Icons.replay_rounded,
      ),
    };
  }

  return _PlannedFeedbackPresentation(
    title: localizations.workoutPhaseLabel(currentPhase),
    message: message,
    tone: isFormBad
        ? PlannedWorkoutHudTone.caution
        : PlannedWorkoutHudTone.positive,
    icon: isFormBad ? Icons.tune_rounded : Icons.check_rounded,
  );
}

BoxDecoration _plannedSurfaceDecoration({
  required Color accentColor,
  required double radius,
  bool strong = false,
  Color? surfaceColor,
}) {
  return BoxDecoration(
    color:
        surfaceColor ??
        (strong ? _plannedHudSurfaceStrong : _plannedHudSurface),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: accentColor.withValues(alpha: strong ? 0.48 : 0.28),
    ),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 7)),
    ],
  );
}

Color _toneColor(PlannedWorkoutHudTone tone) {
  return switch (tone) {
    PlannedWorkoutHudTone.positive => _plannedHudAccent,
    PlannedWorkoutHudTone.caution => Colors.amberAccent,
    PlannedWorkoutHudTone.invalid => Colors.orangeAccent,
    PlannedWorkoutHudTone.muted => Colors.white38,
  };
}

String _sentenceCaseMetricLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final lower = value.toLowerCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}

int _displayWholeSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  return Duration(milliseconds: (seconds * 1000).round()).inSeconds;
}

int _displayScore(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.toInt();
}

String _formatSeconds(int seconds) =>
    _formatDuration(Duration(seconds: seconds));

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
