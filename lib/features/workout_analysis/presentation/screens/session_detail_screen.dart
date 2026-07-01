import 'package:flutter/material.dart';

import '../../domain/models/workout_session.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Oturum Detayı'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SessionSummaryCard(session: session),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricTile(
                    label: 'Süre',
                    value: _formatDuration(session.duration),
                  ),
                  _MetricTile(
                    label: 'Toplam Tekrar',
                    value: session.totalReps.toString(),
                  ),
                  _MetricTile(
                    label: 'Ortalama Skor',
                    value: _formatScore(session.averageScore),
                  ),
                  _MetricTile(
                    label: 'En İyi Skor',
                    value: _formatScore(session.bestScore),
                  ),
                  _MetricTile(
                    label: 'Form Uyarısı',
                    value: session.formWarningCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RecommendationCard(session: session),
            ],
          ),
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
            '${session.totalReps} tekrar • Ortalama skor ${_formatScore(session.averageScore)}',
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
    return SizedBox(
      width: 160,
      child: Container(
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
            'Öneri Özeti',
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

String _recommendationFor(WorkoutSession session) {
  if (session.formWarningCount >= 3) {
    return 'Form kontrolüne biraz daha odaklan. Uyarı sayısı yükseldiğinde daha yavaş ve kontrollü tekrarlar faydalı olabilir.';
  }

  if (session.averageScore >= 85) {
    return 'Tempo ve form dengesi iyi görünüyor. Aynı kaliteyi koruyarak set süresini kademeli artırabilirsin.';
  }

  if (session.totalReps < 5) {
    return 'Biraz daha uzun setlerle devam edebilirsin. Öncelik yine kontrollü hareket kalitesi olsun.';
  }

  return 'Dengeli bir oturum görünüyor. Bir sonraki sette aynı formu korumaya odaklanabilirsin.';
}

String _exerciseTitle(String exerciseType) {
  return switch (exerciseType) {
    'squat' => 'Squat',
    _ =>
      exerciseType
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
