import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../models/home_dashboard_data.dart';

class ScoreTrendCard extends StatelessWidget {
  const ScoreTrendCard({
    super.key,
    required this.exerciseTitle,
    required this.points,
    this.onTap,
    this.chartHeight = 160,
    this.subtitle,
    this.showHeader = true,
    this.showSnapshot = true,
  });

  final String exerciseTitle;
  final List<ScoreTrendPoint> points;
  final VoidCallback? onTap;
  final double chartHeight;
  final String? subtitle;
  final bool showHeader;
  final bool showSnapshot;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final chartPoints = points.where(_isValidPoint).toList(growable: false);
    final bounds = chartPoints.isEmpty
        ? null
        : _ScoreTrendBounds.fromPoints(chartPoints);
    final maxX = chartPoints.length > 1
        ? (chartPoints.length - 1).toDouble()
        : 1.0;
    final latestScore = chartPoints.isEmpty ? null : chartPoints.last.score;
    final scoreDelta = chartPoints.length < 2
        ? 0.0
        : chartPoints.last.score - chartPoints.first.score;

    final content = AppSurfaceCard(
      key: const Key('score-trend-card'),
      variant: AppSurfaceVariant.strong,
      padding: EdgeInsets.zero,
      radius: AppRadii.large,
      clipBehavior: Clip.antiAlias,
      borderColor: colors.analysisAccent.withValues(alpha: 0.24),
      child: Stack(
        children: [
          const Positioned.fill(child: _TrendCardBackdrop()),
          Padding(
            padding: AppSpacing.headerSurfacePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  _TrendHeader(
                    title: localizations.formScoreTrend(exerciseTitle),
                    subtitle:
                        subtitle ??
                        localizations.formScoreChangeSubtitle(exerciseTitle),
                    showDetailsAction: onTap != null,
                    detailsLabel: localizations.viewDetails,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (showSnapshot && latestScore != null) ...[
                  _TrendSnapshot(
                    latestScore: latestScore,
                    scoreDelta: scoreDelta,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (bounds == null)
                  const _ScoreTrendPlaceholder()
                else
                  _ScoreTrendChart(
                    chartPoints: chartPoints,
                    bounds: bounds,
                    maxX: maxX,
                    chartHeight: chartHeight,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      button: true,
      label: localizations.viewDetails,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: content,
        ),
      ),
    );
  }
}

class _TrendCardBackdrop extends StatelessWidget {
  const _TrendCardBackdrop();

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
              stops: const [0, 0.42, 1],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        PositionedDirectional(
          top: -52,
          end: -42,
          child: IgnorePointer(
            child: Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.analysisAccent.withValues(alpha: 0.07),
                  width: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendHeader extends StatelessWidget {
  const _TrendHeader({
    required this.title,
    required this.subtitle,
    required this.showDetailsAction,
    required this.detailsLabel,
  });

  final String title;
  final String subtitle;
  final bool showDetailsAction;
  final String detailsLabel;

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
            Icons.auto_graph_rounded,
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
        if (showDetailsAction) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: colors.analysisAccent.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  detailsLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.analysisAccent,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colors.analysisAccent,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendSnapshot extends StatelessWidget {
  const _TrendSnapshot({required this.latestScore, required this.scoreDelta});

  final double latestScore;
  final double scoreDelta;

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

    return Row(
      children: [
        Expanded(
          child: Container(
            key: const Key('score-trend-latest-score'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              border: Border.all(color: colors.outlineSubtle),
            ),
            child: Row(
              children: [
                Text(
                  latestScore.round().toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '/ 100',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.foregroundMuted,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          key: const Key('score-trend-delta-chip'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: trendColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: trendColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(trendIcon, color: trendColor, size: 18),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                deltaLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: trendColor,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreTrendChart extends StatelessWidget {
  const _ScoreTrendChart({
    required this.chartPoints,
    required this.bounds,
    required this.maxX,
    required this.chartHeight,
  });

  final List<ScoreTrendPoint> chartPoints;
  final _ScoreTrendBounds bounds;
  final double maxX;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isDetailed = chartHeight > 200;

    return Container(
      key: const Key('score-trend-chart-surface'),
      height: chartHeight,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        isDetailed ? AppSpacing.md : AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.analysisAccent.withValues(alpha: 0.055),
            colors.surfaceMuted.withValues(alpha: 0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.surface),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: bounds.minY,
          maxY: bounds.maxY,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            enabled: isDetailed,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(AppRadii.small),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              getTooltipColor: (_) => colors.surfaceStrong,
              getTooltipItems: (spots) {
                return [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${chartPoints[spot.x.round()].label}\n',
                      TextStyle(
                        color: colors.foregroundMuted,
                        fontSize: 11,
                        fontWeight: AppFontWeights.semibold,
                      ),
                      children: [
                        TextSpan(
                          text: spot.y.round().toString(),
                          style: TextStyle(
                            color: colors.analysisAccent,
                            fontSize: 16,
                            fontWeight: AppFontWeights.heavy,
                          ),
                        ),
                      ],
                    ),
                ];
              },
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: bounds.interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.foreground.withValues(alpha: 0.07),
              strokeWidth: 1,
              dashArray: const [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: bounds.interval,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Text(
                    value.toInt().toString(),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.foregroundSubtle,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _xLabelInterval(chartPoints.length),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= chartPoints.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      chartPoints[index].label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foregroundSubtle,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < chartPoints.length; i++)
                  FlSpot(i.toDouble(), chartPoints[i].score),
              ],
              isCurved: chartPoints.length > 2,
              curveSmoothness: 0.22,
              preventCurveOverShooting: true,
              gradient: LinearGradient(
                colors: [
                  colors.analysisAccent.withValues(alpha: 0.62),
                  colors.analysisAccent,
                ],
              ),
              barWidth: isDetailed ? 4 : 3.2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: isDetailed ? 4.5 : 3.5,
                    color: colors.surfaceStrong,
                    strokeWidth: isDetailed ? 3 : 2.3,
                    strokeColor: colors.analysisAccent,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.analysisAccent.withValues(alpha: 0.22),
                    colors.analysisAccent.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: AppMotionDurations.standard,
        curve: AppMotionCurves.standard,
      ),
    );
  }
}

class _ScoreTrendPlaceholder extends StatelessWidget {
  const _ScoreTrendPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      height: 132,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadii.surface),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats_rounded,
              color: colors.analysisAccent,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppLocalizations.of(context).noFormScoreToChart,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isValidPoint(ScoreTrendPoint point) {
  return point.score > 0 && point.score <= 100;
}

double _xLabelInterval(int pointCount) {
  if (pointCount <= 8) {
    return 1;
  }
  if (pointCount <= 16) {
    return 2;
  }
  if (pointCount <= 32) {
    return 4;
  }
  return 8;
}

class _ScoreTrendBounds {
  const _ScoreTrendBounds({
    required this.minY,
    required this.maxY,
    required this.interval,
  });

  final double minY;
  final double maxY;
  final double interval;

  factory _ScoreTrendBounds.fromPoints(List<ScoreTrendPoint> points) {
    var minScore = points.first.score;
    var maxScore = points.first.score;

    for (final point in points.skip(1)) {
      if (point.score < minScore) {
        minScore = point.score;
      }
      if (point.score > maxScore) {
        maxScore = point.score;
      }
    }

    var minY = _clampScore(minScore - 5);
    var maxY = _clampScore(maxScore + 5);

    if (maxY - minY < 10) {
      final middle = (minY + maxY) / 2;
      minY = _clampScore(middle - 5);
      maxY = _clampScore(middle + 5);
      if (maxY - minY < 10) {
        if (minY <= 0) {
          maxY = 10;
        } else {
          minY = 90;
          maxY = 100;
        }
      }
    }

    final range = maxY - minY;
    return _ScoreTrendBounds(
      minY: minY,
      maxY: maxY,
      interval: range <= 20 ? 5 : 10,
    );
  }
}

double _clampScore(double value) {
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}
