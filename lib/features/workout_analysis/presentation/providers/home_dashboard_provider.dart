import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_statistics.dart';
import '../../application/workout_statistics_calculator.dart';
import '../../domain/models/workout_session.dart';
import '../models/home_dashboard_data.dart';
import 'user_sessions_snapshot_provider.dart';

/// Builds Home dashboard aggregates from the shared session snapshot.
final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);

  return switch (snapshot.source) {
    UserSessionsSnapshotSource.real => _buildDashboardData(snapshot.sessions),
    UserSessionsSnapshotSource.noUser => HomeDashboardData.fallback(
      source: HomeDashboardSource.demoNoUser,
    ),
    UserSessionsSnapshotSource.empty => HomeDashboardData.fallback(
      source: HomeDashboardSource.demoEmpty,
    ),
    UserSessionsSnapshotSource.error => HomeDashboardData.fallback(
      source: HomeDashboardSource.demoError,
    ),
  };
});

HomeDashboardData _buildDashboardData(List<WorkoutSession> sessions) {
  final statistics = WorkoutStatisticsCalculator().calculate(sessions);

  return HomeDashboardData(
    totalAnalyses: statistics.snapshotSessionCount,
    averageScore: statistics.averageScore.round(),
    thisWeekCount: statistics.currentWeekAnalysisCount,
    bestScore: statistics.bestScore.round(),
    scoreTrend: _buildScoreTrend(statistics.latestScoreSamples()),
    exerciseDistribution: _buildExerciseDistribution(
      statistics.exerciseSessionCounts,
      statistics.snapshotSessionCount,
    ),
    source: HomeDashboardSource.real,
  );
}

List<ScoreTrendPoint> _buildScoreTrend(List<WorkoutScoreSample> samples) {
  return [
    for (final sample in samples)
      ScoreTrendPoint(
        label: _weekdayLabel(sample.startedAt.toLocal()),
        score: sample.score,
      ),
  ];
}

List<ExerciseDistributionItem> _buildExerciseDistribution(
  Map<String, int> exerciseSessionCounts,
  int totalSessionCount,
) {
  final items = exerciseSessionCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final item in items.take(4))
      ExerciseDistributionItem(
        label: _exerciseTitle(item.key),
        value: item.value * 100 / totalSessionCount,
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
