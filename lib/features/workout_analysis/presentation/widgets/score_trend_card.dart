import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/session_measurement_evidence.dart';
import '../formatters/session_measurement_evidence_presenter.dart';
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
    this.timeWindow,
  });

  final String exerciseTitle;
  final List<ScoreTrendPoint> points;
  final VoidCallback? onTap;
  final double chartHeight;
  final String? subtitle;
  final bool showHeader;
  final bool showSnapshot;
  final ScoreTrendChartWindow? timeWindow;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final chartPoints = points.where(_isValidPoint).toList(growable: false);
    final timeline = _ScoreTrendTimeline.resolve(
      chartPoints,
      timeWindow: timeWindow,
    );
    final orderedPoints = timeline.points
        .map((point) => point.source)
        .toList(growable: false);
    final bounds = orderedPoints.isEmpty
        ? null
        : _ScoreTrendBounds.fromPoints(orderedPoints);
    final latestPoint = orderedPoints.isEmpty ? null : orderedPoints.last;
    final latestScore = latestPoint?.score;
    final aggregatePoints = orderedPoints
        .where((point) => point.contributesToScoreAggregates)
        .toList(growable: false);
    final scoreDelta = aggregatePoints.length < 2
        ? 0.0
        : aggregatePoints.last.score - aggregatePoints.first.score;

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
                    hasEvidenceWarning: latestPoint!.hasEvidenceWarning,
                    warningLabel: localizations.measurementEvidenceWarningShort,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (bounds == null)
                  const _ScoreTrendPlaceholder()
                else
                  _ScoreTrendChart(
                    timeline: timeline,
                    bounds: bounds,
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
  const _TrendSnapshot({
    required this.latestScore,
    required this.scoreDelta,
    required this.hasEvidenceWarning,
    required this.warningLabel,
  });

  final double latestScore;
  final double scoreDelta;
  final bool hasEvidenceWarning;
  final String warningLabel;

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
        if (hasEvidenceWarning)
          Tooltip(
            message: warningLabel,
            child: Container(
              key: const Key('score-trend-evidence-warning'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.caution.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: colors.caution.withValues(alpha: 0.30),
                ),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: colors.caution,
                size: 18,
                semanticLabel: warningLabel,
              ),
            ),
          )
        else
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
    required this.timeline,
    required this.bounds,
    required this.chartHeight,
  });

  final _ScoreTrendTimeline timeline;
  final _ScoreTrendBounds bounds;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isDetailed = chartHeight > 200;
    final xLabelInterval = timeline.labelInterval(isDetailed: isDetailed);

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
          maxX: timeline.maxX,
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
                    _trendTooltipItem(
                      localizations: AppLocalizations.of(context),
                      colors: colors,
                      point: timeline.closestPoint(spot.x).source,
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
                interval: xLabelInterval,
                getTitlesWidget: (value, meta) {
                  final label = timeline.axisLabel(
                    value,
                    interval: xLabelInterval,
                  );
                  if (label == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      label,
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
                for (final point in timeline.points)
                  FlSpot(point.x, point.source.score),
              ],
              isCurved: timeline.points.length > 2,
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
                  final point = timeline.points[index].source;
                  return FlDotCirclePainter(
                    radius: isDetailed ? 4.5 : 3.5,
                    color: colors.surfaceStrong,
                    strokeWidth: isDetailed ? 3 : 2.3,
                    strokeColor: point.hasEvidenceWarning
                        ? colors.caution
                        : colors.analysisAccent,
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

LineTooltipItem _trendTooltipItem({
  required AppLocalizations localizations,
  required AppSemanticColors colors,
  required ScoreTrendPoint point,
}) {
  final confidence = SessionMeasurementEvidencePresenter.confidenceLabel(
    point.averageMeasurementConfidence,
  );
  final quality = SessionMeasurementEvidencePresenter.qualityLabel(
    localizations,
    point.measurementQuality,
  );

  return LineTooltipItem(
    '${point.tooltipLabel}\n',
    TextStyle(
      color: colors.foregroundMuted,
      fontSize: 11,
      fontWeight: AppFontWeights.semibold,
    ),
    children: [
      TextSpan(
        text: point.score.round().toString(),
        style: TextStyle(
          color: point.hasEvidenceWarning
              ? colors.caution
              : colors.analysisAccent,
          fontSize: 16,
          fontWeight: AppFontWeights.heavy,
        ),
      ),
      TextSpan(text: '\n${localizations.measurementQuality}: $quality'),
      if (confidence != null)
        TextSpan(text: '\n${localizations.measurementConfidence}: $confidence'),
      if (point.measurementSampleCount > 0)
        TextSpan(
          text:
              '\n${localizations.measurementSampleCount(point.measurementSampleCount)}',
        ),
      if (point.preparationOutcome == PreparationOutcome.overridden)
        TextSpan(
          text:
              '\n${localizations.preparationCheck}: ${localizations.preparationOverridden}',
        ),
    ],
  );
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

class _ScoreTrendTimeline {
  const _ScoreTrendTimeline._({required this.points, required this.window});

  final List<_ResolvedScoreTrendPoint> points;
  final ScoreTrendChartWindow? window;

  factory _ScoreTrendTimeline.resolve(
    List<ScoreTrendPoint> source, {
    ScoreTrendChartWindow? timeWindow,
  }) {
    if (source.isEmpty) {
      return const _ScoreTrendTimeline._(
        points: <_ResolvedScoreTrendPoint>[],
        window: null,
      );
    }

    final hasCompleteTimeline = source.every(
      (point) => point.startedAt != null,
    );
    if (!hasCompleteTimeline) {
      return _ScoreTrendTimeline._(
        points: [
          for (var index = 0; index < source.length; index++)
            _ResolvedScoreTrendPoint(
              source: source[index],
              x: index.toDouble(),
            ),
        ],
        window: null,
      );
    }

    final resolvedWindow =
        timeWindow ?? ScoreTrendChartWindow.forPoints(source);
    final resolvedPoints = [
      for (final point in source)
        _ResolvedScoreTrendPoint(
          source: point,
          x: resolvedWindow.positionFor(point.startedAt!),
        ),
    ]..sort((left, right) => left.x.compareTo(right.x));

    return _ScoreTrendTimeline._(
      points: List<_ResolvedScoreTrendPoint>.unmodifiable(resolvedPoints),
      window: resolvedWindow,
    );
  }

  double get maxX {
    final resolvedWindow = window;
    if (resolvedWindow != null) {
      return resolvedWindow.maxX;
    }
    return points.length > 1 ? (points.length - 1).toDouble() : 1.0;
  }

  _ResolvedScoreTrendPoint closestPoint(double x) {
    var closest = points.first;
    var closestDistance = (closest.x - x).abs();
    for (final point in points.skip(1)) {
      final distance = (point.x - x).abs();
      if (distance < closestDistance) {
        closest = point;
        closestDistance = distance;
      }
    }
    return closest;
  }

  double labelInterval({required bool isDetailed}) {
    final resolvedWindow = window;
    if (resolvedWindow == null) {
      return _sessionLabelInterval(points.length);
    }

    final span = maxX + 0.000001;
    if (resolvedWindow.axisUnit == ScoreTrendAxisUnit.calendarMonths) {
      if (span <= 6) {
        return 1;
      }
      if (span <= 18) {
        return 3;
      }
      if (span <= 36) {
        return 6;
      }
      return (span / (isDetailed ? 7 : 5)).ceilToDouble();
    }

    if (span <= 7) {
      return isDetailed ? 2 : 3;
    }
    if (span <= 31) {
      return 7;
    }
    if (span <= 90) {
      return 14;
    }
    if (span <= 180) {
      return 30;
    }
    if (span <= 365) {
      return 60;
    }
    return (span / (isDetailed ? 7 : 5)).ceilToDouble();
  }

  String? axisLabel(double x, {required double interval}) {
    if (x < 0 || x > maxX + 0.0001) {
      return null;
    }

    final resolvedWindow = window;
    if (resolvedWindow == null) {
      final index = x.round();
      if ((x - index).abs() > 0.0001 || index >= points.length) {
        return null;
      }
      return points[index].source.label;
    }

    final date = resolvedWindow.dateForPosition(x);
    final label = resolvedWindow.axisUnit == ScoreTrendAxisUnit.calendarMonths
        ? _monthYearLabel(date)
        : _dayMonthLabel(date);
    final previousTick = _previousAxisTick(x, interval: interval);
    if (previousTick != null) {
      final isIrregularEndTick = (x - previousTick - interval).abs() > 0.0001;
      if (isIrregularEndTick && x - previousTick < interval * 0.45) {
        return null;
      }
      final previousDate = resolvedWindow.dateForPosition(previousTick);
      final previousLabel =
          resolvedWindow.axisUnit == ScoreTrendAxisUnit.calendarMonths
          ? _monthYearLabel(previousDate)
          : _dayMonthLabel(previousDate);
      if (previousLabel == label) {
        return null;
      }
    }
    return label;
  }
}

double? _previousAxisTick(double x, {required double interval}) {
  if (x <= 0 || interval <= 0) {
    return null;
  }
  final regularTickIndex = (x / interval).floor();
  final regularTick = regularTickIndex * interval;
  if ((regularTick - x).abs() < 0.0001) {
    final previous = x - interval;
    return previous >= 0 ? previous : null;
  }
  return regularTick >= 0 ? regularTick : null;
}

class _ResolvedScoreTrendPoint {
  const _ResolvedScoreTrendPoint({required this.source, required this.x});

  final ScoreTrendPoint source;
  final double x;
}

double _sessionLabelInterval(int pointCount) {
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

String _dayMonthLabel(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day.$month';
}

String _monthYearLabel(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = (dateTime.year % 100).toString().padLeft(2, '0');
  return '$month.$year';
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
