import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/home_dashboard_data.dart';

/// Compact Home chart; detailed history lives on the score trend detail screen.
class ScoreTrendCard extends StatelessWidget {
  const ScoreTrendCard({super.key, required this.points, this.onTap});

  final List<ScoreTrendPoint> points;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chartPoints = points.where(_isValidMiniChartPoint).toList();
    final bounds = chartPoints.isEmpty
        ? null
        : _ScoreTrendBounds.fromPoints(chartPoints);
    final maxX = chartPoints.length > 1
        ? (chartPoints.length - 1).toDouble()
        : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Skor Trendi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const Text(
                    'Detayı Gör',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              chartPoints.isEmpty
                  ? 'İlk skorların geldikçe trend burada görünür.'
                  : 'Son oturumlardaki skor değişimi',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (bounds == null)
              const _ScoreTrendPlaceholder()
            else
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxX,
                    minY: bounds.minY,
                    maxY: bounds.maxY,
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: bounds.interval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.08),
                        strokeWidth: 1,
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
                          reservedSize: 32,
                          interval: bounds.interval,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chartPoints.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                chartPoints[index].label,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
                        isCurved: false,
                        color: Colors.greenAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.greenAccent.withValues(alpha: 0.10),
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

class _ScoreTrendPlaceholder extends StatelessWidget {
  const _ScoreTrendPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        'Henüz çizilecek skor yok.',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }
}

bool _isValidMiniChartPoint(ScoreTrendPoint point) {
  return point.score > 0 && point.score <= 100;
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
