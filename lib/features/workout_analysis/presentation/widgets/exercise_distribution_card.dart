import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/exercise_type.dart';
import '../models/home_dashboard_data.dart';
import '../providers/exercise_score_trend_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../screens/score_trend_detail_screen.dart';
import 'score_trend_card.dart';

class ExerciseDistributionCard extends ConsumerStatefulWidget {
  const ExerciseDistributionCard({super.key, required this.items});

  final List<ExerciseDistributionItem> items;

  @override
  ConsumerState<ExerciseDistributionCard> createState() =>
      _ExerciseDistributionCardState();
}

class _ExerciseDistributionCardState
    extends ConsumerState<ExerciseDistributionCard> {
  static const List<Color> _colors = [
    Color(0xFF61E6BE),
    Color(0xFF64D2FF),
    Color(0xFFFFD166),
    Color(0xFFFF7A8A),
    Color(0xFFB69CFF),
    Color(0xFF7AA2FF),
  ];

  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final trendData = selectedExercise == null
        ? null
        : ref.watch(exerciseScoreTrendProvider(selectedExercise)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          key: const Key('exercise-distribution-card'),
          variant: AppSurfaceVariant.strong,
          padding: EdgeInsets.zero,
          radius: AppRadii.large,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(child: _DistributionBackdrop()),
              Padding(
                padding: AppSpacing.headerSurfacePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DistributionHeader(
                      title: localizations.exerciseDistribution,
                      subtitle: localizations.exerciseDistributionSubtitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (widget.items.isEmpty)
                      _DistributionPlaceholder(
                        message: localizations.exerciseDistributionEmpty,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 430;
                          final chart = _DistributionChart(
                            items: widget.items,
                            colors: _colors,
                            touchedIndex: _touchedIndex,
                            onTouched: (index) {
                              if (_touchedIndex == index) {
                                return;
                              }
                              setState(() => _touchedIndex = index);
                            },
                          );
                          final legend = _DistributionLegend(
                            items: widget.items,
                            colors: _colors,
                            touchedIndex: _touchedIndex,
                            localizedLabel: (item) => _localizedExerciseLabel(
                              localizations,
                              item.label,
                            ),
                            onSelected: (index) {
                              setState(() {
                                _touchedIndex = _touchedIndex == index
                                    ? -1
                                    : index;
                              });
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: AppSpacing.md),
                                legend,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 5, child: chart),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(flex: 6, child: legend),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (selectedExercise != null && trendData?.hasRealData == true) ...[
          const SizedBox(height: AppSpacing.sm),
          ScoreTrendCard(
            exerciseTitle: localizations.exerciseTitle(selectedExercise.id),
            points: trendData!.latestPoints(
              weekdayLabel: (dateTime) =>
                  localizations.weekdayShort(dateTime.weekday),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ScoreTrendDetailScreen(exercise: selectedExercise),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _DistributionBackdrop extends StatelessWidget {
  const _DistributionBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.analysisAccent.withValues(alpha: 0.10),
                colors.surfaceStrong,
                colors.surfaceStrong,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        PositionedDirectional(
          top: -66,
          end: -46,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.analysisAccent.withValues(alpha: 0.08),
                  width: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DistributionHeader extends StatelessWidget {
  const _DistributionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(
              color: colors.analysisAccent.withValues(
                alpha: AppOpacity.strongBorder,
              ),
            ),
          ),
          child: Icon(
            Icons.donut_large_rounded,
            color: colors.analysisAccent,
            size: 23,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionChart extends StatelessWidget {
  const _DistributionChart({
    required this.items,
    required this.colors,
    required this.touchedIndex,
    required this.onTouched,
  });

  final List<ExerciseDistributionItem> items;
  final List<Color> colors;
  final int touchedIndex;
  final ValueChanged<int> onTouched;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;
    final selectedItem = touchedIndex >= 0 && touchedIndex < items.length
        ? items[touchedIndex]
        : null;
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    final centerValue = selectedItem?.value ?? total;
    final centerLabel = selectedItem == null
        ? localizations.session
        : _localizedExerciseLabel(localizations, selectedItem.label);

    return Semantics(
      container: true,
      label: items
          .map(
            (item) =>
                '${_localizedExerciseLabel(localizations, item.label)} ${item.value.round()}%',
          )
          .join(', '),
      child: Container(
        key: const Key('exercise-distribution-chart-surface'),
        height: 210,
        decoration: BoxDecoration(
          color: semanticColors.surfaceMuted.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppRadii.surface),
          border: Border.all(color: semanticColors.outlineSubtle),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 53,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response?.touchedSection == null) {
                        onTouched(-1);
                        return;
                      }
                      onTouched(response!.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < items.length; i++)
                      PieChartSectionData(
                        value: items[i].value,
                        color: colors[i % colors.length],
                        radius: i == touchedIndex ? 31 : 25,
                        showTitle: false,
                        borderSide: BorderSide(
                          color: semanticColors.surfaceStrong,
                          width: 2,
                        ),
                      ),
                  ],
                ),
                duration: AppMotionDurations.standard,
                curve: AppMotionCurves.standard,
              ),
            ),
            IgnorePointer(
              child: AnimatedContainer(
                duration: AppMotionDurations.fast,
                curve: AppMotionCurves.standard,
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      semanticColors.analysisAccent.withValues(alpha: 0.11),
                      semanticColors.surfaceStrong,
                    ],
                  ),
                  border: Border.all(color: semanticColors.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${centerValue.round()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: semanticColors.foreground,
                        fontWeight: AppFontWeights.heavy,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        centerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: semanticColors.foregroundMuted,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  const _DistributionLegend({
    required this.items,
    required this.colors,
    required this.touchedIndex,
    required this.localizedLabel,
    required this.onSelected,
  });

  final List<ExerciseDistributionItem> items;
  final List<Color> colors;
  final int touchedIndex;
  final String Function(ExerciseDistributionItem item) localizedLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _LegendItem(
            item: items[i],
            color: colors[i % colors.length],
            label: localizedLabel(items[i]),
            selected: touchedIndex == i,
            onTap: () => onSelected(i),
          ),
          if (i != items.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

String _localizedExerciseLabel(AppLocalizations localizations, String label) {
  for (final exercise in ExerciseType.values) {
    if (exercise.title == label || exercise.id == label) {
      return localizations.exerciseTitle(exercise.id);
    }
  }
  return label;
}

class _DistributionPlaceholder extends StatelessWidget {
  const _DistributionPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadii.surface),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: colors.analysisAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.foregroundMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.item,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ExerciseDistributionItem item;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${item.value.round()}%',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.compact),
          child: AnimatedContainer(
            duration: AppMotionDurations.fast,
            curve: AppMotionCurves.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : colors.surfaceMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.52)
                    : colors.outlineSubtle,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${item.value.round()}%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: AppFontWeights.heavy,
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
