import 'package:flutter/material.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../domain/models/workout_session.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Oturum Detayi',
      showDrawer: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionSummaryCard(session: session),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final columnCount = constraints.maxWidth < 340 ? 1 : 2;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columnCount - 1)) /
                    columnCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _detailMetrics(session)
                      .map(
                        (metric) => SizedBox(
                          width: tileWidth,
                          child: _MetricTile(
                            label: metric.key,
                            value: metric.value,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            _RecommendationCard(session: session),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exerciseTitle(session.exerciseType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDateTime(session.startedAt),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _summaryLine(session),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oneri Ozeti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _recommendationFor(session),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<String, String>> _detailMetrics(WorkoutSession session) {
  if (session.isHoldSession) {
    return <MapEntry<String, String>>[
      MapEntry('Sure', _formatDuration(session.duration)),
      MapEntry('Toplam Hold', _formatHoldSeconds(session.totalHoldSeconds)),
      MapEntry('En Iyi Hold', _formatHoldSeconds(session.bestHoldSeconds)),
      MapEntry('Form Kesintisi', session.formBreakCount.toString()),
    ];
  }

  return <MapEntry<String, String>>[
    MapEntry('Sure', _formatDuration(session.duration)),
    MapEntry('Toplam Tekrar', session.totalReps.toString()),
    MapEntry('Ortalama Skor', _formatScore(session.averageScore)),
    MapEntry('En Iyi Skor', _formatScore(session.bestScore)),
    MapEntry('Form Uyarisi', session.formWarningCount.toString()),
  ];
}

String _summaryLine(WorkoutSession session) {
  if (session.isHoldSession) {
    return 'Toplam hold ${_formatHoldSeconds(session.totalHoldSeconds)} • '
        'En iyi hold ${_formatHoldSeconds(session.bestHoldSeconds)}';
  }

  return '${session.totalReps} tekrar • '
      'Ortalama skor ${_formatScore(session.averageScore)}';
}

String _recommendationFor(WorkoutSession session) {
  if (session.isHoldSession) {
    if (session.formBreakCount >= 3) {
      return 'Formunu biraz daha sabit tutmaya odaklan. Kisa ama temiz hold setleri iyi bir sonraki adim olur.';
    }

    if (session.bestHoldSeconds >= 30) {
      return 'Tutus suresi iyi gorunuyor. Ayni kaliteyi koruyarak sureyi kademeli artirabilirsin.';
    }

    if (session.totalHoldSeconds < 15) {
      return 'Biraz daha uzun ve kontrollu hold denemeleri faydali olabilir.';
    }

    return 'Dengeli bir hold oturumu gorunuyor. Siradaki sette ayni sabitligi korumaya odaklanabilirsin.';
  }

  if (session.formWarningCount >= 3) {
    return 'Form kontrolune biraz daha odaklan. Uyari sayisi yuksektiginde daha yavas ve kontrollu tekrarlar faydali olabilir.';
  }

  if (session.averageScore >= 85) {
    return 'Tempo ve form dengesi iyi gorunuyor. Ayni kaliteyi koruyarak set suresini kademeli artirabilirsin.';
  }

  if (session.totalReps < 5) {
    return 'Biraz daha uzun setlerle devam edebilirsin. Oncelik yine kontrollu hareket kalitesi olsun.';
  }

  return 'Dengeli bir oturum gorunuyor. Bir sonraki sette ayni formu korumaya odaklanabilirsin.';
}

String _exerciseTitle(String exerciseType) {
  return switch (exerciseType) {
    'squat' => 'Squat',
    _ => exerciseType
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' '),
  };
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return '$minutes:$seconds';
}

String _formatHoldSeconds(double seconds) {
  return _formatDuration(Duration(seconds: seconds.round()));
}

String _formatScore(double score) {
  return score.round().toString();
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
