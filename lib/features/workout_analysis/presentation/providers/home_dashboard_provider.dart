import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/workout_session.dart';
import '../models/home_dashboard_data.dart';
import 'session_repository_provider.dart';

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final ownerId = ref.watch(currentUserIdProvider);
  if (ownerId == null) {
    return HomeDashboardData.fallback();
  }

  try {
    final sessions = await ref
        .read(sessionRepositoryProvider)
        .listSessions(ownerId: ownerId, limit: 100);

    if (sessions.isEmpty) {
      return HomeDashboardData.fallback();
    }

    return _buildDashboardData(sessions);
  } catch (_) {
    return HomeDashboardData.fallback();
  }
});

HomeDashboardData _buildDashboardData(List<WorkoutSession> sessions) {
  final averageScore =
      sessions.fold<double>(
        0,
        (total, session) => total + session.averageScore,
      ) /
      sessions.length;
  final bestScore = sessions.fold<double>(
    0,
    (best, session) => session.bestScore > best ? session.bestScore : best,
  );

  return HomeDashboardData(
    totalAnalyses: sessions.length,
    averageScore: averageScore.round(),
    thisWeekCount: _countThisWeek(sessions),
    bestScore: bestScore.round(),
    scoreTrend: _buildScoreTrend(sessions),
    exerciseDistribution: _buildExerciseDistribution(sessions),
  );
}

int _countThisWeek(List<WorkoutSession> sessions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: now.weekday - 1));

  return sessions.where((session) {
    final startedAt = session.startedAt.toLocal();
    return !startedAt.isBefore(weekStart);
  }).length;
}

List<ScoreTrendPoint> _buildScoreTrend(List<WorkoutSession> sessions) {
  final sortedSessions = [...sessions]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final recentSessions = sortedSessions.length > 7
      ? sortedSessions.sublist(sortedSessions.length - 7)
      : sortedSessions;

  return [
    for (final session in recentSessions)
      ScoreTrendPoint(
        label: _weekdayLabel(session.startedAt.toLocal()),
        score: session.averageScore,
      ),
  ];
}

List<ExerciseDistributionItem> _buildExerciseDistribution(
  List<WorkoutSession> sessions,
) {
  final counts = <String, int>{};
  for (final session in sessions) {
    final title = _exerciseTitle(session.exerciseType);
    counts[title] = (counts[title] ?? 0) + 1;
  }

  final items = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final item in items.take(4))
      ExerciseDistributionItem(
        label: item.key,
        value: item.value * 100 / sessions.length,
      ),
  ];
}

String _weekdayLabel(DateTime dateTime) {
  const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return labels[dateTime.weekday - 1];
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
