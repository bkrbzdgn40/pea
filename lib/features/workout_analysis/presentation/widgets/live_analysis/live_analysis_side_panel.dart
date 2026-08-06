import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_motion.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_plan_session_provider.dart';

import 'live_analysis_debug_panel.dart';
import 'live_analysis_feedback.dart';
import 'live_analysis_formatters.dart';
import 'live_analysis_theme.dart';
import 'live_analysis_top_bar.dart';
import 'live_hud_mode_control.dart';
import 'live_hud_technical_details.dart';

class LiveAnalysisSidePanel extends StatelessWidget {
  const LiveAnalysisSidePanel({
    super.key,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    required this.onToggleCalibration,
    required this.showNonFinalSet,
    required this.onAdvance,
    required this.showDetails,
    required this.showFinishAction,
    required this.onToggleDetails,
  });

  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback? onToggleCalibration;
  final bool showNonFinalSet;
  final VoidCallback onAdvance;
  final bool showDetails;
  final bool showFinishAction;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 320 || textScale >= 1.5;

        return DecoratedBox(
          key: const ValueKey<String>('live-analysis-side-panel'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFA182027), Color(0xFA101419)],
            ),
            border: Border(
              left: BorderSide(color: liveHudAccent.withValues(alpha: 0.34)),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: liveHudAccent.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LiveSidePanelToolbar(
                    stacked: useStackedLayout,
                    pauseLabel: localizations.pauseWorkout,
                    finishLabel: localizations.finish,
                    isFinishing: isFinishing,
                    showDetails: showDetails,
                    showFinishAction: showFinishAction,
                    onPause: onPause,
                    onFinish: onFinish,
                    onToggleDetails: onToggleDetails,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey<String>('live-side-panel-scroll'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          WorkoutFeedbackStatus(
                            compact: true,
                            sidePanel: true,
                            showMeasurementConfidence: showDetails,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            key: const ValueKey<String>(
                              'live-performance-header',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onLongPress: onToggleCalibration,
                            child: showDetails && useStackedLayout
                                ? const Column(
                                    key: ValueKey<String>(
                                      'live-hud-stacked-metrics',
                                    ),
                                    children: <Widget>[
                                      SizedBox(
                                        height: 86,
                                        child: _PrimaryWorkoutMetricCard(
                                          compact: true,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      SizedBox(
                                        height: 86,
                                        child: _SecondaryWorkoutMetricCard(
                                          compact: true,
                                        ),
                                      ),
                                    ],
                                  )
                                : SizedBox(
                                    height: 78,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        const Expanded(
                                          flex: 3,
                                          child: _PrimaryWorkoutMetricCard(
                                            compact: true,
                                          ),
                                        ),
                                        if (showDetails) ...<Widget>[
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            flex: 2,
                                            child: _SecondaryWorkoutMetricCard(
                                              compact: true,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                          ),
                          if (showDetails) ...<Widget>[
                            const SizedBox(height: 8),
                            const LiveHudTechnicalDetails(compact: true),
                            const SizedBox(height: 8),
                            const RangeRepSideTrackingIndicator(compact: true),
                          ],
                          const SizedBox(height: 8),
                          WorkoutSetCompletedSection(
                            compact: true,
                            showNonFinal: showNonFinalSet,
                            onAdvance: onAdvance,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveSidePanelToolbar extends StatelessWidget {
  const _LiveSidePanelToolbar({
    required this.stacked,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.showDetails,
    required this.showFinishAction,
    required this.onPause,
    required this.onFinish,
    required this.onToggleDetails,
  });

  final bool stacked;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final bool showDetails;
  final bool showFinishAction;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        key: const ValueKey<String>('live-hud-stacked-header'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ActiveExerciseTitle(compact: true, maxLines: 2),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: LiveHudActionButton(
                  key: const ValueKey<String>('live-pause-button'),
                  compact: true,
                  label: pauseLabel,
                  icon: Icons.pause_rounded,
                  accentColor: liveHudAccent,
                  onPressed: onPause,
                ),
              ),
              const SizedBox(width: 8),
              LiveHudModeControl(
                compact: true,
                showDetails: showDetails,
                onPressed: onToggleDetails,
              ),
              if (showFinishAction) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: LiveHudActionButton(
                    key: const ValueKey<String>('live-finish-button'),
                    compact: true,
                    label: finishLabel,
                    icon: Icons.stop_rounded,
                    accentColor: Colors.white70,
                    onPressed: isFinishing ? null : onFinish,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: LiveHudActionButton(
            key: const ValueKey<String>('live-pause-button'),
            compact: true,
            label: pauseLabel,
            icon: Icons.pause_rounded,
            accentColor: liveHudAccent,
            onPressed: onPause,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(flex: 3, child: ActiveExerciseTitle(compact: true)),
        const SizedBox(width: 8),
        LiveHudModeControl(
          compact: true,
          showDetails: showDetails,
          onPressed: onToggleDetails,
        ),
        if (showFinishAction) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: LiveHudActionButton(
              key: const ValueKey<String>('live-finish-button'),
              compact: true,
              label: finishLabel,
              icon: Icons.stop_rounded,
              accentColor: Colors.white70,
              onPressed: isFinishing ? null : onFinish,
            ),
          ),
        ],
      ],
    );
  }
}

class LandscapeWorkoutMetricsOverlay extends StatelessWidget {
  const LandscapeWorkoutMetricsOverlay({
    super.key,
    required this.topInset,
    required this.onToggleCalibration,
    required this.showDetails,
  });

  final double topInset;
  final VoidCallback? onToggleCalibration;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset + 58,
      left: 14,
      right: 14,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Expanded(
                    flex: 3,
                    child: _PrimaryWorkoutMetricCard(compact: true),
                  ),
                  if (showDetails) ...<Widget>[
                    const SizedBox(width: 8),
                    const Expanded(
                      flex: 2,
                      child: _SecondaryWorkoutMetricCard(compact: true),
                    ),
                  ],
                ],
              ),
            ),
            if (showDetails) ...<Widget>[
              const SizedBox(height: 8),
              const LiveHudTechnicalDetails(compact: true, horizontal: true),
            ],
          ],
        ),
      ),
    );
  }
}

class PrimaryWorkoutMetricsOverlay extends StatelessWidget {
  const PrimaryWorkoutMetricsOverlay({
    super.key,
    required this.topInset,
    required this.onToggleCalibration,
    required this.showDetails,
  });

  final double topInset;
  final VoidCallback? onToggleCalibration;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset + 82,
      left: 16,
      right: 16,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Expanded(flex: 3, child: _PrimaryWorkoutMetricCard()),
                  if (showDetails) ...<Widget>[
                    const SizedBox(width: 10),
                    const Expanded(
                      flex: 2,
                      child: _SecondaryWorkoutMetricCard(),
                    ),
                  ],
                ],
              ),
            ),
            if (showDetails) ...<Widget>[
              const SizedBox(height: 10),
              const LiveHudTechnicalDetails(horizontal: true, compact: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryWorkoutMetricCard extends ConsumerWidget {
  const _PrimaryWorkoutMetricCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          holdSeconds: displayWholeSeconds(state.currentHoldSeconds),
        ),
      ),
    );
    final isHoldAnalysis = metric.analysisKind == EngineKind.hold;
    final localizations = AppLocalizations.of(context);
    final value = isHoldAnalysis
        ? formatHoldSeconds(metric.holdSeconds)
        : metric.repCount.toString();

    return _LiveMetricSurface(
      key: const ValueKey<String>('live-primary-metric-card'),
      label: isHoldAnalysis
          ? localizations.holdMetric
          : localizations.repMetric,
      value: value,
      valueStyle: TextStyle(
        color: Colors.white,
        fontSize: compact ? 34 : 52,
        height: 0.96,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
      ),
      icon: isHoldAnalysis ? Icons.timer_outlined : Icons.repeat_rounded,
      accentColor: liveHudAccent,
      emphasize: true,
      compact: compact,
    );
  }
}

class _SecondaryWorkoutMetricCard extends ConsumerWidget {
  const _SecondaryWorkoutMetricCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          bestHoldSeconds: displayWholeSeconds(state.bestHoldSeconds),
          lastRepScore: displayScore(state.lastRepScore),
          lastValidationStatus:
              state.calibrationMetrics.lastRangeRepValidationStatus,
        ),
      ),
    );
    final isHoldAnalysis = metric.analysisKind == EngineKind.hold;
    final localizations = AppLocalizations.of(context);
    final isInvalidLastAttempt = metric.lastValidationStatus == 'invalid';
    final isLowConfidenceLastRep =
        metric.lastValidationStatus == 'low confidence' ||
        metric.lastValidationStatus == 'lowConfidence';
    final hasRepScore = metric.repCount > 0 && !isInvalidLastAttempt;
    final String value;
    if (isHoldAnalysis) {
      value = formatHoldSeconds(metric.bestHoldSeconds);
    } else if (hasRepScore) {
      value = metric.lastRepScore.toString();
    } else {
      value = '—';
    }

    return _LiveMetricSurface(
      key: const ValueKey<String>('live-secondary-metric-card'),
      label: isHoldAnalysis
          ? localizations.bestMetric
          : localizations.formRangeScoreMetric,
      value: value,
      valueStyle: TextStyle(
        color: isHoldAnalysis || hasRepScore
            ? isLowConfidenceLastRep
                  ? Colors.amberAccent
                  : liveHudAccent
            : Colors.white54,
        fontSize: compact ? 24 : 31,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
      icon: Icons.star_rounded,
      accentColor: isHoldAnalysis || hasRepScore
          ? isLowConfidenceLastRep
                ? Colors.amberAccent
                : liveHudAccent
          : Colors.white38,
      compact: compact,
    );
  }
}

class _LiveMetricSurface extends StatelessWidget {
  const _LiveMetricSurface({
    super.key,
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.icon,
    required this.accentColor,
    this.emphasize = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final IconData icon;
  final Color accentColor;
  final bool emphasize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.resolveDuration(context, AppMotionDurations.fast),
        curve: AppMotion.resolveCurve(context, Curves.easeOut),
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: compact ? 8 : 12,
        ),
        decoration: liveHudSurfaceDecoration(
          accentColor: accentColor,
          strong: emphasize,
          glow: emphasize,
          radius: compact ? 18 : 25,
          surfaceColor: emphasize
              ? liveHudMetricSurfaceStrong
              : liveHudMetricSurface,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 28 : 36,
              height: compact ? 28 : 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: emphasize ? 0.65 : 0.42),
                ),
              ),
              child: Icon(icon, color: accentColor, size: compact ? 16 : 21),
            ),
            SizedBox(width: compact ? 7 : 10),
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
                          duration: AppMotion.resolveDuration(
                            context,
                            AppMotionDurations.fast,
                          ),
                          switchInCurve: AppMotion.resolveCurve(
                            context,
                            Curves.easeOutCubic,
                          ),
                          switchOutCurve: AppMotion.resolveCurve(
                            context,
                            Curves.easeIn,
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.92,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            value,
                            key: ValueKey<String>(value),
                            maxLines: 1,
                            style: valueStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sentenceCaseLiveMetricLabel(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor == Colors.white38
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: compact ? 12 : 13,
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

class CanonicalMetricsOverlay extends ConsumerWidget {
  const CanonicalMetricsOverlay({super.key, required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    return Positioned(
      top: topInset + 190,
      left: 20,
      right: 20,
      child: LiveCanonicalMetricsBar(metrics: liveMetrics),
    );
  }
}

class CalibrationPanelOverlay extends ConsumerWidget {
  const CalibrationPanelOverlay({
    super.key,
    required this.topInset,
    required this.compact,
    required this.onClose,
  });

  final double topInset;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutState = ref.watch(workoutControllerProvider);
    final hasPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );

    return Positioned(
      top: topInset + (compact ? (hasPlan ? 192 : 140) : (hasPlan ? 366 : 294)),
      bottom: compact ? 88 : null,
      left: compact ? 14 : 20,
      right: compact ? 14 : 20,
      child: CalibrationDebugPanel(
        workoutState: workoutState,
        onClose: onClose,
      ),
    );
  }
}

class PlannedResumeCountdownOverlay extends StatelessWidget {
  const PlannedResumeCountdownOverlay({
    super.key,
    required this.value,
    this.nextExerciseName,
    this.nextSetNumber,
  });

  final int value;
  final String? nextExerciseName;
  final int? nextSetNumber;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final nextExerciseName = this.nextExerciseName;
    final nextSetNumber = this.nextSetNumber;
    return Positioned.fill(
      child: BlockSemantics(
        key: const ValueKey<String>('planned-resume-semantics-blocker'),
        child: DecoratedBox(
          key: const ValueKey<String>('planned-resume-countdown-overlay'),
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.22),
              radius: 1.1,
              colors: <Color>[Color(0xFF12362B), Color(0xFF050A08)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.analysisAccent.withValues(
                            alpha: 0.12,
                          ),
                          border: Border.all(
                            color: AppColors.analysisAccent.withValues(
                              alpha: 0.48,
                            ),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.analysisAccent.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.analysisAccent,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        localizations.nextSetStarting,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.primaryForeground,
                              fontWeight: AppFontWeights.heavy,
                            ),
                      ),
                      if (nextExerciseName != null &&
                          nextSetNumber != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          key: const ValueKey<String>(
                            'planned-resume-next-step',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.analysisAccent.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: AppColors.analysisAccent.withValues(
                                alpha: 0.30,
                              ),
                            ),
                          ),
                          child: Text(
                            localizations.nextPlannedStep(
                              nextExerciseName,
                              nextSetNumber,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.secondaryForeground,
                              fontWeight: AppFontWeights.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(
                        liveRegion: true,
                        label: '$value',
                        child: Text(
                          '$value',
                          key: ValueKey<String>(
                            'planned-resume-countdown-$value',
                          ),
                          style: const TextStyle(
                            color: AppColors.analysisAccent,
                            fontSize: 112,
                            height: 0.92,
                            fontWeight: FontWeight.w900,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
