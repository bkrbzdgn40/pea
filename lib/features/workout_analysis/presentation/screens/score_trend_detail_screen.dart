import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../domain/models/workout_session.dart';
import '../providers/user_sessions_snapshot_provider.dart';

class ScoreTrendDetailScreen extends ConsumerWidget {
  const ScoreTrendDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotState = ref.watch(userSessionsSnapshotProvider);

    return AppScaffoldShell(
      title: 'Skor Trendi',
      currentPage: null,
      body: snapshotState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
        error: (error, stackTrace) => _ScoreTrendEmptyState(
          message: 'Skor verisi alınamadı.',
          detail: error.toString(),
        ),
        data: (snapshot) {
          final points = _buildDetailPoints(snapshot.sessions);

          if (points.isEmpty) {
            return _ScoreTrendEmptyState(
              message: snapshot.sourceMessage,
              detail: 'Grafik için yeterli geçerli skor verisi bulunamadı.',
            );
          }

          return _ScoreTrendDetailContent(points: points);
        },
      ),
    );
  }
}

class _ScoreTrendDetailContent extends StatelessWidget {
  const _ScoreTrendDetailContent({required this.points});

  final List<_ScoreTrendDetailPoint> points;

  @override
  Widget build(BuildContext context) {
    final bounds = _DetailScoreBounds.fromPoints(points);
    final lastPoint = points.last;
    final bestScore = points.fold<double>(
      0,
      (best, point) => point.score > best ? point.score : best,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ortalama skor gelişimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kaydedilmiş oturumların tarih sırasına göre daha geniş görünümü.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: points.length > 1
                          ? (points.length - 1).toDouble()
                          : 1,
                      minY: bounds.minY,
                      maxY: bounds.maxY,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: bounds.interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: true),
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
                            reservedSize: 36,
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
                            reservedSize: 30,
                            interval: _xLabelInterval(points.length),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  points[index].label,
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
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].score),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TrendSummaryTile(
                  label: 'Oturum',
                  value: points.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendSummaryTile(
                  label: 'Son Skor',
                  value: lastPoint.score.round().toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrendSummaryTile(
                  label: 'En İyi',
                  value: bestScore.round().toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTrendEmptyState extends StatelessWidget {
  const _ScoreTrendEmptyState({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.show_chart_rounded,
              color: Colors.greenAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<_ScoreTrendDetailPoint> _buildDetailPoints(
  List<WorkoutSession> sessions,
) {
  final sortedSessions = [...sessions]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  return [
    for (final session in sortedSessions)
      if (session.averageScore > 0)
        _ScoreTrendDetailPoint(
          label: _dateLabel(session.startedAt.toLocal()),
          score: session.averageScore,
        ),
  ];
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

String _dateLabel(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day.$month';
}

class _ScoreTrendDetailPoint {
  const _ScoreTrendDetailPoint({required this.label, required this.score});

  final String label;
  final double score;
}

class _DetailScoreBounds {
  const _DetailScoreBounds({
    required this.minY,
    required this.maxY,
    required this.interval,
  });

  final double minY;
  final double maxY;
  final double interval;

  factory _DetailScoreBounds.fromPoints(List<_ScoreTrendDetailPoint> points) {
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

    var minY = minScore - 5;
    var maxY = maxScore + 5;
    if (minY < 0) {
      minY = 0;
    }

    if (maxY - minY < 10) {
      final middle = (minY + maxY) / 2;
      minY = middle - 5;
      maxY = middle + 5;
      if (minY < 0) {
        minY = 0;
        maxY = 10;
      }
    }

    final range = maxY - minY;
    return _DetailScoreBounds(
      minY: minY,
      maxY: maxY,
      interval: _detailInterval(range),
    );
  }
}

double _detailInterval(double range) {
  if (range <= 20) {
    return 5;
  }
  if (range <= 50) {
    return 10;
  }
  return 20;
}
