import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_metric_tile.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/workout_statistics.dart';
import '../../domain/models/exercise_type.dart';
import '../models/home_dashboard_data.dart';
import '../providers/exercise_score_trend_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../widgets/score_trend_card.dart';

class ScoreTrendDetailScreen extends ConsumerStatefulWidget {
  const ScoreTrendDetailScreen({super.key, required this.exercise});

  final ExerciseType exercise;

  @override
  ConsumerState<ScoreTrendDetailScreen> createState() =>
      _ScoreTrendDetailScreenState();
}

class _ScoreTrendDetailScreenState
    extends ConsumerState<ScoreTrendDetailScreen> {
  ScoreTrendRange _selectedRange = ScoreTrendRange.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final exerciseTitle = localizations.exerciseTitle(widget.exercise.id);
    final trendState = ref.watch(exerciseScoreTrendProvider(widget.exercise));

    return AppScaffoldShell(
      title: localizations.formScoreTrend(exerciseTitle),
      currentPage: null,
      maxContentWidth: 960,
      body: trendState.when(
        loading: () => AppLoadingView(message: localizations.loading),
        error: (_, _) => _ScoreTrendEmptyState(
          message: localizations.formScoreDataUnavailable,
          detail: localizations.tryAgainLater,
          isError: true,
        ),
        data: (trendData) {
          if (!trendData.hasRealData) {
            final didFail =
                trendData.source == UserSessionsSnapshotSource.error;

            return _ScoreTrendEmptyState(
              message: didFail
                  ? localizations.formScoreTrendUnavailable(exerciseTitle)
                  : localizations.formScoreTrendEmpty(exerciseTitle),
              detail: didFail
                  ? localizations.tryAgainLater
                  : localizations.formScoreTrendEmptyDetail,
              isError: didFail,
            );
          }

          final now = ref.watch(scoreTrendClockProvider)();
          final rangeContext = _rangeContext(localizations, _selectedRange);
          final filteredSamples = trendData.samplesForRange(
            _selectedRange,
            now: now,
          );
          final chartWindow = trendData.chartWindowForRange(
            _selectedRange,
            now: now,
            source: filteredSamples,
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TrendRangeSelector(
                  selectedRange: _selectedRange,
                  onSelected: (range) {
                    if (range == _selectedRange) {
                      return;
                    }
                    setState(() => _selectedRange = range);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (filteredSamples.isEmpty)
                  _ScoreTrendEmptyState(
                    message: localizations.formScoreTrendRangeEmpty(
                      exerciseTitle,
                      rangeContext,
                    ),
                    detail: localizations.formScoreTrendRangeEmptyDetail,
                  )
                else ...[
                  _TrendDetailContent(
                    exercise: widget.exercise,
                    exerciseTitle: exerciseTitle,
                    rangeContext: rangeContext,
                    trendData: trendData,
                    samples: filteredSamples,
                    chartWindow: chartWindow!,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendDetailContent extends StatelessWidget {
  const _TrendDetailContent({
    required this.exercise,
    required this.exerciseTitle,
    required this.rangeContext,
    required this.trendData,
    required this.samples,
    required this.chartWindow,
  });

  final ExerciseType exercise;
  final String exerciseTitle;
  final String rangeContext;
  final ExerciseScoreTrendData trendData;
  final List<WorkoutScoreSample> samples;
  final ScoreTrendChartWindow chartWindow;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final latestSample = samples.last;
    final latestScore = latestSample.score;
    final aggregateSamples = trendData.aggregateEligibleSamples(samples);
    final scoreDelta = aggregateSamples.length < 2
        ? 0.0
        : aggregateSamples.last.score - aggregateSamples.first.score;
    final averageScore = trendData.averageScoreFor(samples);
    final bestScore = aggregateSamples.isEmpty
        ? null
        : trendData.bestAverageScoreFor(samples);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrendDetailHero(
          exercise: exercise,
          exerciseTitle: exerciseTitle,
          subtitle: localizations.formScoreTrendRangeSubtitle(
            exerciseTitle,
            rangeContext,
          ),
          latestScore: latestScore,
          scoreDelta: scoreDelta,
          hasEvidenceWarning: latestSample.hasEvidenceWarning,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartHeight = constraints.maxWidth < 520 ? 270.0 : 340.0;
            return ScoreTrendCard(
              exerciseTitle: exerciseTitle,
              points: trendData.detailPoints(source: samples),
              timeWindow: chartWindow,
              chartHeight: chartHeight,
              subtitle: localizations.formScoreTrendRangeSubtitle(
                exerciseTitle,
                rangeContext,
              ),
              showHeader: false,
              showSnapshot: false,
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _TrendMetricsGrid(
          sessionCount: samples.length,
          latestScore: latestScore,
          bestScore: bestScore,
          averageScore: averageScore,
        ),
      ],
    );
  }
}

class _TrendRangeSelector extends StatelessWidget {
  const _TrendRangeSelector({
    required this.selectedRange,
    required this.onSelected,
  });

  final ScoreTrendRange selectedRange;
  final ValueChanged<ScoreTrendRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final options = <(ScoreTrendRange, String, Key)>[
      (
        ScoreTrendRange.sevenDays,
        localizations.scoreTrendLastSevenDays,
        const Key('score-trend-range-seven-days'),
      ),
      (
        ScoreTrendRange.thirtyDays,
        localizations.scoreTrendLastThirtyDays,
        const Key('score-trend-range-thirty-days'),
      ),
      (
        ScoreTrendRange.all,
        localizations.scoreTrendAllTime,
        const Key('score-trend-range-all'),
      ),
    ];

    return AppSurfaceCard(
      key: const Key('score-trend-range-selector'),
      variant: AppSurfaceVariant.strong,
      padding: const EdgeInsets.all(AppSpacing.sm),
      radius: AppRadii.surface,
      borderColor: colors.analysisAccent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  color: colors.analysisAccent,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  localizations.scoreTrendRangeTitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _TrendRangeOption(
                    key: options[index].$3,
                    label: options[index].$2,
                    selected: options[index].$1 == selectedRange,
                    onTap: () => onSelected(options[index].$1),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendRangeOption extends StatelessWidget {
  const _TrendRangeOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: AnimatedContainer(
            duration: AppMotionDurations.fast,
            curve: AppMotionCurves.standard,
            constraints: const BoxConstraints(
              minHeight: AppTouchTargets.minimum,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colors.analysisAccent
                  : colors.surfaceMuted.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected ? colors.analysisAccent : colors.outlineSubtle,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colors.canvas : colors.foregroundMuted,
                fontWeight: selected
                    ? AppFontWeights.heavy
                    : AppFontWeights.semibold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _rangeContext(AppLocalizations localizations, ScoreTrendRange range) {
  return switch (range) {
    ScoreTrendRange.sevenDays => localizations.scoreTrendLastSevenDaysContext,
    ScoreTrendRange.thirtyDays => localizations.scoreTrendLastThirtyDaysContext,
    ScoreTrendRange.all => localizations.scoreTrendAllTimeContext,
  };
}

class _TrendDetailHero extends StatelessWidget {
  const _TrendDetailHero({
    required this.exercise,
    required this.exerciseTitle,
    required this.subtitle,
    required this.latestScore,
    required this.scoreDelta,
    required this.hasEvidenceWarning,
  });

  final ExerciseType exercise;
  final String exerciseTitle;
  final String subtitle;
  final double latestScore;
  final double scoreDelta;
  final bool hasEvidenceWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final trendColor = scoreDelta > 0
        ? colors.success
        : scoreDelta < 0
        ? colors.caution
        : colors.foregroundMuted;
    final trendIcon = scoreDelta > 0
        ? Icons.trending_up_rounded
        : scoreDelta < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final deltaLabel = scoreDelta > 0
        ? '+${scoreDelta.round()}'
        : scoreDelta.round().toString();

    return AppSurfaceCard(
      key: const Key('score-trend-detail-hero'),
      variant: AppSurfaceVariant.accent,
      padding: EdgeInsets.zero,
      radius: AppRadii.large,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            top: -54,
            end: -36,
            child: IgnorePointer(
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.analysisAccent.withValues(alpha: 0.10),
                    width: 24,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final identity = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadii.surface),
                        border: Border.all(
                          color: colors.analysisAccent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Icon(
                        _exerciseIcon(exercise),
                        color: colors.analysisAccent,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                  height: 1.05,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.foregroundMuted,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final score = _HeroScore(
                  latestScore: latestScore,
                  deltaLabel: deltaLabel,
                  trendColor: trendColor,
                  trendIcon: trendIcon,
                  hasEvidenceWarning: hasEvidenceWarning,
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: AppSpacing.md),
                      score,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.lg),
                    score,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroScore extends StatelessWidget {
  const _HeroScore({
    required this.latestScore,
    required this.deltaLabel,
    required this.trendColor,
    required this.trendIcon,
    required this.hasEvidenceWarning,
  });

  final double latestScore;
  final String deltaLabel;
  final Color trendColor;
  final IconData trendIcon;
  final bool hasEvidenceWarning;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      key: const Key('score-trend-detail-latest'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadii.surface),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            latestScore.round().toString(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
              letterSpacing: -1.4,
              height: 1,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '/ 100',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foregroundMuted,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: 2),
              if (hasEvidenceWarning)
                Tooltip(
                  message: AppLocalizations.of(
                    context,
                  ).measurementEvidenceWarningShort,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    key: const Key('score-trend-detail-evidence-warning'),
                    color: colors.caution,
                    size: 18,
                    semanticLabel: AppLocalizations.of(
                      context,
                    ).measurementEvidenceWarningShort,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, color: trendColor, size: 17),
                    const SizedBox(width: 3),
                    Text(
                      deltaLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: trendColor,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendMetricsGrid extends StatelessWidget {
  const _TrendMetricsGrid({
    required this.sessionCount,
    required this.latestScore,
    required this.bestScore,
    required this.averageScore,
  });

  final int sessionCount;
  final double latestScore;
  final double? bestScore;
  final double? averageScore;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final tiles = <Widget>[
      AppMetricTile(
        key: const Key('score-trend-session-count'),
        label: localizations.session,
        value: sessionCount.toString(),
        icon: Icons.calendar_month_rounded,
        tone: AppStatusTone.neutral,
      ),
      AppMetricTile(
        key: const Key('score-trend-latest-metric'),
        label: localizations.latestFormScore,
        value: latestScore.round().toString(),
        icon: Icons.bolt_rounded,
        tone: AppStatusTone.accent,
      ),
      AppMetricTile(
        key: const Key('score-trend-best-metric'),
        label: localizations.bestFormScore,
        value: bestScore?.round().toString() ?? '—',
        icon: Icons.emoji_events_rounded,
        tone: AppStatusTone.success,
      ),
      AppMetricTile(
        key: const Key('score-trend-average-metric'),
        label: localizations.averageScore,
        value: averageScore?.round().toString() ?? '—',
        icon: Icons.stacked_line_chart_rounded,
        tone: AppStatusTone.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final columnCount = constraints.maxWidth < 360
            ? 1
            : constraints.maxWidth < 720
            ? 2
            : 4;
        final tileWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          key: const Key('score-trend-summary-grid'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _ScoreTrendEmptyState extends StatelessWidget {
  const _ScoreTrendEmptyState({
    required this.message,
    this.detail,
    this.isError = false,
  });

  final String message;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final tone = isError ? colors.danger : colors.analysisAccent;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppSurfaceCard(
          key: const Key('score-trend-empty-state'),
          variant: AppSurfaceVariant.strong,
          padding: const EdgeInsets.all(AppSpacing.xl),
          radius: AppRadii.large,
          borderColor: tone.withValues(alpha: 0.30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  isError ? Icons.cloud_off_rounded : Icons.query_stats_rounded,
                  color: tone,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _exerciseIcon(ExerciseType exercise) {
  final id = exercise.id;
  if (id.contains('plank') || id == 'wall_sit') {
    return Icons.timer_rounded;
  }
  if (id == 'jumping_jack') {
    return Icons.directions_run_rounded;
  }
  if (id.contains('curl') ||
      id.contains('raise') ||
      id.contains('press') ||
      id.contains('row') ||
      id.contains('extension') ||
      id.contains('dip') ||
      id.contains('deadlift')) {
    return Icons.fitness_center_rounded;
  }
  return Icons.accessibility_new_rounded;
}
