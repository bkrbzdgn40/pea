import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/workout_statistics.dart';
import '../../application/workout_statistics_calculator.dart';
import '../../domain/models/workout_session.dart';
import '../models/home_dashboard_data.dart';
import 'settings_provider.dart';
import 'user_sessions_snapshot_provider.dart';

/// Builds Home dashboard aggregates from the shared session snapshot.
final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);
  final localizations = ref.watch(appLocalizationsProvider);

  return switch (snapshot.source) {
    UserSessionsSnapshotSource.real => _buildDashboardData(
      snapshot.sessions,
      localizations,
    ),
    UserSessionsSnapshotSource.noUser => HomeDashboardData.empty(
      source: HomeDashboardSource.noUser,
    ),
    UserSessionsSnapshotSource.empty => HomeDashboardData.empty(
      source: HomeDashboardSource.empty,
    ),
    UserSessionsSnapshotSource.error => HomeDashboardData.empty(
      source: HomeDashboardSource.error,
    ),
  };
});

HomeDashboardData _buildDashboardData(
  List<WorkoutSession> sessions,
  AppLocalizations localizations,
) {
  final statistics = WorkoutStatisticsCalculator().calculate(sessions);

  return HomeDashboardData(
    totalAnalyses: statistics.snapshotSessionCount,
    averageScore: statistics.averageScore.round(),
    thisWeekCount: statistics.currentWeekAnalysisCount,
    bestScore: statistics.bestScore.round(),
    scoreTrend: _buildScoreTrend(
      statistics.latestScoreSamples(),
      localizations,
    ),
    exerciseDistribution: _buildExerciseDistribution(
      statistics.exerciseSessionCounts,
      statistics.snapshotSessionCount,
      localizations,
    ),
    source: HomeDashboardSource.real,
  );
}

List<ScoreTrendPoint> _buildScoreTrend(
  List<WorkoutScoreSample> samples,
  AppLocalizations localizations,
) {
  return [
    for (final sample in samples)
      ScoreTrendPoint(
        label: localizations.weekdayShort(sample.startedAt.toLocal().weekday),
        score: sample.score,
      ),
  ];
}

List<ExerciseDistributionItem> _buildExerciseDistribution(
  Map<String, int> exerciseSessionCounts,
  int totalSessionCount,
  AppLocalizations localizations,
) {
  final items = exerciseSessionCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final item in items.take(4))
      ExerciseDistributionItem(
        label: localizations.exerciseTitle(item.key),
        value: item.value * 100 / totalSessionCount,
      ),
  ];
}
